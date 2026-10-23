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

public class TabStaleReproducer {
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

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
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

    public static void Run(string exePath, string workingDir, string outputDir) {
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

            CaptureWindow(hwnd, Path.Combine(outputDir, "step0_initial_home.png"));
            Console.WriteLine("[Step 0] Initial Home captured.");

            // Step 1: Click "Cơ sở dữ liệu" (Database button on Home)
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
            }

            // Wait until TabItems count is at least 2
            AutomationElementCollection tabItems = null;
            for (int w = 0; w < 10; w++) {
                Thread.Sleep(500);
                tabItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                if (tabItems.Count >= 2) break;
            }
            Console.WriteLine("After Step 1, TabItems count: " + (tabItems != null ? tabItems.Count : 0));
            CaptureWindow(hwnd, Path.Combine(outputDir, "step1_database_opened.png"));
            Console.WriteLine("[Step 1] Database tab opened.");

            // Step 2: Click Home tab (first TabItem)
            if (tabItems != null && tabItems.Count > 0) {
                Rect r = tabItems[0].Current.BoundingRectangle;
                Console.WriteLine("Clicking Home Tab: X=" + (r.X + r.Width/2) + " Y=" + (r.Y + r.Height/2));
                PhysicalLeftClick((int)(r.X + r.Width/2), (int)(r.Y + r.Height/2));
                Thread.Sleep(1500);
            }
            CaptureWindow(hwnd, Path.Combine(outputDir, "step2_back_to_home.png"));
            Console.WriteLine("[Step 2] Back to Home captured.");

            // Step 3: Open Settings tab from Home
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
            }

            // Wait until TabItems count is at least 3
            for (int w = 0; w < 10; w++) {
                Thread.Sleep(500);
                tabItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                if (tabItems.Count >= 3) break;
            }
            Console.WriteLine("After Step 3, TabItems count: " + (tabItems != null ? tabItems.Count : 0));
            CaptureWindow(hwnd, Path.Combine(outputDir, "step3_settings_opened.png"));
            Console.WriteLine("[Step 3] Settings tab opened.");

            // Step 4: Close Tab 1 ("Cơ sở dữ liệu") while Tab 2 ("Cài đặt") is currently selected
            for (int i = 0; i < tabItems.Count; i++) {
                Console.WriteLine("Tab " + i + ": Name='" + tabItems[i].Current.Name + "' Bounds=" + tabItems[i].Current.BoundingRectangle);
            }

            if (tabItems.Count >= 3) {
                AutomationElement dbTab = tabItems[1]; // Tab 1 is Database
                var closeBtns = dbTab.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
                Console.WriteLine("Close buttons in Database tab: " + closeBtns.Count);
                if (closeBtns.Count > 0) {
                    Rect r = closeBtns[0].Current.BoundingRectangle;
                    Console.WriteLine("Clicking close button on Tab 1 (Database): X=" + (r.X + r.Width/2) + " Y=" + (r.Y + r.Height/2));
                    PhysicalLeftClick((int)(r.X + r.Width/2), (int)(r.Y + r.Height/2));
                }
            }

            // Wait until TabItems count becomes 2
            for (int w = 0; w < 10; w++) {
                Thread.Sleep(500);
                tabItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                if (tabItems.Count <= 2) break;
            }
            Thread.Sleep(1000); // Allow smooth animation to finish

            CaptureWindow(hwnd, Path.Combine(outputDir, "step4_after_closing_database_tab.png"));
            Console.WriteLine("[Step 4] Captured after closing Database tab. Tab 2 (Settings) is now Tab 1.");

            tabItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
            Console.WriteLine("TabItems remaining after closing Database tab: " + tabItems.Count);
            for (int i = 0; i < tabItems.Count; i++) {
                Console.WriteLine("Remaining Tab " + i + ": Name='" + tabItems[i].Current.Name + "' Bounds=" + tabItems[i].Current.BoundingRectangle);
            }

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
$bugDir = "D:\DEV\WinUI\DataSphere\.specify\bugs\tab-selection-background-not-updated-on-close"
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\bed6b624-6a96-45dd-963c-7b8ea009ac6a"

if (!(Test-Path $bugDir)) {
    New-Item -ItemType Directory -Path $bugDir -Force | Out-Null
}

# Kill any existing DataSphere instances first
Get-Process -Name "DataSphere" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500

[TabStaleReproducer]::Run($exePath, $workingDir, $bugDir)

# Also copy screenshots to artifact dir
Copy-Item "$bugDir\*.png" -Destination $artifactDir -Force
Write-Host "Verification complete. Screenshots saved to $bugDir and $artifactDir"
