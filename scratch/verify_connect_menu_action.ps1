$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class ConnectMenuActionVerifier {
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
    public const uint MOUSEEVENTF_RIGHTDOWN = 0x0008;
    public const uint MOUSEEVENTF_RIGHTUP = 0x0010;

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

    public static void PhysicalRightClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(300);
        mouse_event(MOUSEEVENTF_RIGHTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_RIGHTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(600);
    }

    public static string ExecuteVerification(int pid, string screenshotPath) {
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
                        log += "Found DataSphere window on real desktop (HWND=" + hwnd + ")\n";
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
                } else {
                    log += "WARNING: Could not find Database Card button!\n";
                }

                Thread.Sleep(2000);

                // 2. Locate TreeViewItem 'localhost'
                var itemCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TreeItem);
                var allItems = appWin.FindAll(TreeScope.Descendants, itemCond);
                log += "Found " + allItems.Count + " TreeItem(s)\n";

                if (allItems.Count > 0) {
                    AutomationElement item = allItems[0];
                    Rect ir = item.Current.BoundingRectangle;
                    int cx = (int)(ir.X + ir.Width / 3);
                    int cy = (int)(ir.Y + ir.Height / 2);
                    log += "Right-clicking TreeItem at (" + cx + ", " + cy + ") to open MenuFlyout...\n";
                    PhysicalRightClick(cx, cy);
                    Thread.Sleep(1200);

                    // 3. Find MenuFlyoutItem 'Chỉnh sửa kết nối' (or second menu item)
                    // Menu items are hosted in the desktop root / popups
                    var menuCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.MenuItem);
                    var allMenuItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, menuCond);
                    log += "Found " + allMenuItems.Count + " MenuItem(s) on desktop\n";

                    AutomationElement editMenuItem = null;
                    foreach (AutomationElement mi in allMenuItems) {
                        log += "  MenuItem: '" + mi.Current.Name + "'\n";
                        if (mi.Current.Name.Contains("Chỉnh sửa") || mi.Current.Name.Contains("Edit")) {
                            editMenuItem = mi;
                            break;
                        }
                    }

                    if (editMenuItem == null && allMenuItems.Count >= 2) {
                        // Click the second menu item (Edit)
                        editMenuItem = allMenuItems[1];
                    }

                    if (editMenuItem != null) {
                        Rect mr = editMenuItem.Current.BoundingRectangle;
                        int mcx = (int)(mr.X + mr.Width / 2);
                        int mcy = (int)(mr.Y + mr.Height / 2);
                        log += "Clicking MenuItem '" + editMenuItem.Current.Name + "' at (" + mcx + ", " + mcy + ")...\n";
                        PhysicalLeftClick(mcx, mcy);
                        Thread.Sleep(2500);
                    } else {
                        log += "WARNING: Edit MenuItem not found!\n";
                    }
                }

                // 4. Capture screenshot showing ConnectionEditingDialog opened via command
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
                        bmp.Save(screenshotPath, ImageFormat.Png);
                    }
                    log += "SUCCESS: Captured real desktop screenshot to " + screenshotPath + " (" + w + "x" + h + ")\n";
                }

                Thread.Sleep(1500);
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
$diagImgPath = "D:\DEV\C#DOTNET\DataSphere\.specify\bugs\connect-view-code-behind-violation\03_verified_edit_dialog.png"

$appPid = [ConnectMenuActionVerifier]::LaunchApp($exePath, $workingDir)
Write-Host "Launched DataSphere PID=$appPid"

$log = [ConnectMenuActionVerifier]::ExecuteVerification($appPid, $diagImgPath)
Write-Host $log

Get-Process -Id $appPid -ErrorAction SilentlyContinue | Stop-Process -Force
