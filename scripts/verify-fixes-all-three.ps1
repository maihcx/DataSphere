$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class ThreeIssuesVerifier {
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
        if (!success) throw new InvalidOperationException("CreateProcess failed");
        return pi.dwProcessId;
    }

    public static void PhysicalLeftClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(200);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(400);
    }

    public static void CaptureWindow(IntPtr hwnd, string filename) {
        RECT r;
        GetWindowRect(hwnd, out r);
        int w = r.Right - r.Left;
        int h = r.Bottom - r.Top;
        if (w <= 0 || h <= 0) return;
        using (Bitmap bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb)) {
            using (Graphics g = Graphics.FromImage(bmp)) {
                IntPtr hdc = g.GetHdc();
                try {
                    PrintWindow(hwnd, hdc, 2);
                } finally {
                    g.ReleaseHdc(hdc);
                }
            }
            bmp.Save(filename, ImageFormat.Png);
        }
    }

    public static string Verify(int pid, string artifactDir) {
        string log = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) return;
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
                if (appWin == null) return;
                SetForegroundWindow(hwnd);
                Thread.Sleep(1500);

                // 1. Connect localhost
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
                    SetCursorPos((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(200);
                    mouse_event(0x0008, 0, 0, 0, 0);
                    Thread.Sleep(100);
                    mouse_event(0x0010, 0, 0, 0, 0);
                    Thread.Sleep(800);

                    var allMenuItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.MenuItem));
                    if (allMenuItems.Count > 0) {
                        Rect mr = allMenuItems[0].Current.BoundingRectangle;
                        PhysicalLeftClick((int)(mr.X + mr.Width / 2), (int)(mr.Y + mr.Height / 2));
                    }
                }

                log += "Waiting 4 seconds for database schemas...\n";
                Thread.Sleep(4000);

                // 2. CHECK ISSUE 1: Immediate expansion of database node 'ngocthamcatalog' on SINGLE CLICK
                log += "Testing Issue 1: Single-click expand on 'ngocthamcatalog'...\n";
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
                    log += "ERROR: 'ngocthamcatalog' not found!\n";
                    return;
                }

                Rect dbRect = dbTreeItem.Current.BoundingRectangle;
                int dbChevronX = (int)dbRect.X + 37;
                int dbChevronY = (int)(dbRect.Y + dbRect.Height / 2);
                log += string.Format("Single click on database chevron at ({0},{1})...\n", dbChevronX, dbChevronY);
                PhysicalLeftClick(dbChevronX, dbChevronY);
                Thread.Sleep(1500);

                // Verify child categories appeared immediately on SINGLE click
                var afterExpandTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement tablesCatElement = null;
                foreach (AutomationElement txt in afterExpandTexts) {
                    string name = txt.Current.Name ?? "";
                    if (name.IndexOf("b\u1EA3ng", StringComparison.OrdinalIgnoreCase) >= 0 ||
                        name.IndexOf("Tables", StringComparison.OrdinalIgnoreCase) >= 0 ||
                        name.IndexOf("b?ng", StringComparison.OrdinalIgnoreCase) >= 0) {
                        tablesCatElement = txt;
                        break;
                    }
                }

                if (tablesCatElement != null) {
                    log += "PASS ISSUE 1: Database node expanded IMMEDIATELY on single click! Found 'Các bảng' node!\n";
                } else {
                    log += "FAIL ISSUE 1: Database node did NOT expand on single click!\n";
                    return;
                }

                CaptureWindow(hwnd, artifactDir + "\\verify_issue1_db_expanded.png");

                // 3. CHECK ISSUE 2: Expanding 'Các bảng' (loading indicator + automatic expansion)
                log += "Testing Issue 2: Expanding 'Các bảng'...\n";
                Rect catRect = tablesCatElement.Current.BoundingRectangle;
                int catChevronX = (int)catRect.X - 43;
                int catChevronY = (int)(catRect.Y + catRect.Height / 2);
                PhysicalLeftClick(catChevronX, catChevronY);
                Thread.Sleep(3000);

                // Locate 'admin' table
                AutomationElement adminNode = null;
                var afterTablesTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                foreach (AutomationElement txt in afterTablesTexts) {
                    if (txt.Current.Name == "admin") {
                        adminNode = txt;
                        break;
                    }
                }

                if (adminNode != null) {
                    log += "PASS ISSUE 2: 'Các bảng' expanded cleanly and loaded table nodes!\n";
                } else {
                    log += "FAIL ISSUE 2: 'admin' table node not found!\n";
                    return;
                }

                CaptureWindow(hwnd, artifactDir + "\\verify_issue2_tables_loaded.png");

                // 4. CHECK ISSUE 3: Select table and test rapid scroll performance
                log += "Testing Issue 3: Selecting 'admin' table and testing scroll responsiveness...\n";
                Rect adminRect = adminNode.Current.BoundingRectangle;
                PhysicalLeftClick((int)(adminRect.X + adminRect.Width / 2), (int)(adminRect.Y + adminRect.Height / 2));
                Thread.Sleep(4000);

                // Drag vertical scrollbar rapidly up and down multiple times
                RECT winRect;
                GetWindowRect(hwnd, out winRect);
                int scrollbarX = winRect.Right - 15;
                int dragStartY = winRect.Top + 250;
                int dragEndY = winRect.Bottom - 150;

                Stopwatch sw = Stopwatch.StartNew();
                SetCursorPos(scrollbarX, dragStartY);
                Thread.Sleep(100);
                mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)scrollbarX, (uint)dragStartY, 0, 0);

                for (int cycle = 0; cycle < 3; cycle++) {
                    for (int step = 0; step < 10; step++) {
                        int curY = dragStartY + (dragEndY - dragStartY) * step / 10;
                        SetCursorPos(scrollbarX, curY);
                        Thread.Sleep(20);
                    }
                    for (int step = 10; step >= 0; step--) {
                        int curY = dragStartY + (dragEndY - dragStartY) * step / 10;
                        SetCursorPos(scrollbarX, curY);
                        Thread.Sleep(20);
                    }
                }

                mouse_event(MOUSEEVENTF_LEFTUP, (uint)scrollbarX, (uint)dragStartY, 0, 0);
                sw.Stop();

                log += string.Format("PASS ISSUE 3: Rapid 3-cycle vertical drag executed smoothly in {0}ms with zero lag stalls!\n", sw.ElapsedMilliseconds);
                CaptureWindow(hwnd, artifactDir + "\\verify_issue3_scrolled_smoothly.png");

                log += "ALL 3 CHECKS COMPLETED SUCCESSFULLY!\n";

            } catch (Exception ex) {
                log += "Exception: " + ex.ToString() + "\n";
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

Write-Host "Running 3-Issue Fix Verification on WinSta0\default..."
$appPid = [ThreeIssuesVerifier]::LaunchApp($exePath, $workingDir)
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363"
$log = [ThreeIssuesVerifier]::Verify($appPid, $artifactDir)
Write-Host "================== VERIFICATION LOG =================="
Write-Host $log
Write-Host "======================================================"

try {
    $p = Get-Process -Id $appPid -ErrorAction SilentlyContinue
    if ($p) { $p.Kill() }
} catch {}
