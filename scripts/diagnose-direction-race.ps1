$source = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class DirectionRaceDiagnoser {
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
    public static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, uint nFlags);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

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
        Thread.Sleep(80);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
        Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
        Thread.Sleep(80);
    }

    public static void PhysicalRightClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(80);
        mouse_event(MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, UIntPtr.Zero);
        Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_RIGHTUP, 0, 0, 0, UIntPtr.Zero);
        Thread.Sleep(80);
    }

    public static void CaptureWindow(IntPtr hwnd, string savePath) {
        RECT rect;
        GetWindowRect(hwnd, out rect);
        int width = rect.Right - rect.Left;
        int height = rect.Bottom - rect.Top;
        if (width <= 0 || height <= 0) return;

        using (Bitmap bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb)) {
            using (Graphics g = Graphics.FromImage(bmp)) {
                IntPtr hdc = g.GetHdc();
                bool ok = PrintWindow(hwnd, hdc, 2); // PW_RENDERFULLCONTENT = 2
                if (!ok) {
                    PrintWindow(hwnd, hdc, 0);
                }
                g.ReleaseHdc(hdc);
            }
            bmp.Save(savePath, ImageFormat.Png);
        }
    }

    public static string RunDiagnosis(int pid, string artifactDir) {
        string log = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) {
                log += "ERROR: Could not open WinSta0\\default\n";
                return;
            }
            SetThreadDesktop(hDesk);

            try {
                Thread.Sleep(4000);
                Process proc = Process.GetProcessById(pid);
                IntPtr hwnd = proc.MainWindowHandle;
                int retries = 0;
                while (hwnd == IntPtr.Zero && retries < 20) {
                    Thread.Sleep(500);
                    proc.Refresh();
                    hwnd = proc.MainWindowHandle;
                    retries++;
                }

                if (hwnd == IntPtr.Zero) {
                    log += "ERROR: MainWindowHandle is Zero\n";
                    return;
                }

                SetForegroundWindow(hwnd);
                Thread.Sleep(1000);

                AutomationElement appWin = AutomationElement.FromHandle(hwnd);
                if (appWin == null) {
                    log += "ERROR: Could not get AutomationElement for MainWindow\n";
                    return;
                }

                log += "1. Finding and clicking Database navigation card...\n";
                var allButtons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
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
                    Rect r = dbBtn.Current.BoundingRectangle;
                    log += string.Format("Clicking Database card at ({0}, {1})...\n", (int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(2500);
                }

                // Locate connection node 'localhost'
                log += "2. Connecting to localhost to open second inner workspace tab...\n";
                var allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement connNode = null;
                foreach (AutomationElement txt in allTexts) {
                    if ((txt.Current.Name ?? "").Contains("localhost")) {
                        connNode = txt;
                        break;
                    }
                }

                if (connNode != null) {
                    Rect r = connNode.Current.BoundingRectangle;
                    log += string.Format("Found localhost at ({0}, {1}), right clicking...\n", (int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    PhysicalRightClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(1000);

                    var allMenuItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.MenuItem));
                    if (allMenuItems.Count > 0) {
                        Rect mr = allMenuItems[0].Current.BoundingRectangle;
                        log += "Clicking Open Connection menu item...\n";
                        PhysicalLeftClick((int)(mr.X + mr.Width / 2), (int)(mr.Y + mr.Height / 2));
                    }
                    Thread.Sleep(3000);
                }

                // Capture initial state with localhost active
                string snap1 = Path.Combine(artifactDir, "diag_tab_localhost_active.png");
                CaptureWindow(hwnd, snap1);
                log += "Captured diag_tab_localhost_active.png\n";

                // Step 3: Find TabItems to test tab switching
                log += "3. Finding TabItems in DatabasePage...\n";
                var allTabs = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                log += "Total TabItems found: " + allTabs.Count + "\n";
                AutomationElement connTab = null;
                AutomationElement localTab = null;
                foreach (AutomationElement tab in allTabs) {
                    string tName = tab.Current.Name ?? "";
                    Rect tr = tab.Current.BoundingRectangle;
                    log += string.Format("TabItem: '{0}' at ({1}, {2}, w={3}, h={4})\n", tName, (int)tr.X, (int)tr.Y, (int)tr.Width, (int)tr.Height);
                    if (tr.Y > 260 && tr.Width > 20) {
                        if (connTab == null) {
                            connTab = tab;
                        } else if (localTab == null) {
                            localTab = tab;
                        }
                    }
                }

                if (connTab != null) {
                    Rect cr = connTab.Current.BoundingRectangle;
                    log += string.Format("Clicking Connection TabItem (backward switch to index 0) at ({0}, {1})...\n", (int)(cr.X + cr.Width / 2), (int)(cr.Y + cr.Height / 2));
                    PhysicalLeftClick((int)(cr.X + cr.Width / 2), (int)(cr.Y + cr.Height / 2));
                    Thread.Sleep(1500);

                    string snap2 = Path.Combine(artifactDir, "diag_tab_ketnoi_backward.png");
                    CaptureWindow(hwnd, snap2);
                    log += "Captured diag_tab_ketnoi_backward.png\n";
                }

                if (localTab != null) {
                    Rect lr = localTab.Current.BoundingRectangle;
                    log += string.Format("Clicking Localhost TabItem (forward switch to index 1) at ({0}, {1})...\n", (int)(lr.X + lr.Width / 2), (int)(lr.Y + lr.Height / 2));
                    PhysicalLeftClick((int)(lr.X + lr.Width / 2), (int)(lr.Y + lr.Height / 2));
                    Thread.Sleep(1500);

                    string snap3 = Path.Combine(artifactDir, "diag_tab_localhost_forward.png");
                    CaptureWindow(hwnd, snap3);
                    log += "Captured diag_tab_localhost_forward.png\n";
                }

                log += "DIAGNOSIS COMPLETE: All tabs inspected and switched.\n";
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
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\d95f0652-9d5d-4b63-99a7-69c856d9c98f"

Write-Host "Running diagnostic on WinSta0\default..."
$pidVal = [DirectionRaceDiagnoser]::LaunchApp($exePath, $workingDir)
Write-Host "Launched process with PID: $pidVal"

$log = [DirectionRaceDiagnoser]::RunDiagnosis($pidVal, $artifactDir)
Write-Host "================ DIAGNOSTIC LOG ================"
Write-Host $log
Write-Host "================================================"

try {
    $proc = Get-Process -Id $pidVal -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "Stopping test process $pidVal..."
        $proc.Kill()
    }
} catch {}
