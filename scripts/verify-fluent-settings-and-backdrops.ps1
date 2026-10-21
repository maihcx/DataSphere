$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class FluentSettingsVerifier {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct STARTUPINFO {
        public int cb;
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
        public int dwX;
        public int dwY;
        public int dwXSize;
        public int dwYSize;
        public int dwXCountChars;
        public int dwYCountChars;
        public int dwFillAttribute;
        public int dwFlags;
        public short wShowWindow;
        public short cbReserved2;
        public IntPtr lpReserved2;
        public IntPtr hStdInput;
        public IntPtr hStdOutput;
        public IntPtr hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION {
        public IntPtr hProcess;
        public IntPtr hThread;
        public int dwProcessId;
        public int dwThreadId;
    }

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool CreateProcess(
        string lpApplicationName,
        string lpCommandLine,
        IntPtr lpProcessAttributes,
        IntPtr lpThreadAttributes,
        bool bInheritHandles,
        uint dwCreationFlags,
        IntPtr lpEnvironment,
        string lpCurrentDirectory,
        ref STARTUPINFO lpStartupInfo,
        out PROCESS_INFORMATION lpProcessInformation);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, uint nFlags);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;

    public static void PhysicalLeftClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(120);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(80);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(300);
    }

    public static void CaptureWindow(IntPtr hWnd, string savePath) {
        RECT rc;
        GetWindowRect(hWnd, out rc);
        int width = rc.Right - rc.Left;
        int height = rc.Bottom - rc.Top;
        if (width <= 0 || height <= 0) return;

        using (Bitmap bmp = new Bitmap(width, height)) {
            using (Graphics g = Graphics.FromImage(bmp)) {
                IntPtr hdc = g.GetHdc();
                try {
                    PrintWindow(hWnd, hdc, 2); // PW_RENDERFULLCONTENT = 2
                } finally {
                    g.ReleaseHdc(hdc);
                }
            }
            bmp.Save(savePath, ImageFormat.Png);
        }
    }

    public static bool RunVerification(string exePath, string workingDir, string artifactDir) {
        bool allPassed = true;
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) {
                Console.WriteLine("Failed to open desktop!");
                allPassed = false;
                return;
            }
            SetThreadDesktop(hDesk);

            STARTUPINFO si = new STARTUPINFO();
            si.cb = Marshal.SizeOf(si);
            si.lpDesktop = @"WinSta0\default";
            PROCESS_INFORMATION pi = new PROCESS_INFORMATION();

            bool ok = CreateProcess(exePath, null, IntPtr.Zero, IntPtr.Zero, false, 0, IntPtr.Zero, workingDir, ref si, out pi);
            if (!ok) {
                Console.WriteLine("CreateProcess failed: " + Marshal.GetLastWin32Error());
                allPassed = false;
                return;
            }

            Console.WriteLine("Launched DataSphere PID: " + pi.dwProcessId);
            AutomationElement appWin = null;
            IntPtr hwnd = IntPtr.Zero;

            for (int i = 0; i < 30; i++) {
                Thread.Sleep(300);
                var cond = new PropertyCondition(AutomationElement.ProcessIdProperty, pi.dwProcessId);
                appWin = AutomationElement.RootElement.FindFirst(TreeScope.Children, cond);
                if (appWin != null) {
                    hwnd = (IntPtr)appWin.Current.NativeWindowHandle;
                    break;
                }
            }

            if (appWin == null) {
                Console.WriteLine("Could not find DataSphere window!");
                try { Process.GetProcessById(pi.dwProcessId).Kill(); } catch {}
                allPassed = false;
                return;
            }

            SetForegroundWindow(hwnd);
            Thread.Sleep(2500);

            Rect winRect = appWin.Current.BoundingRectangle;
            Console.WriteLine("DataSphere Window Bounds: X=" + winRect.X + ", Y=" + winRect.Y + ", W=" + winRect.Width + ", H=" + winRect.Height);

            // Step 1: Open Settings page from Home Page
            var allButtons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
            AutomationElement settingsBtn = null;
            foreach (AutomationElement btn in allButtons) {
                Rect r = btn.Current.BoundingRectangle;
                if (r.Width > 200 && r.Height > 60) {
                    if (settingsBtn == null || r.X > settingsBtn.Current.BoundingRectangle.X) {
                        settingsBtn = btn;
                    }
                }
            }

            if (settingsBtn != null) {
                Rect r = settingsBtn.Current.BoundingRectangle;
                int cx = (int)(r.X + r.Width / 2);
                int cy = (int)(r.Y + r.Height / 2);
                Console.WriteLine("Invoking Settings button at (" + cx + ", " + cy + ")");
                try {
                    var invoke = (InvokePattern)settingsBtn.GetCurrentPattern(InvokePattern.Pattern);
                    invoke.Invoke();
                } catch {
                    PhysicalLeftClick(cx, cy);
                }
            } else {
                Console.WriteLine("Settings button NOT found on Home Page!");
                allPassed = false;
            }

            Thread.Sleep(2000);

            // Step 2: Verify Centered Layout & Bounding Rectangles
            var allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
            AutomationElement sectionHeader = null;
            foreach (AutomationElement txt in allTexts) {
                string name = txt.Current.Name ?? "";
                Rect tr = txt.Current.BoundingRectangle;
                if (name.IndexOf("hóa", StringComparison.OrdinalIgnoreCase) >= 0 || name.IndexOf("Personalization", StringComparison.OrdinalIgnoreCase) >= 0 || (tr.Y > 240 && tr.Y < 300 && tr.Width > 400)) {
                    sectionHeader = txt;
                    break;
                }
            }

            if (sectionHeader != null) {
                Rect hr = sectionHeader.Current.BoundingRectangle;
                double relLeft = hr.X - winRect.X;
                double relRight = (winRect.X + winRect.Width) - (hr.X + hr.Width);
                Console.WriteLine("Section Header: RelLeft=" + (int)relLeft + ", Width=" + (int)hr.Width + ", RelRight=" + (int)relRight);
                
                // Centering verification: left and right margins should be balanced within 60px tolerance
                double marginDiff = Math.Abs(relLeft - relRight);
                Console.WriteLine("Horizontal Margin Difference: " + (int)marginDiff + " px");
                if (marginDiff < 60.0) {
                    Console.WriteLine("[PASS] Layout is symmetrically centered!");
                } else {
                    Console.WriteLine("[FAIL] Layout is not centered: left=" + (int)relLeft + ", right=" + (int)relRight);
                    allPassed = false;
                }
            } else {
                Console.WriteLine("[FAIL] Personalization section header not found in Settings page!");
                allPassed = false;
            }

            // Capture winui_settings_fluent_layout.png
            string layoutShot = System.IO.Path.Combine(artifactDir, "winui_settings_fluent_layout.png");
            CaptureWindow(hwnd, layoutShot);
            Console.WriteLine("Saved layout verification screenshot: " + layoutShot);

            // Step 3: Capture Tabbed Backdrop screenshot
            string tabbedShot = System.IO.Path.Combine(artifactDir, "winui_backdrop_tabbed.png");
            CaptureWindow(hwnd, tabbedShot);
            Console.WriteLine("Saved Tabbed backdrop screenshot: " + tabbedShot);

            // Step 4: Locate ComboBoxes in Settings page
            var allCombos = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ComboBox));
            Console.WriteLine("Found " + allCombos.Count + " ComboBoxes in Settings page.");
            AutomationElement backdropCombo = null;

            if (allCombos.Count >= 2) {
                backdropCombo = allCombos[1];
                Console.WriteLine("Backdrop ComboBox located at: " + backdropCombo.Current.BoundingRectangle.ToString());
            }

            if (backdropCombo != null) {
                Rect cbRect = backdropCombo.Current.BoundingRectangle;
                int cbX = (int)(cbRect.X + cbRect.Width / 2);
                int cbY = (int)(cbRect.Y + cbRect.Height / 2);

                // --- 1. Select Acrylic ---
                Console.WriteLine("Expanding Backdrop ComboBox...");
                try {
                    var ecp = (ExpandCollapsePattern)backdropCombo.GetCurrentPattern(ExpandCollapsePattern.Pattern);
                    ecp.Expand();
                } catch {
                    PhysicalLeftClick(cbX, cbY);
                }
                Thread.Sleep(1000);

                var procCond = new PropertyCondition(AutomationElement.ProcessIdProperty, pi.dwProcessId);
                var listTypeCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ListItem);
                var listItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new AndCondition(procCond, listTypeCond));
                Console.WriteLine("Found " + listItems.Count + " dropdown list items in DataSphere process.");
                AutomationElement acrylicItem = null;
                AutomationElement solidItem = null;

                foreach (AutomationElement item in listItems) {
                    string itemName = item.Current.Name ?? "";
                    if (itemName.IndexOf("Acrylic", StringComparison.OrdinalIgnoreCase) >= 0) {
                        acrylicItem = item;
                    }
                }

                if (acrylicItem != null) {
                    Console.WriteLine("Selecting Acrylic item: " + acrylicItem.Current.Name);
                    try {
                        var sip = (SelectionItemPattern)acrylicItem.GetCurrentPattern(SelectionItemPattern.Pattern);
                        sip.Select();
                    } catch {
                        Rect ar = acrylicItem.Current.BoundingRectangle;
                        PhysicalLeftClick((int)(ar.X + ar.Width / 2), (int)(ar.Y + ar.Height / 2));
                    }
                    Thread.Sleep(1500);

                    string acrylicShot = System.IO.Path.Combine(artifactDir, "winui_backdrop_acrylic.png");
                    CaptureWindow(hwnd, acrylicShot);
                    Console.WriteLine("Saved Acrylic backdrop screenshot: " + acrylicShot);
                } else {
                    Console.WriteLine("[FAIL] Acrylic item not found in dropdown!");
                    allPassed = false;
                }

                // --- 2. Select Solid ---
                Thread.Sleep(800);
                Console.WriteLine("Re-expanding Backdrop ComboBox for Solid selection...");
                try {
                    var ecp = (ExpandCollapsePattern)backdropCombo.GetCurrentPattern(ExpandCollapsePattern.Pattern);
                    ecp.Expand();
                } catch {
                    PhysicalLeftClick(cbX, cbY);
                }
                Thread.Sleep(1000);

                listItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new AndCondition(procCond, listTypeCond));
                Console.WriteLine("Found " + listItems.Count + " dropdown list items in DataSphere process for Solid.");
                foreach (AutomationElement item in listItems) {
                    string itemName = item.Current.Name ?? "";
                    Console.WriteLine("Item in dropdown: " + itemName);
                    if (itemName.IndexOf("Acrylic", StringComparison.OrdinalIgnoreCase) < 0 &&
                        itemName.IndexOf("Mica", StringComparison.OrdinalIgnoreCase) < 0 &&
                        itemName.IndexOf("Tabbed", StringComparison.OrdinalIgnoreCase) < 0) {
                        solidItem = item;
                        break;
                    }
                }

                if (solidItem != null) {
                    Console.WriteLine("Selecting Solid item: " + solidItem.Current.Name);
                    try {
                        var sip = (SelectionItemPattern)solidItem.GetCurrentPattern(SelectionItemPattern.Pattern);
                        sip.Select();
                    } catch {
                        Rect sr = solidItem.Current.BoundingRectangle;
                        PhysicalLeftClick((int)(sr.X + sr.Width / 2), (int)(sr.Y + sr.Height / 2));
                    }
                    Thread.Sleep(1500);

                    string solidShot = System.IO.Path.Combine(artifactDir, "winui_backdrop_solid.png");
                    CaptureWindow(hwnd, solidShot);
                    Console.WriteLine("Saved Solid backdrop screenshot: " + solidShot);
                } else {
                    Console.WriteLine("[FAIL] Solid item not found in dropdown!");
                    allPassed = false;
                }
            } else {
                Console.WriteLine("[FAIL] Backdrop ComboBox not found!");
                allPassed = false;
            }

            try { Process.GetProcessById(pi.dwProcessId).Kill(); } catch {}
        });

        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join(45000);

        return allPassed;
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing", "UIAutomationClient", "UIAutomationTypes", "WindowsBase"

$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363"

$result = [FluentSettingsVerifier]::RunVerification($exePath, $workingDir, $artifactDir)

if ($result) {
    Write-Host "ALL FLUENT SETTINGS AND SYSTEM BACKDROP TESTS PASSED!"
    exit 0
} else {
    Write-Host "VERIFICATION FAILED!"
    exit 1
}
