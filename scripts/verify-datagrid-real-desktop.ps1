$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class DataGridRealVerifier {
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

    public static void PhysicalRightClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(200);
        mouse_event(0x0008, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(100);
        mouse_event(0x0010, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(600);
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

    public static string ExecuteVerification(int pid, string artifactDir) {
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

                // 4. Open banggiada table
                AutomationElement banggiadaNode = null;
                var afterTablesTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                foreach (AutomationElement txt in afterTablesTexts) {
                    if (txt.Current.Name == "banggiada") {
                        banggiadaNode = txt;
                        break;
                    }
                }

                if (banggiadaNode == null) {
                    log += "ERROR: 'banggiada' table not found!\n";
                    return;
                }

                Rect bRect = banggiadaNode.Current.BoundingRectangle;
                log += "Clicking 'banggiada' table...\n";
                PhysicalLeftClick((int)(bRect.X + bRect.Width / 2), (int)(bRect.Y + bRect.Height / 2));
                Thread.Sleep(4000);

                // 5. CAPTURE MILESTONE 1: Initial DataGrid Rendering
                string snapInitial = artifactDir + "\\datagrid_rendered_initial.png";
                CaptureWindow(hwnd, snapInitial);
                log += "SUCCESS: Captured initial DataGrid to " + snapInitial + "\n";

                // 6. Test Interactive Sorting: Click on 'id' column header
                // Find column header for 'id'
                RECT winRect;
                GetWindowRect(hwnd, out winRect);

                // Search for Header with Text 'id'
                var allHeaderTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.HeaderItem));
                AutomationElement idHeader = null;
                log += "Found " + allHeaderTexts.Count + " HeaderItems.\n";
                foreach (AutomationElement h in allHeaderTexts) {
                    log += "HeaderItem: " + h.Current.Name + " Rect=" + h.Current.BoundingRectangle.ToString() + "\n";
                    if (h.Current.Name == "id") {
                        idHeader = h;
                        break;
                    }
                }

                int clickHeaderX, clickHeaderY;
                if (idHeader != null) {
                    Rect hr = idHeader.Current.BoundingRectangle;
                    clickHeaderX = (int)(hr.X + hr.Width / 2);
                    clickHeaderY = (int)(hr.Y + hr.Height / 2);
                } else {
                    // Fallback to coordinates: Table starts around X=350, header Y around 135
                    clickHeaderX = winRect.Left + 420;
                    clickHeaderY = winRect.Top + 135;
                }

                log += "Clicking 'id' column header at (" + clickHeaderX + ", " + clickHeaderY + ") to sort Ascending...\n";
                PhysicalLeftClick(clickHeaderX, clickHeaderY);
                Thread.Sleep(1000);

                string snapAsc = artifactDir + "\\datagrid_sorted_asc.png";
                CaptureWindow(hwnd, snapAsc);
                log += "SUCCESS: Captured DataGrid sorted Ascending to " + snapAsc + "\n";

                log += "Clicking 'id' column header again to sort Descending...\n";
                PhysicalLeftClick(clickHeaderX, clickHeaderY);
                Thread.Sleep(1000);

                string snapDesc = artifactDir + "\\datagrid_sorted_desc.png";
                CaptureWindow(hwnd, snapDesc);
                log += "SUCCESS: Captured DataGrid sorted Descending to " + snapDesc + "\n";

                log += "Clicking 'id' column header third time to Clear sort...\n";
                PhysicalLeftClick(clickHeaderX, clickHeaderY);
                Thread.Sleep(1000);

                string snapClear = artifactDir + "\\datagrid_sorted_cleared.png";
                CaptureWindow(hwnd, snapClear);
                log += "SUCCESS: Captured DataGrid sorted Cleared to " + snapClear + "\n";

                // 7. Test Fast Scrolling on DataGrid
                int tableCenterX = winRect.Left + 550;
                int tableCenterY = winRect.Top + 400;
                log += "Performing 20 fast wheel down events on DataGrid at (" + tableCenterX + ", " + tableCenterY + ")...\n";
                SetCursorPos(tableCenterX, tableCenterY);
                Thread.Sleep(200);

                for (int w = 0; w < 20; w++) {
                    mouse_event(0x0800, 0, 0, unchecked((uint)-240), 0);
                    Thread.Sleep(10);
                }
                Thread.Sleep(800);

                string snapScroll = artifactDir + "\\datagrid_scrolled_fast.png";
                CaptureWindow(hwnd, snapScroll);
                log += "SUCCESS: Captured DataGrid fast scroll to " + snapScroll + "\n";

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

Write-Host "Running End-to-End DataGrid Live Verification on WinSta0\default..."
$appPid = [DataGridRealVerifier]::LaunchApp($exePath, $workingDir)
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363"
$log = [DataGridRealVerifier]::ExecuteVerification($appPid, $artifactDir)
Write-Host "================== TEST OUTPUT =================="
Write-Host $log
Write-Host "================================================="

try {
    $p = Get-Process -Id $appPid -ErrorAction SilentlyContinue
    if ($p) { $p.Kill() }
} catch {}
