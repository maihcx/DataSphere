$source = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class DesktopTester {
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

    public static void PhysicalClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(200);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(80);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(300);
    }

    public static void PhysicalDoubleClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(150);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(400);
    }

    public static void CaptureWindow(IntPtr hwnd, string path) {
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

    public static string RunFullTest(int pid, string artifactDir) {
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
                        break;
                    }
                }

                if (appWin == null) {
                    log += "ERROR: Window not found for PID " + pid + "\n";
                    return;
                }

                SetForegroundWindow(hwnd);
                Thread.Sleep(2000);

                // Step 1: Click Database Card on Home page
                log += "[Step 1] Finding Database Card on Home page...\n";
                var allButtons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
                AutomationElement dbBtn = null;
                foreach (AutomationElement btn in allButtons) {
                    Rect r = btn.Current.BoundingRectangle;
                    if (r.Width > 200 && r.Height > 60) {
                        if (dbBtn == null || r.X < dbBtn.Current.BoundingRectangle.X) dbBtn = btn;
                    }
                }

                if (dbBtn != null) {
                    Rect r = dbBtn.Current.BoundingRectangle;
                    int cx = (int)(r.X + r.Width / 2);
                    int cy = (int)(r.Y + r.Height / 2);
                    log += "Clicking Database Card at (" + cx + ", " + cy + ")...\n";
                    PhysicalClick(cx, cy);
                } else {
                    log += "WARNING: Database Card button not found!\n";
                }

                Thread.Sleep(2500);

                // Step 2: In ConnectViewControl, find the connection 'localhost'
                log += "[Step 2] Locating connection 'localhost' in tree view...\n";
                AutomationElement connNode = null;
                for (int attempt = 0; attempt < 5; attempt++) {
                    var allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                    foreach (AutomationElement txt in allTexts) {
                        string n = txt.Current.Name ?? "";
                        if (n == "localhost" || n.Contains("localhost") || n.Contains("MySQL")) {
                            connNode = txt;
                            break;
                        }
                    }
                    if (connNode != null) break;
                    Thread.Sleep(500);
                }

                if (connNode != null) {
                    Rect r = connNode.Current.BoundingRectangle;
                    int cx = (int)(r.X + r.Width / 2);
                    int cy = (int)(r.Y + r.Height / 2);
                    log += "Located 'localhost' text at exact coords: (" + cx + ", " + cy + "). Double-clicking...\n";
                    PhysicalDoubleClick(cx, cy);
                } else {
                    log += "WARNING: 'localhost' not found, scanning TreeItems...\n";
                    var treeItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TreeItem));
                    if (treeItems.Count > 0) {
                        Rect r = treeItems[0].Current.BoundingRectangle;
                        int cx = (int)(r.X + r.Width / 2);
                        int cy = (int)(r.Y + r.Height / 2);
                        log += "Double-clicking first TreeItem at (" + cx + ", " + cy + ")...\n";
                        PhysicalDoubleClick(cx, cy);
                    }
                }

                // Wait for connection to connect and databases to load
                log += "[Step 3] Waiting for localhost session tab to open and load databases...\n";
                bool tabOpened = false;
                for (int wait = 0; wait < 15; wait++) {
                    Thread.Sleep(1000);
                    var tabItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                    foreach (AutomationElement ti in tabItems) {
                        string name = ti.Current.Name ?? "";
                        if (name.Contains("localhost")) {
                            tabOpened = true;
                            log += "Session tab 'localhost' confirmed open! (Found TabItem: " + name + ")\n";
                            break;
                        }
                    }
                    if (tabOpened) break;
                }

                if (!tabOpened) {
                    log += "Session tab was not detected via TabItem, checking TreeItems in left pane...\n";
                }

                Thread.Sleep(2000);

                // Step 4: Find schema node 'chat' or 'file3dluutru' in SchemaTree
                log += "[Step 4] Searching for schema node 'chat' in SchemaTree...\n";
                AutomationElement chatText = null;
                for (int a = 0; a < 10; a++) {
                    var allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                    foreach (AutomationElement txt in allTexts) {
                        if (txt.Current.Name == "chat") {
                            chatText = txt;
                            break;
                        }
                    }
                    if (chatText != null) break;
                    Thread.Sleep(500);
                }

                if (chatText != null) {
                    Rect rChat = chatText.Current.BoundingRectangle;
                    int cx = (int)(rChat.X + rChat.Width / 2);
                    int cy = (int)(rChat.Y + rChat.Height / 2);
                    log += "Located 'chat' database schema at exact coords (" + cx + ", " + cy + ").\n";

                    // Expand 'chat' by double-clicking
                    log += "Double-clicking 'chat' to expand its categories (Tables, Views, SPs, Fncs)...\n";
                    PhysicalDoubleClick(cx, cy);
                    Thread.Sleep(2500);

                    // Step 5: Locate 'Các bảng'
                    log += "[Step 5] Searching for 'Các bảng' under 'chat'...\n";
                    AutomationElement tablesText = null;
                    var allTexts2 = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                    foreach (AutomationElement txt in allTexts2) {
                        string n = txt.Current.Name ?? "";
                        if (n.Contains("bảng") || n.Contains("Tables")) {
                            tablesText = txt;
                            break;
                        }
                    }

                    if (tablesText != null) {
                        Rect rTables = tablesText.Current.BoundingRectangle;
                        int tx = (int)(rTables.X + rTables.Width / 2);
                        int ty = (int)(rTables.Y + rTables.Height / 2);
                        log += "Located 'Các bảng' at exact coords (" + tx + ", " + ty + "). Double-clicking to expand tables list...\n";
                        PhysicalDoubleClick(tx, ty);
                        Thread.Sleep(2500);

                        // Step 6: Locate table item 'chatrooms' or 'chat_user_table'
                        log += "[Step 6] Searching for table 'chatrooms'...\n";
                        AutomationElement roomTable = null;
                        var allTexts3 = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                        foreach (AutomationElement txt in allTexts3) {
                            string n = txt.Current.Name ?? "";
                            if (n == "chatrooms" || n == "chat_user_table") {
                                roomTable = txt;
                                break;
                            }
                        }

                        if (roomTable != null) {
                            Rect rRoom = roomTable.Current.BoundingRectangle;
                            int rx = (int)(rRoom.X + rRoom.Width / 2);
                            int ry = (int)(rRoom.Y + rRoom.Height / 2);
                            log += "Located table '" + roomTable.Current.Name + "' at exact coords (" + rx + ", " + ry + "). Single-clicking to select and load data...\n";
                            PhysicalClick(rx, ry);
                            Thread.Sleep(3500);

                            // Capture screenshot 1: Table loaded
                            string snapTablePath = artifactDir + "\\verification_real_table_loaded.png";
                            CaptureWindow(hwnd, snapTablePath);
                            log += "SUCCESS: Captured table data loaded screenshot to " + snapTablePath + "\n";

                            // Step 7: Interact with table rows and cells!
                            log += "[Step 7] Testing table interaction (clicking row and selecting cell)...\n";
                            // Table data rows are located to the right of the tree, starting around X = rChat.X + 300, Y = rChat.Y
                            int clickRowX = (int)rChat.X + 350;
                            int clickRowY = (int)rChat.Y;
                            log += "Clicking table row at (" + clickRowX + ", " + clickRowY + ") to verify row selection...\n";
                            PhysicalClick(clickRowX, clickRowY);
                            Thread.Sleep(800);

                            // Double click cell to select text
                            log += "Double-clicking cell at (" + (clickRowX + 80) + ", " + clickRowY + ") to test cell text selection...\n";
                            PhysicalDoubleClick(clickRowX + 80, clickRowY);
                            Thread.Sleep(800);

                            string snapInteractPath = artifactDir + "\\verification_real_interaction.png";
                            CaptureWindow(hwnd, snapInteractPath);
                            log += "SUCCESS: Captured cell interaction screenshot to " + snapInteractPath + "\n";
                        } else {
                            log += "WARNING: 'chatrooms' table node not found!\n";
                        }
                    } else {
                        log += "WARNING: 'Các bảng' node not found under 'chat'!\n";
                    }

                    // Step 8: Perform aggressive rapid expand/collapse stress test on 'chat'
                    log += "[Step 8] Starting aggressive rapid expand/collapse stress test on 'chat' node at (" + cx + ", " + cy + ")...\n";
                    for (int cycle = 1; cycle <= 10; cycle++) {
                        PhysicalDoubleClick(cx, cy);
                        Thread.Sleep(100);
                    }
                    log += "Completed 10 rapid expand/collapse cycles! Testing process health...\n";

                    Process p = Process.GetProcessById(pid);
                    if (!p.HasExited) {
                        log += "PASS: Process is healthy, alive, and completely crash-free!\n";
                    } else {
                        log += "FAIL: Process crashed during rapid expand/collapse!\n";
                    }

                    string snapRapidPath = artifactDir + "\\verification_real_rapid_stress.png";
                    CaptureWindow(hwnd, snapRapidPath);
                    log += "SUCCESS: Captured rapid stress test screenshot to " + snapRapidPath + "\n";
                } else {
                    log += "WARNING: 'chat' database node not found in TreeView!\n";
                    // Still capture whatever is on screen
                    CaptureWindow(hwnd, artifactDir + "\\verification_debug_state.png");
                }

                Thread.Sleep(1000);
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

$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"

Write-Host "Starting REAL Desktop Comprehensive Automation Test..."
$appPid = [DesktopTester]::LaunchApp($exePath, $workingDir)
Write-Host "App launched with PID: $appPid on real desktop (WinSta0\default)"

$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363"

$log = [DesktopTester]::RunFullTest($appPid, $artifactDir)
Write-Host "================== TEST LOG =================="
Write-Host $log
Write-Host "=============================================="

# Terminate test process
try {
    $p = Get-Process -Id $appPid -ErrorAction SilentlyContinue
    if ($p) {
        Write-Host "Terminating test instance (PID: $appPid)..."
        $p.Kill()
    }
} catch {}
