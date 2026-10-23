$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class TabBugReproducer {
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
        Thread.Sleep(150);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(80);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(500);
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

    public static void Run(string exePath, string workingDir, string artifactDir) {
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) {
                Console.WriteLine("Failed to open desktop!");
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
                Console.WriteLine("Could not find window!");
                try { Process.GetProcessById(pi.dwProcessId).Kill(); } catch {}
                return;
            }

            SetForegroundWindow(hwnd);
            Thread.Sleep(2000);

            CaptureWindow(hwnd, Path.Combine(artifactDir, "step0_initial_home.png"));
            Console.WriteLine("[Step 0] Initial Home captured.");

            // Step 1: Click "Cơ sở dữ liệu" (Database card on Home)
            AutomationElement dbBtn = null;
            var buttons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
            foreach (AutomationElement btn in buttons) {
                Rect r = btn.Current.BoundingRectangle;
                if (r.Width > 200 && r.Height > 60) {
                    if (dbBtn == null || r.X < dbBtn.Current.BoundingRectangle.X) {
                        dbBtn = btn;
                    }
                }
            }

            if (dbBtn != null) {
                Rect r = dbBtn.Current.BoundingRectangle;
                Console.WriteLine("Clicking Database Button: X=" + (r.X + r.Width/2) + " Y=" + (r.Y + r.Height/2));
                PhysicalLeftClick((int)(r.X + r.Width/2), (int)(r.Y + r.Height/2));
                Thread.Sleep(1500);
            }
            CaptureWindow(hwnd, Path.Combine(artifactDir, "step1_database_opened.png"));
            Console.WriteLine("[Step 1] Database tab opened.");

            // Step 2: Click Home tab (first TabItem)
            var tabItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
            Console.WriteLine("Current TabItems count: " + tabItems.Count);
            if (tabItems.Count > 0) {
                Rect r = tabItems[0].Current.BoundingRectangle;
                Console.WriteLine("Clicking Home Tab: X=" + (r.X + r.Width/2) + " Y=" + (r.Y + r.Height/2));
                PhysicalLeftClick((int)(r.X + r.Width/2), (int)(r.Y + r.Height/2));
                Thread.Sleep(1500);
            }
            CaptureWindow(hwnd, Path.Combine(artifactDir, "step2_back_to_home.png"));
            Console.WriteLine("[Step 2] Back to Home captured.");

            // Step 3: Open Settings (or Database) tab from Home
            buttons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
            AutomationElement settingsBtn = null;
            foreach (AutomationElement btn in buttons) {
                Rect r = btn.Current.BoundingRectangle;
                if (r.Width > 200 && r.Height > 60) {
                    if (settingsBtn == null || r.X > settingsBtn.Current.BoundingRectangle.X) {
                        settingsBtn = btn;
                    }
                }
            }
            if (settingsBtn != null) {
                Rect r = settingsBtn.Current.BoundingRectangle;
                Console.WriteLine("Clicking Settings Button: X=" + (r.X + r.Width/2) + " Y=" + (r.Y + r.Height/2));
                PhysicalLeftClick((int)(r.X + r.Width/2), (int)(r.Y + r.Height/2));
                Thread.Sleep(1500);
            }
            CaptureWindow(hwnd, Path.Combine(artifactDir, "step3_settings_opened.png"));
            Console.WriteLine("[Step 3] Settings tab opened.");

            // Step 4: Close all tabs from the right
            // First close rightmost tab (Settings)
            tabItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
            Console.WriteLine("TabItems before closing: " + tabItems.Count);
            for (int i = 0; i < tabItems.Count; i++) {
                Console.WriteLine("Tab " + i + ": Name='" + tabItems[i].Current.Name + "' Bounds=" + tabItems[i].Current.BoundingRectangle);
            }

            // Close rightmost tab (tab index 2)
            if (tabItems.Count >= 3) {
                AutomationElement rightTab = tabItems[2];
                // Find close button inside rightTab
                var closeBtns = rightTab.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
                Console.WriteLine("Close buttons in right tab: " + closeBtns.Count);
                if (closeBtns.Count > 0) {
                    Rect r = closeBtns[0].Current.BoundingRectangle;
                    Console.WriteLine("Clicking close button on tab 2: X=" + (r.X + r.Width/2) + " Y=" + (r.Y + r.Height/2));
                    PhysicalLeftClick((int)(r.X + r.Width/2), (int)(r.Y + r.Height/2));
                    Thread.Sleep(1500);
                }
            }
            CaptureWindow(hwnd, Path.Combine(artifactDir, "step4a_closed_rightmost.png"));

            // Now close the next dynamic tab (Database, tab index 1)
            tabItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
            Console.WriteLine("TabItems after closing 1 tab: " + tabItems.Count);
            if (tabItems.Count >= 2) {
                AutomationElement lastDynamicTab = tabItems[1];
                var closeBtns = lastDynamicTab.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
                Console.WriteLine("Close buttons in last dynamic tab: " + closeBtns.Count);
                if (closeBtns.Count > 0) {
                    Rect r = closeBtns[0].Current.BoundingRectangle;
                    Console.WriteLine("Clicking close button on tab 1: X=" + (r.X + r.Width/2) + " Y=" + (r.Y + r.Height/2));
                    PhysicalLeftClick((int)(r.X + r.Width/2), (int)(r.Y + r.Height/2));
                    Thread.Sleep(1500);
                }
            }
            CaptureWindow(hwnd, Path.Combine(artifactDir, "step4b_all_closed_at_home.png"));
            Console.WriteLine("[Step 4] All dynamic tabs closed.");

            // Step 5: Now create a new tab from Home (e.g. Settings or Database)
            buttons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
            AutomationElement newTabBtn = null;
            foreach (AutomationElement btn in buttons) {
                Rect r = btn.Current.BoundingRectangle;
                if (r.Width > 200 && r.Height > 60) {
                    // Let's pick Settings button or Database button
                    newTabBtn = btn;
                    break;
                }
            }

            if (newTabBtn != null) {
                Rect r = newTabBtn.Current.BoundingRectangle;
                Console.WriteLine("Clicking Button to create new tab: X=" + (r.X + r.Width/2) + " Y=" + (r.Y + r.Height/2));
                PhysicalLeftClick((int)(r.X + r.Width/2), (int)(r.Y + r.Height/2));
                Thread.Sleep(2000);
            }
            CaptureWindow(hwnd, Path.Combine(artifactDir, "step5_new_tab_reproduced.png"));
            Console.WriteLine("[Step 5] New tab opened after closing all tabs captured.");

            Thread.Sleep(1000);
            try { Process.GetProcessById(pi.dwProcessId).Kill(); } catch {}
        });

        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join();
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing", "UIAutomationClient", "UIAutomationTypes", "WindowsBase"

$exePath = "D:\DEV\WinUI\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\WinUI\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\bed6b624-6a96-45dd-963c-7b8ea009ac6a"

# Kill any existing DataSphere instances first
Get-Process -Name "DataSphere" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500

[TabBugReproducer]::Run($exePath, $workingDir, $artifactDir)
