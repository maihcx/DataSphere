$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class BugReproducer {
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

    public static string Reproduce(int pid, string artifactDir) {
        string log = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) {
                log += "Failed to open default desktop: " + Marshal.GetLastWin32Error() + "\n";
                return;
            }
            SetThreadDesktop(hDesk);

            try {
                var procs = Process.GetProcessesByName("DataSphere");
                if (procs.Length > 0) {
                    pid = procs[0].Id;
                    log += "Targeting running DataSphere PID: " + pid + "\n";
                }

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
                    log += "ERROR: appWin null for PID " + pid + "\n";
                    return;
                }
                SetForegroundWindow(hwnd);
                Thread.Sleep(1500);

                // Right click localhost -> Connect
                log += "Step 1: Connecting to localhost...\n";
                var allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement connNode = null;
                foreach (AutomationElement txt in allTexts) {
                    if (txt.Current.Name == "localhost") {
                        connNode = txt;
                        break;
                    }
                }
                if (connNode == null) {
                    var allButtons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
                    foreach (AutomationElement btn in allButtons) {
                        Rect r = btn.Current.BoundingRectangle;
                        if (r.Width > 200 && r.Height > 60) {
                            PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                            Thread.Sleep(2000);
                            break;
                        }
                    }
                    allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                    foreach (AutomationElement txt in allTexts) {
                        if (txt.Current.Name == "localhost") {
                            connNode = txt;
                            break;
                        }
                    }
                }

                if (connNode != null) {
                    Rect r = connNode.Current.BoundingRectangle;
                    log += string.Format("Right-clicking localhost at ({0},{1})...\n", (int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    SetCursorPos((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(200);
                    mouse_event(0x0008, 0, 0, 0, 0); // Right down
                    Thread.Sleep(100);
                    mouse_event(0x0010, 0, 0, 0, 0); // Right up
                    Thread.Sleep(1000);

                    var allMenuItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.MenuItem));
                    if (allMenuItems.Count > 0) {
                        Rect mr = allMenuItems[0].Current.BoundingRectangle;
                        log += string.Format("Clicking MenuItem '{0}'...\n", allMenuItems[0].Current.Name);
                        PhysicalLeftClick((int)(mr.X + mr.Width / 2), (int)(mr.Y + mr.Height / 2));
                    }
                }

                log += "Waiting 4s for database schemas...\n";
                Thread.Sleep(4000);

                // Expand ngocthamcatalog
                log += "Step 2: Locating ngocthamcatalog...\n";
                var allTreeItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TreeItem));
                AutomationElement targetDbTreeItem = null;
                foreach (AutomationElement item in allTreeItems) {
                    var child = item.FindFirst(TreeScope.Descendants, new PropertyCondition(AutomationElement.NameProperty, "ngocthamcatalog"));
                    if (child != null) {
                        targetDbTreeItem = item;
                        break;
                    }
                }

                if (targetDbTreeItem == null) {
                    log += "ERROR: ngocthamcatalog not found among " + allTreeItems.Count + " TreeItems\n";
                    return;
                }

                Rect dbRect = targetDbTreeItem.Current.BoundingRectangle;
                log += string.Format("Expanding ngocthamcatalog at ({0},{1})...\n", (int)dbRect.X + 37, (int)(dbRect.Y + dbRect.Height / 2));
                PhysicalLeftClick((int)dbRect.X + 37, (int)(dbRect.Y + dbRect.Height / 2));
                Thread.Sleep(2500);

                // ISSUE 1: Check loading on 'Các bảng'
                var treeItemsAfter = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TreeItem));
                AutomationElement tablesCat = null;
                foreach (AutomationElement item in treeItemsAfter) {
                    var texts = item.FindAll(TreeScope.Children, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                    foreach (AutomationElement txt in texts) {
                        string name = txt.Current.Name ?? "";
                        if (name.IndexOf("b\u1EA3ng", StringComparison.OrdinalIgnoreCase) >= 0 ||
                            name.IndexOf("Tables", StringComparison.OrdinalIgnoreCase) >= 0 ||
                            name.IndexOf("b?ng", StringComparison.OrdinalIgnoreCase) >= 0) {
                            tablesCat = item;
                            break;
                        }
                    }
                    if (tablesCat != null) break;
                }

                if (tablesCat != null) {
                    Rect catRect = tablesCat.Current.BoundingRectangle;
                    var catTextChild = tablesCat.FindFirst(TreeScope.Children, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                    int catChevronX = (int)catRect.X + 37;
                    if (catTextChild != null) catChevronX = (int)catTextChild.Current.BoundingRectangle.X - 43;
                    
                    log += "Issue 1: Clicking chevron for 'Các bảng' to observe loading indicator...\n";
                    PhysicalLeftClick(catChevronX, (int)(catRect.Y + catRect.Height / 2));
                    
                    // Immediately check if any ProgressRing is active in treeview
                    var rings = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ProgressBar)); // or Spinner
                    log += "Progress/Spinner elements found in tree during expansion: " + rings.Count + "\n";
                    Thread.Sleep(3000);
                }

                // ISSUE 2: Click admin table and test scroll performance
                AutomationElement adminNode = null;
                var allT = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                foreach (AutomationElement txt in allT) {
                    if (txt.Current.Name == "admin") {
                        adminNode = txt;
                        break;
                    }
                }

                if (adminNode != null) {
                    Rect adminRect = adminNode.Current.BoundingRectangle;
                    PhysicalLeftClick((int)(adminRect.X + adminRect.Width / 2), (int)(adminRect.Y + adminRect.Height / 2));
                    Thread.Sleep(500);
                    PhysicalLeftClick((int)(adminRect.X + adminRect.Width / 2), (int)(adminRect.Y + adminRect.Height / 2));
                    Thread.Sleep(4000);

                    // Capture initial table data screenshot
                    CaptureWindow(hwnd, artifactDir + "\\reproduction_table_loaded.png");
                    log += "Captured reproduction_table_loaded.png\n";

                    // Rapid scroll test to measure lag
                    RECT winRect;
                    GetWindowRect(hwnd, out winRect);
                    int scrollbarX = winRect.Right - 15;
                    log += string.Format("Issue 2: Dragging vertical scrollbar at X={0} rapidly...\n", scrollbarX);

                    Stopwatch sw = Stopwatch.StartNew();
                    int dragStartY = winRect.Top + 250;
                    int dragEndY = winRect.Bottom - 150;

                    // Mouse down on vertical scroll track/thumb and drag up and down
                    SetCursorPos(scrollbarX, dragStartY);
                    Thread.Sleep(100);
                    mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)scrollbarX, (uint)dragStartY, 0, 0);
                    
                    for (int step = 0; step < 10; step++) {
                        int curY = dragStartY + (dragEndY - dragStartY) * step / 10;
                        SetCursorPos(scrollbarX, curY);
                        Thread.Sleep(50);
                    }
                    for (int step = 10; step >= 0; step--) {
                        int curY = dragStartY + (dragEndY - dragStartY) * step / 10;
                        SetCursorPos(scrollbarX, curY);
                        Thread.Sleep(50);
                    }
                    mouse_event(MOUSEEVENTF_LEFTUP, (uint)scrollbarX, (uint)dragStartY, 0, 0);
                    sw.Stop();

                    log += string.Format("Rapid vertical drag test completed in {0}ms\n", sw.ElapsedMilliseconds);
                    CaptureWindow(hwnd, artifactDir + "\\reproduction_after_scroll.png");
                    log += "Captured reproduction_after_scroll.png\n";
                }

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

$appPid = [BugReproducer]::LaunchApp($exePath, $workingDir)
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363"
$log = [BugReproducer]::Reproduce($appPid, $artifactDir)
Write-Host "================== REPRODUCTION LOG =================="
Write-Host $log
Write-Host "======================================================"

try {
    $p = Get-Process -Id $appPid -ErrorAction SilentlyContinue
    if ($p) { $p.Kill() }
} catch {}
