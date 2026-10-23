$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class ThemeTransitionVerifier {
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

    public static bool RunVerification(string exePath, string workingDir, string outDir) {
        bool success = true;
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) {
                Console.WriteLine("Failed to open desktop!");
                success = false;
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
                success = false;
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
                success = false;
                return;
            }

            SetForegroundWindow(hwnd);
            Thread.Sleep(2500);

            // Navigate to Settings
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
                Console.WriteLine("Clicking Settings button at (" + cx + ", " + cy + ")");
                try {
                    var invoke = (InvokePattern)settingsBtn.GetCurrentPattern(InvokePattern.Pattern);
                    invoke.Invoke();
                } catch {
                    PhysicalLeftClick(cx, cy);
                }
            } else {
                Console.WriteLine("Settings button NOT found!");
                success = false;
            }

            Thread.Sleep(2000);

            // Step 1: Capture initial Settings state
            string shotInitial = System.IO.Path.Combine(outDir, "verified_settings_initial.png");
            CaptureWindow(hwnd, shotInitial);
            Console.WriteLine("Captured: " + shotInitial);

            // Step 2: Locate Theme ComboBox and Backdrop ComboBox
            var allCombos = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ComboBox));
            Console.WriteLine("Found " + allCombos.Count + " ComboBoxes.");

            AutomationElement themeCombo = null;
            AutomationElement backdropCombo = null;

            if (allCombos.Count >= 1) themeCombo = allCombos[0];
            if (allCombos.Count >= 2) backdropCombo = allCombos[1];

            // Step 3: Trigger Theme Switch to Dark (item index 1)
            if (themeCombo != null) {
                Rect tcRect = themeCombo.Current.BoundingRectangle;
                int tcX = (int)(tcRect.X + tcRect.Width / 2);
                int tcY = (int)(tcRect.Y + tcRect.Height / 2);
                Console.WriteLine("Expanding Theme ComboBox...");
                try {
                    var ecp = (ExpandCollapsePattern)themeCombo.GetCurrentPattern(ExpandCollapsePattern.Pattern);
                    ecp.Expand();
                } catch {
                    PhysicalLeftClick(tcX, tcY);
                }
                Thread.Sleep(800);

                var procCond = new PropertyCondition(AutomationElement.ProcessIdProperty, pi.dwProcessId);
                var listTypeCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ListItem);
                var themeItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new AndCondition(procCond, listTypeCond));
                Console.WriteLine("Theme dropdown items: " + themeItems.Count);

                if (themeItems.Count >= 2) {
                    var darkItem = themeItems[1]; // Dark / Tối
                    Console.WriteLine("Selecting Dark theme option...");
                    try {
                        var sip = (SelectionItemPattern)darkItem.GetCurrentPattern(SelectionItemPattern.Pattern);
                        sip.Select();
                    } catch {
                        Rect dr = darkItem.Current.BoundingRectangle;
                        PhysicalLeftClick((int)(dr.X + dr.Width / 2), (int)(dr.Y + dr.Height / 2));
                    }

                    // Give transition 600ms to complete smoothly
                    Thread.Sleep(800);
                    string shotDark = System.IO.Path.Combine(outDir, "verified_theme_dark.png");
                    CaptureWindow(hwnd, shotDark);
                    Console.WriteLine("Captured Dark theme: " + shotDark);
                }
            }

            // Step 4: Trigger Backdrop Switch to Acrylic (item index 2)
            if (backdropCombo != null) {
                Rect bcRect = backdropCombo.Current.BoundingRectangle;
                int bcX = (int)(bcRect.X + bcRect.Width / 2);
                int bcY = (int)(bcRect.Y + bcRect.Height / 2);
                Console.WriteLine("Expanding Backdrop ComboBox...");
                try {
                    var ecp = (ExpandCollapsePattern)backdropCombo.GetCurrentPattern(ExpandCollapsePattern.Pattern);
                    ecp.Expand();
                } catch {
                    PhysicalLeftClick(bcX, bcY);
                }
                Thread.Sleep(800);

                var procCond = new PropertyCondition(AutomationElement.ProcessIdProperty, pi.dwProcessId);
                var listTypeCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ListItem);
                var backdropItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new AndCondition(procCond, listTypeCond));
                Console.WriteLine("Backdrop dropdown items: " + backdropItems.Count);

                if (backdropItems.Count >= 3) {
                    var acrylicItem = backdropItems[2]; // Acrylic
                    Console.WriteLine("Selecting Acrylic backdrop...");
                    try {
                        var sip = (SelectionItemPattern)acrylicItem.GetCurrentPattern(SelectionItemPattern.Pattern);
                        sip.Select();
                    } catch {
                        Rect ar = acrylicItem.Current.BoundingRectangle;
                        PhysicalLeftClick((int)(ar.X + ar.Width / 2), (int)(ar.Y + ar.Height / 2));
                    }

                    Thread.Sleep(800);
                    string shotAcrylic = System.IO.Path.Combine(outDir, "verified_backdrop_acrylic.png");
                    CaptureWindow(hwnd, shotAcrylic);
                    Console.WriteLine("Captured Acrylic backdrop: " + shotAcrylic);
                }
            }

            Thread.Sleep(1000);
            try { Process.GetProcessById(pi.dwProcessId).Kill(); } catch {}
            Console.WriteLine("Verification run finished successfully.");
        });

        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join(45000);

        return success;
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing", "UIAutomationClient", "UIAutomationTypes", "WindowsBase"

$exePath = "D:\DEV\WinUI\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\WinUI\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"
$outDir = "C:\Users\huynh\.gemini\antigravity\brain\b7280d00-69f1-4ef4-b69b-8de3d7a295a9"

[ThemeTransitionVerifier]::RunVerification($exePath, $workingDir, $outDir)
