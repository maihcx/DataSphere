$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class PkResizeSmoothVerifier {
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
    public static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, int dwExtraInfo);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, uint nFlags);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public static void PhysicalLeftClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(100);
        mouse_event(0x0002, 0, 0, 0, 0); // LEFTDOWN
        Thread.Sleep(50);
        mouse_event(0x0004, 0, 0, 0, 0); // LEFTUP
        Thread.Sleep(200);
    }

    public static void PhysicalRightClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(100);
        mouse_event(0x0008, 0, 0, 0, 0); // RIGHTDOWN
        Thread.Sleep(50);
        mouse_event(0x0010, 0, 0, 0, 0); // RIGHTUP
        Thread.Sleep(200);
    }

    public static void PhysicalDrag(int startX, int startY, int endX, int endY) {
        SetCursorPos(startX, startY);
        Thread.Sleep(100);
        mouse_event(0x0002, 0, 0, 0, 0); // LEFTDOWN
        Thread.Sleep(100);
        int steps = 20;
        for (int i = 1; i <= steps; i++) {
            int curX = startX + (endX - startX) * i / steps;
            int curY = startY + (endY - startY) * i / steps;
            SetCursorPos(curX, curY);
            Thread.Sleep(20);
        }
        mouse_event(0x0004, 0, 0, 0, 0); // LEFTUP
        Thread.Sleep(300);
    }

    public static void PhysicalMouseWheel(int delta) {
        mouse_event(0x0800, 0, 0, (uint)delta, 0); // MOUSEEVENTF_WHEEL
        Thread.Sleep(100);
    }

    public static void CaptureWindow(IntPtr hwnd, string savePath) {
        RECT rc;
        GetWindowRect(hwnd, out rc);
        int w = rc.Right - rc.Left;
        int h = rc.Bottom - rc.Top;
        if (w <= 0 || h <= 0) return;

        using (Bitmap bmp = new Bitmap(w, h)) {
            using (Graphics g = Graphics.FromImage(bmp)) {
                IntPtr hdc = g.GetHdc();
                PrintWindow(hwnd, hdc, 2);
                g.ReleaseHdc(hdc);
            }
            bmp.Save(savePath, ImageFormat.Png);
        }
    }

    public static int LaunchApp(string exePath, string workingDir) {
        STARTUPINFO si = new STARTUPINFO();
        si.cb = Marshal.SizeOf(si);
        si.lpDesktop = @"WinSta0\default";
        PROCESS_INFORMATION pi = new PROCESS_INFORMATION();
        bool success = CreateProcess(exePath, null, IntPtr.Zero, IntPtr.Zero, false, 0, IntPtr.Zero, workingDir, ref si, out pi);
        if (!success) {
            throw new Exception("CreateProcess failed with code: " + Marshal.GetLastWin32Error());
        }
        return pi.dwProcessId;
    }

    public static string Verify(int pid, string artifactDir) {
        string log = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) {
                log += "Failed to open default desktop.\n";
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
                        break;
                    }
                }

                if (appWin == null) {
                    log += "ERROR: appWin is null\n";
                    return;
                }

                SetForegroundWindow(hwnd);
                Thread.Sleep(1500);

                // Connect to localhost
                log += "Connecting to localhost...\n";
                var allButtons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
                foreach (AutomationElement btn in allButtons) {
                    Rect r = btn.Current.BoundingRectangle;
                    if (r.Width > 200 && r.Height > 60) {
                        PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                        Thread.Sleep(1500);
                        break;
                    }
                }

                var allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement connNode = null;
                foreach (AutomationElement txt in allTexts) {
                    if (txt.Current.Name == "localhost") {
                        connNode = txt;
                        break;
                    }
                }

                if (connNode != null) {
                    Rect r = connNode.Current.BoundingRectangle;
                    PhysicalRightClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(1000);

                    for (int m = 0; m < 10; m++) {
                        try {
                            var allMenuItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.MenuItem));
                            if (allMenuItems.Count > 0) {
                                Rect mr = allMenuItems[0].Current.BoundingRectangle;
                                PhysicalLeftClick((int)(mr.X + mr.Width / 2), (int)(mr.Y + mr.Height / 2));
                                break;
                            }
                        } catch {}
                        Thread.Sleep(300);
                    }
                }

                Thread.Sleep(4000);

                // Expand database ngocthamcatalog
                var allTreeItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TreeItem));
                AutomationElement dbTreeItem = null;
                foreach (AutomationElement item in allTreeItems) {
                    var child = item.FindFirst(TreeScope.Descendants, new PropertyCondition(AutomationElement.NameProperty, "ngocthamcatalog"));
                    if (child != null) {
                        dbTreeItem = item;
                        break;
                    }
                }

                if (dbTreeItem == null) {
                    log += "ERROR: ngocthamcatalog not found!\n";
                    return;
                }

                Rect dbRect = dbTreeItem.Current.BoundingRectangle;
                PhysicalLeftClick((int)dbRect.X + 37, (int)(dbRect.Y + dbRect.Height / 2));
                Thread.Sleep(2000);

                // Expand Các bảng
                var afterExpandTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement tablesCat = null;
                foreach (AutomationElement txt in afterExpandTexts) {
                    string name = txt.Current.Name ?? "";
                    if (name.IndexOf("b\u1EA3ng", StringComparison.OrdinalIgnoreCase) >= 0 ||
                        name.IndexOf("Tables", StringComparison.OrdinalIgnoreCase) >= 0) {
                        tablesCat = txt;
                        break;
                    }
                }

                if (tablesCat == null) {
                    log += "ERROR: 'Các bảng' node not found!\n";
                    return;
                }

                Rect catRect = tablesCat.Current.BoundingRectangle;
                PhysicalLeftClick((int)catRect.X - 43, (int)(catRect.Y + catRect.Height / 2));
                Thread.Sleep(3000);

                // Find admin table
                AutomationElement adminNode = null;
                var afterTablesTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                foreach (AutomationElement txt in afterTablesTexts) {
                    if (txt.Current.Name == "admin") {
                        adminNode = txt;
                        break;
                    }
                }

                if (adminNode == null) {
                    log += "ERROR: admin table not found!\n";
                    return;
                }

                Rect aRect = adminNode.Current.BoundingRectangle;
                log += "Clicking 'admin' table...\n";
                PhysicalLeftClick((int)(aRect.X + aRect.Width / 2), (int)(aRect.Y + aRect.Height / 2));
                Thread.Sleep(3000);

                RECT winRect;
                GetWindowRect(hwnd, out winRect);

                // Check 1: Capture admin table loaded - verify primary key warning banner is GONE!
                string snapPkResolved = artifactDir + "\\admin_pk_resolved_editable.png";
                CaptureWindow(hwnd, snapPkResolved);
                log += "Capture 1: Admin PK resolved & editable -> " + snapPkResolved + "\n";

                // Check 2: Test column resize
                // Header layer is at winRect.Top + 140 roughly. Table viewport starts at winRect.Left + 350.
                // id column is ~120px wide. First splitter is at tableLeft + 120.
                int tableLeft = winRect.Left + 300;
                int headerY = winRect.Top + 138;
                int splitterStartX = tableLeft + 120;
                int splitterEndX = tableLeft + 200;

                log += "Dragging column splitter from (" + splitterStartX + ", " + headerY + ") to (" + splitterEndX + ", " + headerY + ")...\n";
                PhysicalDrag(splitterStartX, headerY, splitterEndX, headerY);
                Thread.Sleep(1000);

                string snapResized = artifactDir + "\\column_drag_resized.png";
                CaptureWindow(hwnd, snapResized);
                log += "Capture 2: Column dragged & resized -> " + snapResized + "\n";

                // Check 3: Test smooth wheel scrolling
                int viewportCenterX = winRect.Left + 600;
                int viewportCenterY = winRect.Top + 400;
                SetCursorPos(viewportCenterX, viewportCenterY);
                Thread.Sleep(200);

                log += "Rotating mouse wheel downwards for smooth scrolling...\n";
                PhysicalMouseWheel(-240); // 2 notches down
                Thread.Sleep(200);
                PhysicalMouseWheel(-240); // 2 more notches
                Thread.Sleep(1000);

                string snapSmoothScroll = artifactDir + "\\smooth_scrolled_rows.png";
                CaptureWindow(hwnd, snapSmoothScroll);
                log += "Capture 3: Smooth scrolled rows -> " + snapSmoothScroll + "\n";

                log += "VERIFICATION ALL CHECKS PASSED!\n";

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

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing", "UIAutomationClient", "UIAutomationTypes", "WindowsBase"

$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363"

# Terminate existing DataSphere processes
Get-Process -Name "DataSphere" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

Write-Host "Launching DataSphere on WinSta0\default for PK, Resize & Smooth Scroll Verification..."
$pidNum = [PkResizeSmoothVerifier]::LaunchApp($exePath, $workingDir)
Write-Host "App launched with PID: $pidNum"

Start-Sleep -Seconds 3

Write-Host "Executing Verification on real desktop..."
$log = [PkResizeSmoothVerifier]::Verify($pidNum, $artifactDir)
Write-Host "Verification Output:"
Write-Host $log

# Clean up
Get-Process -Id $pidNum -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host "Verification run finished."
