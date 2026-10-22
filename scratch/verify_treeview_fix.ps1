$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class TreeViewFixVerifier {
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

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseDesktop(IntPtr hDesktop);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, int dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, int nFlags);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;

    public static int LaunchApp(string exePath, string workingDir) {
        STARTUPINFO si = new STARTUPINFO();
        si.cb = Marshal.SizeOf(si);
        si.lpDesktop = @"WinSta0\default";

        PROCESS_INFORMATION pi = new PROCESS_INFORMATION();
        bool success = CreateProcess(exePath, null, IntPtr.Zero, IntPtr.Zero, false, 0, IntPtr.Zero, workingDir, ref si, out pi);
        if (!success) {
            int err = Marshal.GetLastWin32Error();
            throw new InvalidOperationException("CreateProcess on WinSta0\\default failed: " + err);
        }
        return pi.dwProcessId;
    }

    public static void PhysicalLeftClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(300);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(600);
    }

    public static void PhysicalDoubleClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(200);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(50);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(80);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(50);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(600);
    }

    public static void CaptureScreenshot(IntPtr hwnd, string path) {
        RECT winR;
        GetWindowRect(hwnd, out winR);
        int w = winR.Right - winR.Left;
        int h = winR.Bottom - winR.Top;
        if (w > 0 && h > 0) {
            using (Bitmap bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb)) {
                using (Graphics g = Graphics.FromImage(bmp)) {
                    IntPtr hdc = g.GetHdc();
                    bool ok = PrintWindow(hwnd, hdc, 2);
                    if (!ok) PrintWindow(hwnd, hdc, 0);
                    g.ReleaseHdc(hdc);
                }
                bmp.Save(path, ImageFormat.Png);
            }
        }
    }

    public static string ExecuteVerification(int pid, string shotSingleClick, string shotDoubleTap) {
        string log = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) {
                log += "Failed to open default desktop: " + Marshal.GetLastWin32Error() + "\n";
                return;
            }

            SetThreadDesktop(hDesk);

            try {
                AutomationElement appWin = null;
                IntPtr hwnd = IntPtr.Zero;

                for (int i = 0; i < 30; i++) {
                    Thread.Sleep(300);
                    var cond = new PropertyCondition(AutomationElement.ProcessIdProperty, pid);
                    appWin = AutomationElement.RootElement.FindFirst(TreeScope.Children, cond);
                    if (appWin != null) {
                        hwnd = (IntPtr)appWin.Current.NativeWindowHandle;
                        log += "Found DataSphere window (HWND=" + hwnd + ")\n";
                        break;
                    }
                }

                if (appWin == null) {
                    log += "ERROR: Window not found for PID " + pid + "\n";
                    return;
                }

                SetForegroundWindow(hwnd);
                Thread.Sleep(1500);

                // 1. Click Database Card on Home page
                var btnCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button);
                var allButtons = appWin.FindAll(TreeScope.Descendants, btnCond);
                AutomationElement dbBtn = null;

                foreach (AutomationElement btn in allButtons) {
                    Rect r = btn.Current.BoundingRectangle;
                    if (r.Width > 200 && r.Height > 60) {
                        if (dbBtn == null || r.X < dbBtn.Current.BoundingRectangle.X) {
                            dbBtn = btn;
                        }
                    }
                }

                if (dbBtn != null) {
                    Rect rect = dbBtn.Current.BoundingRectangle;
                    int cx = (int)(rect.X + rect.Width / 2);
                    int cy = (int)(rect.Y + rect.Height / 2);
                    log += "Clicking Database Card at (" + cx + ", " + cy + ")...\n";
                    PhysicalLeftClick(cx, cy);
                }

                Thread.Sleep(2000);

                // 2. Perform Single Left-Click on TreeItem 'localhost'
                var itemCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TreeItem);
                var allItems = appWin.FindAll(TreeScope.Descendants, itemCond);
                log += "Found " + allItems.Count + " TreeItem(s) on Connections tab\n";

                if (allItems.Count > 0) {
                    AutomationElement item = allItems[0];
                    Rect ir = item.Current.BoundingRectangle;
                    int cx = (int)(ir.X + ir.Width / 3);
                    int cy = (int)(ir.Y + ir.Height / 2);
                    log += "TEST 1: Single-clicking TreeItem at (" + cx + ", " + cy + ") — should only select, NOT open tab...\n";
                    PhysicalLeftClick(cx, cy);
                    Thread.Sleep(2000);
                }

                // Capture shotSingleClick: verify selected, but STILL on Connections tab (no tab opened)
                CaptureScreenshot(hwnd, shotSingleClick);
                log += "Saved shot 1 (Single click: selected, no auto-open) to " + shotSingleClick + "\n";

                // 3. Perform Double-Click on TreeItem 'localhost' to open session
                if (allItems.Count > 0) {
                    AutomationElement item = allItems[0];
                    Rect ir = item.Current.BoundingRectangle;
                    int cx = (int)(ir.X + ir.Width / 3);
                    int cy = (int)(ir.Y + ir.Height / 2);
                    log += "TEST 2: Double-clicking TreeItem at (" + cx + ", " + cy + ") — now opens database session...\n";
                    PhysicalDoubleClick(cx, cy);
                    Thread.Sleep(3000);
                }

                // 4. In Database tab, Single-click on a database schema node
                var allItems2 = appWin.FindAll(TreeScope.Descendants, itemCond);
                log += "Found " + allItems2.Count + " TreeItem(s) on Database schema tree\n";

                if (allItems2.Count > 1) {
                    AutomationElement dbItem = allItems2[1];
                    Rect ir = dbItem.Current.BoundingRectangle;
                    int cx = (int)(ir.X + ir.Width / 2);
                    int cy = (int)(ir.Y + ir.Height / 2);
                    log += "TEST 3: Single-clicking database schema node '" + dbItem.Current.Name + "' at (" + cx + ", " + cy + ") — should only select, NOT expand...\n";
                    PhysicalLeftClick(cx, cy);
                    Thread.Sleep(1500);
                }

                // Capture shotDoubleTap: database tab opened via double-click, and schema node selected without auto-expanding
                CaptureScreenshot(hwnd, shotDoubleTap);
                log += "Saved shot 2 (Double click: opened session; schema node: selected without expanding) to " + shotDoubleTap + "\n";

            } catch (Exception ex) {
                log += "EXCEPTION: " + ex.ToString() + "\n";
            } finally {
                CloseDesktop(hDesk);
            }
        });

        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join();
        return log;
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies WindowsBase, UIAutomationClient, UIAutomationTypes, System.Drawing

Get-Process DataSphere -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 600

$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"

$shotSingleClick = "D:\DEV\C#DOTNET\DataSphere\.specify\bugs\treeview-single-click-auto-invoke\03_fixed_single_click_select_only.png"
$shotDoubleTap = "D:\DEV\C#DOTNET\DataSphere\.specify\bugs\treeview-single-click-auto-invoke\04_fixed_double_click_open_and_tree_select.png"

$appPid = [TreeViewFixVerifier]::LaunchApp($exePath, $workingDir)
Write-Host "Launched DataSphere PID=$appPid"

$log = [TreeViewFixVerifier]::ExecuteVerification($appPid, $shotSingleClick, $shotDoubleTap)
Write-Host $log

Get-Process -Id $appPid -ErrorAction SilentlyContinue | Stop-Process -Force
