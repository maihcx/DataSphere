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

public class InnerTabTearOffVerifier {
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

    public static void PhysicalDoubleClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(150);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(80);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(500);
    }

    public static void PhysicalDragAndDrop(int startX, int startY, int endX, int endY) {
        SetCursorPos(startX, startY);
        Thread.Sleep(200);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)startX, (uint)startY, 0, UIntPtr.Zero);
        Thread.Sleep(250);

        int steps = 25;
        for (int i = 1; i <= steps; i++) {
            int cx = startX + (endX - startX) * i / steps;
            int cy = startY + (endY - startY) * i / steps;
            SetCursorPos(cx, cy);
            Thread.Sleep(20);
        }

        Thread.Sleep(300);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)endX, (uint)endY, 0, UIntPtr.Zero);
        Thread.Sleep(1000);
    }

    public static void CaptureWindow(IntPtr hwnd, string savePath) {
        RECT rc;
        GetWindowRect(hwnd, out rc);
        int w = Math.Max(rc.Right - rc.Left, 100);
        int h = Math.Max(rc.Bottom - rc.Top, 100);
        using (Bitmap bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb)) {
            using (Graphics g = Graphics.FromImage(bmp)) {
                IntPtr hdc = g.GetHdc();
                try {
                    PrintWindow(hwnd, hdc, 2); // PW_RENDERFULLCONTENT = 2
                } finally {
                    g.ReleaseHdc(hdc);
                }
            }
            bmp.Save(savePath, ImageFormat.Png);
        }
    }

    public static void Run(string exePath, string workingDir, string outputDir) {
        Thread t = new Thread(() => {
            IntPtr hDesktop = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesktop != IntPtr.Zero) {
                SetThreadDesktop(hDesktop);
            }

            STARTUPINFO si = new STARTUPINFO();
            si.cb = Marshal.SizeOf(si);
            si.lpDesktop = @"WinSta0\default";

            PROCESS_INFORMATION pi = new PROCESS_INFORMATION();

            bool success = CreateProcess(
                exePath,
                null,
                IntPtr.Zero,
                IntPtr.Zero,
                false,
                0,
                IntPtr.Zero,
                workingDir,
                ref si,
                out pi);

            if (!success) {
                Console.WriteLine("CreateProcess failed: " + Marshal.GetLastWin32Error());
                return;
            }

            Console.WriteLine("Launched DataSphere PID: " + pi.dwProcessId);

            AutomationElement appWin = null;
            for (int i = 0; i < 40; i++) {
                Thread.Sleep(500);
                appWin = AutomationElement.RootElement.FindFirst(
                    TreeScope.Children,
                    new PropertyCondition(AutomationElement.ProcessIdProperty, pi.dwProcessId));
                if (appWin != null) break;
            }

            if (appWin == null) {
                Console.WriteLine("Window not found.");
                return;
            }

            IntPtr hwnd = (IntPtr)appWin.Current.NativeWindowHandle;
            SetForegroundWindow(hwnd);
            Thread.Sleep(1500);

            // Step 1: Open Databases page
            var buttons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
            AutomationElement dbButton = null;
            for (int i = 0; i < buttons.Count; i++) {
                string name = buttons[i].Current.Name;
                if (name.Contains("li?u") || name.Contains("Database") || name.Contains("Co s?")) {
                    dbButton = buttons[i];
                    break;
                }
            }

            if (dbButton == null && buttons.Count >= 2) {
                dbButton = buttons[1];
            }

            if (dbButton != null) {
                Rect r = dbButton.Current.BoundingRectangle;
                PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
            }
            Thread.Sleep(2000);

            // Step 2: Open connection 'localhost'
            var treeItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TreeItem));
            if (treeItems.Count > 0) {
                Rect r = treeItems[0].Current.BoundingRectangle;
                PhysicalDoubleClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
            }
            Thread.Sleep(2500);

            // Step 3: Find Database tab in shell window and drag it out to tear off
            var tabsBefore = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
            if (tabsBefore.Count >= 2) {
                AutomationElement dbTab = tabsBefore[1];
                Rect r = dbTab.Current.BoundingRectangle;
                int startX = (int)(r.X + r.Width / 2);
                int startY = (int)(r.Y + r.Height / 2);
                int endX = startX;
                int endY = (int)(r.Y - 150);

                Console.WriteLine("Tearing off Database tab...");
                PhysicalDragAndDrop(startX, startY, endX, endY);
            }
            Thread.Sleep(2500);

            // Step 4: Find new window
            var allWindows = AutomationElement.RootElement.FindAll(TreeScope.Children, new PropertyCondition(AutomationElement.ProcessIdProperty, pi.dwProcessId));
            AutomationElement newWin = null;
            for (int i = 0; i < allWindows.Count; i++) {
                IntPtr h = (IntPtr)allWindows[i].Current.NativeWindowHandle;
                if (h != hwnd) {
                    newWin = allWindows[i];
                }
            }

            if (newWin != null) {
                IntPtr newHwnd = (IntPtr)newWin.Current.NativeWindowHandle;
                SetForegroundWindow(newHwnd);
                Thread.Sleep(1000);

                var tabsInNewWin = newWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                AutomationElement connTab = null;
                for (int i = 0; i < tabsInNewWin.Count; i++) {
                    string name = tabsInNewWin[i].Current.Name;
                    if (name.Contains("n?i") || name.Contains("Connect") || name.Contains("K?t")) {
                        connTab = tabsInNewWin[i];
                        break;
                    }
                }

                if (connTab == null && tabsInNewWin.Count >= 3) {
                    connTab = tabsInNewWin[2];
                }

                if (connTab != null) {
                    Rect r = connTab.Current.BoundingRectangle;
                    Console.WriteLine("Clicking Connection Tab in new window at (" + (r.X + r.Width/2) + ", " + (r.Y + r.Height/2) + ")...");
                    PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(2000);
                }

                CaptureWindow(newHwnd, Path.Combine(outputDir, "verify_step4_connection_in_new_win.png"));
                Console.WriteLine("[Verification] Captured verify_step4_connection_in_new_win.png");
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
$bugDir = "D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule"
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\bed6b624-6a96-45dd-963c-7b8ea009ac6a"

Get-Process -Name "DataSphere" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500

[InnerTabTearOffVerifier]::Run($exePath, $workingDir, $bugDir)

Copy-Item "$bugDir\verify_step4_connection_in_new_win.png" -Destination $artifactDir -Force -ErrorAction SilentlyContinue
Write-Host "Verification run completed."
