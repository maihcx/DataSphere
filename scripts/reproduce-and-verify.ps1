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

public class ReproduceAndVerify {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct STARTUPINFO {
        public int cb;
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
        public int dwX, dwY, dwXSize, dwYSize;
        public int dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
        public short wShowWindow, cbReserved2;
        public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION {
        public IntPtr hProcess, hThread;
        public int dwProcessId, dwThreadId;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

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

    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, uint nFlags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);

    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;

    public static void PhysicalLeftClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(200);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
        Thread.Sleep(120);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
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
                    PrintWindow(hwnd, hdc, 2);
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
            SetThreadDesktop(hDesk);

            STARTUPINFO si = new STARTUPINFO();
            si.cb = Marshal.SizeOf(si);
            si.lpDesktop = @"WinSta0\default";
            PROCESS_INFORMATION pi = new PROCESS_INFORMATION();

            bool ok = CreateProcess(exePath, null, IntPtr.Zero, IntPtr.Zero, false, 0, IntPtr.Zero, workingDir, ref si, out pi);
            if (!ok) {
                Console.WriteLine("CreateProcess failed");
                return;
            }

            Console.WriteLine("Launched PID: " + pi.dwProcessId);
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
                Console.WriteLine("Window not found");
                try { Process.GetProcessById(pi.dwProcessId).Kill(); } catch {}
                return;
            }

            SetForegroundWindow(hwnd);
            Thread.Sleep(1500);

            Console.WriteLine("Step 1: Clicking Database button on Home page...");
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
                Console.WriteLine("Found dbBtn at: " + r);
                PhysicalLeftClick((int)(r.X + r.Width/2), (int)(r.Y + r.Height/2));
            } else {
                Console.WriteLine("dbBtn not found!");
            }
            Thread.Sleep(2000);
            CaptureWindow(hwnd, Path.Combine(outputDir, "diag_step1_db_page.png"));

            // 2. Double-click localhost in connection tree
            Console.WriteLine("Step 2: Double-clicking localhost in connection tree...");
            var treeItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TreeItem));
            Console.WriteLine("TreeItems found: " + treeItems.Count);
            if (treeItems.Count > 0) {
                Rect r = treeItems[0].Current.BoundingRectangle;
                Console.WriteLine("TreeItem 0: " + treeItems[0].Current.Name + " at " + r);
                PhysicalDoubleClick((int)(r.X + r.Width/2), (int)(r.Y + r.Height/2));
            }
            Thread.Sleep(2500);
            CaptureWindow(hwnd, Path.Combine(outputDir, "diag_step2_connection_opened.png"));

            // 3. Tear off Databases tab
            Console.WriteLine("Step 3: Finding tabs to tear off...");
            var tabsBefore = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
            Console.WriteLine("Tabs before drag: " + tabsBefore.Count);
            for (int i = 0; i < tabsBefore.Count; i++) {
                Console.WriteLine("  tabBefore " + i + ": " + tabsBefore[i].Current.Name + " at " + tabsBefore[i].Current.BoundingRectangle);
            }

            if (tabsBefore.Count >= 2) {
                AutomationElement dbTab = tabsBefore[1];
                Rect r = dbTab.Current.BoundingRectangle;
                int startX = (int)(r.X + r.Width/2);
                int startY = (int)(r.Y + r.Height/2);
                int endX = startX;
                int endY = (int)(r.Y - 150);
                Console.WriteLine("Dragging from (" + startX + "," + startY + ") to (" + endX + "," + endY + ")...");
                PhysicalDragAndDrop(startX, startY, endX, endY);
            }
            Thread.Sleep(2500);

            // 4. Find new torn-off window
            var allWindows = AutomationElement.RootElement.FindAll(TreeScope.Children, new PropertyCondition(AutomationElement.ProcessIdProperty, pi.dwProcessId));
            Console.WriteLine("All windows for PID " + pi.dwProcessId + ": " + allWindows.Count);
            AutomationElement newWin = null;
            for (int i = 0; i < allWindows.Count; i++) {
                IntPtr h = (IntPtr)allWindows[i].Current.NativeWindowHandle;
                Console.WriteLine("Window " + i + ": hwnd=" + h + " class=" + allWindows[i].Current.ClassName + " name='" + allWindows[i].Current.Name + "' rect=" + allWindows[i].Current.BoundingRectangle);
                if (h != hwnd) {
                    newWin = allWindows[i];
                }
            }

            if (newWin != null) {
                IntPtr newHwnd = (IntPtr)newWin.Current.NativeWindowHandle;
                RECT newRc;
                GetWindowRect(newHwnd, out newRc);
                Console.WriteLine("New window rect: (" + newRc.Left + "," + newRc.Top + ")-(" + newRc.Right + "," + newRc.Bottom + ")");

                // Activate new window
                PhysicalLeftClick(newRc.Left + 600, newRc.Top + 20);
                SetForegroundWindow(newHwnd);
                Thread.Sleep(1000);

                var tabsInNewWin = newWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                Console.WriteLine("Tab count in new window: " + tabsInNewWin.Count);
                AutomationElement connTab = null;
                for (int i = 0; i < tabsInNewWin.Count; i++) {
                    string name = tabsInNewWin[i].Current.Name;
                    Console.WriteLine("NewWin tab " + i + ": " + name + " Bounds=" + tabsInNewWin[i].Current.BoundingRectangle);
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
                    int cx = (int)(r.X + r.Width / 2);
                    int cy = (int)(r.Y + r.Height / 2);
                    Console.WriteLine("Clicking Connection Tab at X=" + cx + " Y=" + cy);
                    PhysicalLeftClick(cx, cy);
                    Thread.Sleep(2000);
                }

                string outPath = Path.Combine(outputDir, "verified_step4_connection_selected.png");
                CaptureWindow(newHwnd, outPath);
                Console.WriteLine("Captured: " + outPath);

                CaptureWindow(hwnd, Path.Combine(outputDir, "verified_step4_main_win.png"));
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

[ReproduceAndVerify]::Run($exePath, $workingDir, $bugDir)

Copy-Item "$bugDir\verified_step4_connection_selected.png" -Destination $artifactDir -Force -ErrorAction SilentlyContinue
Write-Host "Test completed successfully."
