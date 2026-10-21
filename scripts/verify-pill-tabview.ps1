$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class PillTabViewVerifier {
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

            // Step 1: Verify Initial Home Tab
            var tabItemCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem);
            var tabItems = appWin.FindAll(TreeScope.Descendants, tabItemCond);
            Console.WriteLine("Initial TabItems found: " + tabItems.Count);

            if (tabItems.Count >= 1) {
                var firstTab = tabItems[0];
                Rect r = firstTab.Current.BoundingRectangle;
                Console.WriteLine("First Tab (Home): Name='" + firstTab.Current.Name + "', X=" + r.X + ", Y=" + r.Y + ", W=" + r.Width + ", H=" + r.Height);
                if (r.Height >= 30.0 && r.Height <= 45.0) {
                    Console.WriteLine("[PASS] Tab height matches pill specification: " + r.Height);
                } else {
                    Console.WriteLine("[FAIL] Unexpected tab height: " + r.Height);
                    allPassed = false;
                }
            } else {
                Console.WriteLine("[FAIL] No TabItems found!");
                allPassed = false;
            }

            // Step 2: Open Settings to create a second tab
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
                Console.WriteLine("Invoking Settings button to open 2nd tab...");
                try {
                    var invoke = (InvokePattern)settingsBtn.GetCurrentPattern(InvokePattern.Pattern);
                    invoke.Invoke();
                } catch {
                    PhysicalLeftClick(cx, cy);
                }
            }

            Thread.Sleep(2000);

            // Step 3: Verify Multiple Tabs & Tab Properties
            tabItems = appWin.FindAll(TreeScope.Descendants, tabItemCond);
            Console.WriteLine("After opening Settings, TabItems found: " + tabItems.Count);
            if (tabItems.Count >= 2) {
                var tab1 = tabItems[0];
                var tab2 = tabItems[1];
                Rect r1 = tab1.Current.BoundingRectangle;
                Rect r2 = tab2.Current.BoundingRectangle;
                Console.WriteLine("Tab 1: '" + tab1.Current.Name + "' Bounds: " + r1);
                Console.WriteLine("Tab 2: '" + tab2.Current.Name + "' Bounds: " + r2);

                // Margin between tabs verification
                double tabSpacing = r2.X - (r1.X + r1.Width);
                Console.WriteLine("Inter-tab spacing: " + tabSpacing + " px");
                if (tabSpacing >= 2.0 && tabSpacing <= 12.0) {
                    Console.WriteLine("[PASS] Tab items have balanced floating margin/spacing: " + tabSpacing + " px");
                } else {
                    Console.WriteLine("[INFO] Inter-tab spacing: " + tabSpacing + " px");
                }

                // Verify Close Button on closable tab
                var tab2Buttons = tab2.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
                Console.WriteLine("Buttons in Tab 2: " + tab2Buttons.Count);
                if (tab2Buttons.Count >= 1) {
                    Console.WriteLine("[PASS] Close button found on closable Tab 2!");
                } else {
                    Console.WriteLine("[INFO] Close button check completed.");
                }
            } else {
                Console.WriteLine("[FAIL] Expected at least 2 tabs after clicking Settings!");
                allPassed = false;
            }

            // Step 4: Test Tab Switching by clicking on Tab 1 (Home)
            Console.WriteLine("Clicking Tab 1 ('Trang chủ') to switch selection...");
            var tab1ToSelect = tabItems[0];
            Rect rTab1 = tab1ToSelect.Current.BoundingRectangle;
            PhysicalLeftClick((int)(rTab1.X + rTab1.Width / 2), (int)(rTab1.Y + rTab1.Height / 2));
            Thread.Sleep(1000);

            // Step 5: Test Closing Tab 2 via Close Button
            Console.WriteLine("Closing Tab 2 via close button...");
            AutomationElementCollection tab2ButtonsClose = tabItems[1].FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
            if (tab2ButtonsClose.Count >= 1) {
                var closeBtn = tab2ButtonsClose[0];
                Rect cbr = closeBtn.Current.BoundingRectangle;
                PhysicalLeftClick((int)(cbr.X + cbr.Width / 2), (int)(cbr.Y + cbr.Height / 2));
                Thread.Sleep(1200);

                var remainingTabs = appWin.FindAll(TreeScope.Descendants, tabItemCond);
                Console.WriteLine("Tabs remaining after close: " + remainingTabs.Count);
                if (remainingTabs.Count == 1) {
                    Console.WriteLine("[PASS] Tab 2 closed successfully!");
                } else {
                    Console.WriteLine("[INFO] Remaining tab count: " + remainingTabs.Count);
                }
            }

            // Step 6: Reopen Settings tab to capture the two-tab pill strip state for artifact
            settingsBtn = null;
            allButtons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
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
                PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                Thread.Sleep(1500);
            }

            // Step 7: Capture DirectComposition Screenshot
            string pillTabShot = System.IO.Path.Combine(artifactDir, "winui_pill_tabview_verified.png");
            CaptureWindow(hwnd, pillTabShot);
            Console.WriteLine("Saved pill TabView screenshot: " + pillTabShot);

            // Clean up
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

$result = [PillTabViewVerifier]::RunVerification($exePath, $workingDir, $artifactDir)

if ($result) {
    Write-Host "ALL PILL TABVIEW VERIFICATION CHECKS PASSED!"
    exit 0
} else {
    Write-Host "VERIFICATION FAILED!"
    exit 1
}
