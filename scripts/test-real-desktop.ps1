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

public class RealDesktopRunner {
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
        Thread.Sleep(300);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(600);
    }

    public static string ExecuteRealDesktopTest(int pid, string screenshotPath) {
        string log = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) {
                log += "Failed to open default desktop: " + Marshal.GetLastWin32Error() + "\n";
                return;
            }

            SetThreadDesktop(hDesk);

            try {
                // 1. Locate DataSphere Window on real desktop
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

                // 2. Find Database button by structural properties (large content button on left)
                log += "Searching for Database Card on Home page...\n";
                var btnCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button);
                var allButtons = appWin.FindAll(TreeScope.Descendants, btnCond);
                AutomationElement dbBtn = null;

                foreach (AutomationElement btn in allButtons) {
                    Rect r = btn.Current.BoundingRectangle;
                    // Database Card is a large button (>200 width, >60 height) on the left side of the dashboard
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
                    log += "Located Database Card at (" + (int)rect.X + "," + (int)rect.Y + "," + (int)rect.Width + "x" + (int)rect.Height + ")\n";
                    log += "Physically moving mouse to (" + cx + ", " + cy + ") and clicking...\n";
                    PhysicalClick(cx, cy);
                } else {
                    log += "WARNING: Could not find Database Card button!\n";
                }

                Thread.Sleep(2500);

                // 3. Search for 'New Connection' button on Database tab
                log += "Searching for 'New Connection' button on Database tab...\n";
                var allButtons2 = appWin.FindAll(TreeScope.Descendants, btnCond);
                AutomationElement newConnBtn = null;

                foreach (AutomationElement btn in allButtons2) {
                    Rect r = btn.Current.BoundingRectangle;
                    // The toolbar or empty state New Connection button is inside the active content area (Y > 150)
                    // and not the title bar buttons
                    if (r.Y > 150 && r.Width > 60 && r.Height >= 28 && r.Height <= 60) {
                        // Check if it's the toolbar button or empty state button
                        newConnBtn = btn;
                        log += "Located New Connection Button at (" + (int)r.X + "," + (int)r.Y + "," + (int)r.Width + "x" + (int)r.Height + ")\n";
                        break;
                    }
                }

                if (newConnBtn != null) {
                    Rect rect = newConnBtn.Current.BoundingRectangle;
                    int cx = (int)(rect.X + rect.Width / 2);
                    int cy = (int)(rect.Y + rect.Height / 2);
                    log += "Physically moving mouse to 'New Connection' (" + cx + ", " + cy + ") and clicking...\n";
                    PhysicalClick(cx, cy);
                } else {
                    log += "WARNING: Could not find 'New Connection' button!\n";
                }

                Thread.Sleep(3000);

                // 4. Locate Database Type ComboBox inside ConnectionEditingDialog
                log += "Searching for ComboBox inside dialog...\n";
                var cbCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ComboBox);
                var allCombos = appWin.FindAll(TreeScope.Descendants, cbCond);

                if (allCombos.Count > 0) {
                    AutomationElement cb = allCombos[0];
                    Rect rect = cb.Current.BoundingRectangle;
                    int cx = (int)(rect.X + rect.Width / 2);
                    int cy = (int)(rect.Y + rect.Height / 2);
                    log += "Located ComboBox: '" + cb.Current.Name + "' at (" + cx + ", " + cy + ")\n";
                    log += "Physically moving mouse to ComboBox and clicking to expand dropdown options (MySQL, MariaDB, PostgreSQL)...\n";
                    PhysicalClick(cx, cy);
                    Thread.Sleep(1200);
                } else {
                    log += "WARNING: ComboBox not found in dialog!\n";
                }

                // 5. Capture screenshot of the window on real desktop
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

                Thread.Sleep(2000);
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

Write-Host "Starting Real Desktop End-to-End Test (Zero AutomationId, Physical Mouse Simulation)..."
$appPid = [RealDesktopRunner]::LaunchApp($exePath, $workingDir)
Write-Host "App launched with PID: $appPid on user's real desktop (WinSta0\default)"

$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\aca4648a-7af8-48c3-9b8a-ae269a772d90"
$snapPath = "$artifactDir\real_desktop_verification.png"

$log = [RealDesktopRunner]::ExecuteRealDesktopTest($appPid, $snapPath)
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
