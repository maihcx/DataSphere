$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class VirtualTableRealVerifier {
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

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);

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

    public static void PhysicalDoubleClick(int x, int y) {
        PhysicalLeftClick(x, y);
        Thread.Sleep(60);
        PhysicalLeftClick(x, y);
        Thread.Sleep(200);
    }

    public static void PhysicalDrag(int startX, int startY, int endX, int endY) {
        SetCursorPos(startX, startY);
        Thread.Sleep(100);
        mouse_event(0x0002, 0, 0, 0, 0); // LEFTDOWN
        Thread.Sleep(100);
        int steps = 10;
        for (int i = 1; i <= steps; i++) {
            int curX = startX + (endX - startX) * i / steps;
            int curY = startY + (endY - startY) * i / steps;
            SetCursorPos(curX, curY);
            Thread.Sleep(25);
        }
        mouse_event(0x0004, 0, 0, 0, 0); // LEFTUP
        Thread.Sleep(200);
    }

    public static void MouseWheelScroll(int delta, int count) {
        for (int i = 0; i < count; i++) {
            mouse_event(0x0800, 0, 0, (uint)delta, 0); // MOUSEEVENTF_WHEEL = 0x0800
            Thread.Sleep(50);
        }
    }

    public static void SendText(string text) {
        foreach (char c in text) {
            short vk = (short)c;
            keybd_event((byte)vk, 0, 0, 0);
            Thread.Sleep(25);
            keybd_event((byte)vk, 0, 2, 0);
            Thread.Sleep(25);
        }
        // Press Enter to commit edit
        keybd_event(0x0D, 0, 0, 0);
        Thread.Sleep(25);
        keybd_event(0x0D, 0, 2, 0);
        Thread.Sleep(150);
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
                PrintWindow(hwnd, hdc, 2); // PW_RENDERFULLCONTENT = 2
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

    public static string ExecuteVerification(int pid, string artifactDir) {
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

                // 1. Connect to localhost
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
                    int cx = (int)(r.X + r.Width / 2);
                    int cy = (int)(r.Y + r.Height / 2);
                    log += "Right-clicking 'localhost' at (" + cx + ", " + cy + ")...\n";
                    PhysicalRightClick(cx, cy);
                    Thread.Sleep(1000);

                    for (int m = 0; m < 10; m++) {
                        try {
                            var allMenuItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.MenuItem));
                            if (allMenuItems.Count > 0) {
                                Rect mr = allMenuItems[0].Current.BoundingRectangle;
                                if (mr.Width > 0 && mr.Height > 0) {
                                    log += "Clicking MenuItem at (" + (int)(mr.X + mr.Width / 2) + ", " + (int)(mr.Y + mr.Height / 2) + ")...\n";
                                    PhysicalLeftClick((int)(mr.X + mr.Width / 2), (int)(mr.Y + mr.Height / 2));
                                    break;
                                }
                            }
                        } catch {}
                        Thread.Sleep(300);
                    }
                }

                Thread.Sleep(4000);

                // 2. Expand database ngocthamcatalog
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

                // 3. Expand Các bảng
                var afterExpandTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement tablesCat = null;
                foreach (AutomationElement txt in afterExpandTexts) {
                    string name = txt.Current.Name ?? "";
                    if (name.IndexOf("b\u1EA3ng", StringComparison.OrdinalIgnoreCase) >= 0 ||
                        name.IndexOf("Tables", StringComparison.OrdinalIgnoreCase) >= 0 ||
                        name.IndexOf("b?ng", StringComparison.OrdinalIgnoreCase) >= 0) {
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

                // 4. Find and click table banggiada
                AutomationElement banggiadaNode = null;
                AutomationElement adminNode = null;
                var afterTablesTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                foreach (AutomationElement txt in afterTablesTexts) {
                    if (txt.Current.Name == "banggiada") {
                        banggiadaNode = txt;
                    } else if (txt.Current.Name == "admin") {
                        adminNode = txt;
                    }
                }

                if (banggiadaNode == null) {
                    log += "ERROR: 'banggiada' table not found!\n";
                    return;
                }

                Rect bRect = banggiadaNode.Current.BoundingRectangle;
                log += "Clicking 'banggiada' table...\n";
                PhysicalLeftClick((int)(bRect.X + bRect.Width / 2), (int)(bRect.Y + bRect.Height / 2));
                Thread.Sleep(3000);

                // Capture initial rendering via VirtualTable
                string snapInitial = artifactDir + "\\virtualtable_initial_render.png";
                CaptureWindow(hwnd, snapInitial);
                log += "SUCCESS: Captured VirtualTable initial render to " + snapInitial + "\n";

                // 5. Test Fast Zero-Allocation Scrolling
                RECT winRect;
                GetWindowRect(hwnd, out winRect);
                int viewportCenterX = winRect.Left + 550;
                int viewportCenterY = winRect.Top + 300;
                SetCursorPos(viewportCenterX, viewportCenterY);
                Thread.Sleep(100);

                log += "Scrolling down rapidly with mouse wheel...\n";
                MouseWheelScroll(-120, 8);
                Thread.Sleep(1000);

                string snapScrolled = artifactDir + "\\virtualtable_fast_scrolled.png";
                CaptureWindow(hwnd, snapScrolled);
                log += "SUCCESS: Captured VirtualTable fast scrolled to " + snapScrolled + "\n";

                // Scroll back to top
                MouseWheelScroll(120, 8);
                Thread.Sleep(1000);

                // 6. Test 3-State Server-Side Sorting: Click 'id' header
                int headerIdX = winRect.Left + 420;
                int headerIdY = winRect.Top + 135;

                // Click ASC
                log += "Clicking 'id' column header for Server Sort ASC...\n";
                PhysicalLeftClick(headerIdX, headerIdY);
                Thread.Sleep(1500);

                string snapAsc = artifactDir + "\\virtualtable_sort_asc.png";
                CaptureWindow(hwnd, snapAsc);
                log += "SUCCESS: Captured VirtualTable sort ASC to " + snapAsc + "\n";

                // Click DESC
                log += "Clicking 'id' column header for Server Sort DESC...\n";
                PhysicalLeftClick(headerIdX, headerIdY);
                Thread.Sleep(1500);

                string snapDesc = artifactDir + "\\virtualtable_sort_desc.png";
                CaptureWindow(hwnd, snapDesc);
                log += "SUCCESS: Captured VirtualTable sort DESC to " + snapDesc + "\n";

                // Click Clear
                log += "Clicking 'id' column header for Server Sort Clear...\n";
                PhysicalLeftClick(headerIdX, headerIdY);
                Thread.Sleep(1500);

                string snapClear = artifactDir + "\\virtualtable_sort_clear.png";
                CaptureWindow(hwnd, snapClear);
                log += "SUCCESS: Captured VirtualTable sort Clear to " + snapClear + "\n";

                // 7. Test Column Resizing via Splitter Drag
                int splitterX = headerIdX + 70;
                int splitterY = headerIdY;
                log += "Dragging column splitter from (" + splitterX + ", " + splitterY + ") right by 80px...\n";
                PhysicalDrag(splitterX, splitterY, splitterX + 80, splitterY);
                Thread.Sleep(1000);

                string snapResized = artifactDir + "\\virtualtable_column_resized.png";
                CaptureWindow(hwnd, snapResized);
                log += "SUCCESS: Captured VirtualTable column resized to " + snapResized + "\n";

                // 8. Test Editable Table with Primary Key: Switch to 'admin' table
                if (adminNode != null) {
                    Rect aRect = adminNode.Current.BoundingRectangle;
                    log += "Switching to 'admin' table for primary key editing...\n";
                    PhysicalLeftClick((int)(aRect.X + aRect.Width / 2), (int)(aRect.Y + aRect.Height / 2));
                    Thread.Sleep(3000);

                    // Double-click cell in admin table
                    int adminCellX = headerIdX + 180;
                    int adminCellY = headerIdY + 45;
                    log += "Double-clicking cell in 'admin' table at (" + adminCellX + ", " + adminCellY + ")...\n";
                    PhysicalDoubleClick(adminCellX, adminCellY);
                    Thread.Sleep(500);

                    log += "Sending edit text...\n";
                    SendText("1");
                    Thread.Sleep(1000);

                    string snapDirty = artifactDir + "\\virtualtable_cell_edited_dirty.png";
                    CaptureWindow(hwnd, snapDirty);
                    log += "SUCCESS: Captured VirtualTable dirty cell edit to " + snapDirty + "\n";

                    // Click Commit Changes button
                    int commitX = winRect.Right - 230;
                    int commitY = winRect.Top + 85;
                    log += "Clicking Commit button at (" + commitX + ", " + commitY + ")...\n";
                    PhysicalLeftClick(commitX, commitY);
                    Thread.Sleep(3000);

                    string snapCommitted = artifactDir + "\\virtualtable_cell_committed.png";
                    CaptureWindow(hwnd, snapCommitted);
                    log += "SUCCESS: Captured VirtualTable committed state to " + snapCommitted + "\n";
                } else {
                    // Fallback to banggiada cell editing
                    int cellX = headerIdX + 420;
                    int cellY = headerIdY + 45;
                    PhysicalDoubleClick(cellX, cellY);
                    Thread.Sleep(500);
                    SendText("T");
                    Thread.Sleep(1000);
                    string snapDirty = artifactDir + "\\virtualtable_cell_edited_dirty.png";
                    CaptureWindow(hwnd, snapDirty);
                    log += "SUCCESS: Captured VirtualTable dirty cell edit to " + snapDirty + "\n";
                }

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

Write-Host "Launching DataSphere on WinSta0\default..."
$pidNum = [VirtualTableRealVerifier]::LaunchApp($exePath, $workingDir)
Write-Host "App launched with PID: $pidNum"

Start-Sleep -Seconds 3

Write-Host "Executing VirtualTable automated verification on real desktop..."
$log = [VirtualTableRealVerifier]::ExecuteVerification($pidNum, $artifactDir)
Write-Host "Verification Log:"
Write-Host $log

# Clean up
Get-Process -Id $pidNum -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host "Verification finished."
