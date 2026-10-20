$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class TreeViewDiagnoser {
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
            throw new InvalidOperationException("CreateProcess failed: " + err);
        }
        return pi.dwProcessId;
    }

    public static void PhysicalLeftClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(150);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(300);
    }

    public static void PhysicalRightClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(150);
        mouse_event(MOUSEEVENTF_RIGHTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_RIGHTUP, (uint)x, (uint)y, 0, 0);
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

    public static string RunDiagnosis(int pid, string artifactDir) {
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
                Thread.Sleep(2000);

                // 1. Click Database Card on Home page
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
                    PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                }
                Thread.Sleep(2500);

                // 2. Open localhost via Right-Click Context Menu
                AutomationElement connNode = null;
                var allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                foreach (AutomationElement txt in allTexts) {
                    if ((txt.Current.Name ?? "").Contains("localhost")) {
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

                    // Click first MenuFlyoutItem ('Mở kết nối')
                    var allMenuItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.MenuItem));
                    if (allMenuItems.Count > 0) {
                        Rect mr = allMenuItems[0].Current.BoundingRectangle;
                        log += "Clicking MenuItem '" + allMenuItems[0].Current.Name + "' at (" + (int)(mr.X + mr.Width / 2) + ", " + (int)(mr.Y + mr.Height / 2) + ")...\n";
                        PhysicalLeftClick((int)(mr.X + mr.Width / 2), (int)(mr.Y + mr.Height / 2));
                    }
                }

                log += "Waiting 4 seconds for localhost tab to connect and load schemas...\n";
                Thread.Sleep(4000);

                // Capture initial state of localhost tab
                CaptureWindow(hwnd, artifactDir + "\\diag_after_connect.png");

                // Dump all TreeItem and Text elements in the window
                log += "\n=== DUMPING ALL TREEITEMS AND TEXTS ===\n";
                var allTreeItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TreeItem));
                log += "Found " + allTreeItems.Count + " TreeItem(s):\n";
                foreach (AutomationElement item in allTreeItems) {
                    Rect ir = item.Current.BoundingRectangle;
                    log += "  TreeItem: '" + item.Current.Name + "', Rect=(" + (int)ir.X + "," + (int)ir.Y + "," + (int)ir.Width + "x" + (int)ir.Height + ")\n";
                    
                    // Inspect children of TreeItem
                    var children = item.FindAll(TreeScope.Children, Condition.TrueCondition);
                    foreach (AutomationElement child in children) {
                        Rect cr = child.Current.BoundingRectangle;
                        log += "    Child: Type=" + child.Current.ControlType.ProgrammaticName + ", Name='" + child.Current.Name + "', Rect=(" + (int)cr.X + "," + (int)cr.Y + "," + (int)cr.Width + "x" + (int)cr.Height + ")\n";
                    }
                }

                var allTextsAfter = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                log += "\nFound " + allTextsAfter.Count + " Text element(s):\n";
                foreach (AutomationElement txt in allTextsAfter) {
                    Rect tr = txt.Current.BoundingRectangle;
                    if (tr.X < 600 && tr.Width > 0 && tr.Height > 0) {
                        log += "  Text: '" + txt.Current.Name + "', Rect=(" + (int)tr.X + "," + (int)tr.Y + "," + (int)tr.Width + "x" + (int)tr.Height + ")\n";
                    }
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

Add-Type -TypeDefinition $source -ReferencedAssemblies WindowsBase, UIAutomationClient, UIAutomationTypes, System.Drawing

$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"

Write-Host "Running TreeView UI Automation Diagnosis..."
$appPid = [TreeViewDiagnoser]::LaunchApp($exePath, $workingDir)
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363"
$log = [TreeViewDiagnoser]::RunDiagnosis($appPid, $artifactDir)
Write-Host "================== DIAG LOG =================="
Write-Host $log
Write-Host "=============================================="

try {
    $p = Get-Process -Id $appPid -ErrorAction SilentlyContinue
    if ($p) { $p.Kill() }
} catch {}
