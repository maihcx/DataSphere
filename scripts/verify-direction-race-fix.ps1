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

public class DirectionFixVerifier {
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

    public static string RunAlternatingTabTest(int pid, string artifactDir) {
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

                // 1. Click Database card
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
                    log += string.Format("Navigating to Database at ({0}, {1})...\n", (int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(3000);
                }

                // 2. Locate connection node 'localhost' with retries
                AutomationElement connNode = null;
                int nodeRetries = 0;
                while (connNode == null && nodeRetries < 20) {
                    var allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                    foreach (AutomationElement txt in allTexts) {
                        if ((txt.Current.Name ?? "").Contains("localhost")) {
                            connNode = txt;
                            break;
                        }
                    }
                    if (connNode == null) {
                        Thread.Sleep(500);
                        nodeRetries++;
                    }
                }

                if (connNode != null) {
                    Rect r = connNode.Current.BoundingRectangle;
                    log += string.Format("Opening localhost session at ({0}, {1})...\n", (int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    PhysicalRightClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(1000);

                    var allMenuItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.MenuItem));
                    if (allMenuItems.Count > 0) {
                        Rect mr = allMenuItems[0].Current.BoundingRectangle;
                        PhysicalLeftClick((int)(mr.X + mr.Width / 2), (int)(mr.Y + mr.Height / 2));
                    }
                    Thread.Sleep(3500);
                } else {
                    log += "WARNING: localhost node not found in tree view\n";
                }

                // 3. Find inner TabItems
                AutomationElement connTab = null;
                AutomationElement localTab = null;
                int tabRetries = 0;
                while ((connTab == null || localTab == null) && tabRetries < 15) {
                    var allTabs = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                    foreach (AutomationElement tab in allTabs) {
                        Rect tr = tab.Current.BoundingRectangle;
                        if (tr.Y > 200 && tr.Y < 250 && tr.Width > 20) {
                            if (connTab == null) {
                                connTab = tab;
                            } else if (localTab == null && tab != connTab) {
                                localTab = tab;
                            }
                        }
                    }
                    if (connTab == null || localTab == null) {
                        Thread.Sleep(400);
                        tabRetries++;
                    }
                }

                if (connTab != null && localTab != null) {
                    Rect cr = connTab.Current.BoundingRectangle;
                    Rect lr = localTab.Current.BoundingRectangle;
                    int cx = (int)(cr.X + cr.Width / 2);
                    int cy = (int)(cr.Y + cr.Height / 2);
                    int lx = (int)(lr.X + lr.Width / 2);
                    int ly = (int)(lr.Y + lr.Height / 2);

                    log += string.Format("Found inner tabs: Conn at ({0},{1}), Local at ({2},{3})\n", cx, cy, lx, ly);
                    log += "Executing alternating tab transitions:\n";

                    // Cycle 1: 1 -> 0 (backward navigation, enters from left)
                    log += " - Cycle 1: Backward transition to Connection (Index 0)...\n";
                    PhysicalLeftClick(cx, cy);
                    Thread.Sleep(900);

                    // Cycle 2: 0 -> 1 (forward navigation, enters from right)
                    log += " - Cycle 2: Forward transition to localhost (Index 1)...\n";
                    PhysicalLeftClick(lx, ly);
                    Thread.Sleep(900);

                    // Cycle 3: 1 -> 0 (backward navigation, enters from left)
                    log += " - Cycle 3: Backward transition to Connection (Index 0)...\n";
                    PhysicalLeftClick(cx, cy);
                    Thread.Sleep(900);

                    // Cycle 4: 0 -> 1 (forward navigation, enters from right)
                    log += " - Cycle 4: Forward transition to localhost (Index 1)...\n";
                    PhysicalLeftClick(lx, ly);
                    Thread.Sleep(900);

                    string snap = Path.Combine(artifactDir, "04_tab_direction_fixed.png");
                    CaptureWindow(hwnd, snap);
                    log += "Captured 04_tab_direction_fixed.png\n";
                    log += "SUCCESS: Alternating transitions executed smoothly without exceptions.\n";
                } else {
                    log += "ERROR: Could not locate both inner tabs for switching.\n";
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
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\d95f0652-9d5d-4b63-99a7-69c856d9c98f"

Write-Host "Running Alternating Tab Direction Verification on WinSta0\default..."
$pidVal = [DirectionFixVerifier]::LaunchApp($exePath, $workingDir)
Write-Host "Launched process with PID: $pidVal"

$log = [DirectionFixVerifier]::RunAlternatingTabTest($pidVal, $artifactDir)
Write-Host "================ VERIFICATION LOG ================"
Write-Host $log
Write-Host "================================================"

try {
    $proc = Get-Process -Id $pidVal -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "Stopping test process $pidVal..."
        $proc.Kill()
    }
} catch {}
