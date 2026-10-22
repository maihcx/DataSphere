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

public class Feature013Verifier {
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
        Thread.Sleep(250);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(600);
    }

    public static void ClickOrInvoke(AutomationElement elem) {
        if (elem == null) return;
        try {
            Rect r = elem.Current.BoundingRectangle;
            int cx = (int)(r.X + r.Width / 2);
            int cy = (int)(r.Y + r.Height / 2);
            SetCursorPos(cx, cy);
            Thread.Sleep(100);
        } catch {}

        try {
            object invPattern;
            if (elem.TryGetCurrentPattern(InvokePattern.Pattern, out invPattern)) {
                ((InvokePattern)invPattern).Invoke();
                Thread.Sleep(600);
                return;
            }
        } catch {}

        try {
            Rect r = elem.Current.BoundingRectangle;
            int cx = (int)(r.X + r.Width / 2);
            int cy = (int)(r.Y + r.Height / 2);
            PhysicalClick(cx, cy);
        } catch {}
    }

    public static bool CaptureWindow(IntPtr hwnd, string savePath) {
        RECT winR;
        GetWindowRect(hwnd, out winR);
        int w = winR.Right - winR.Left;
        int h = winR.Bottom - winR.Top;
        if (w <= 0 || h <= 0) return false;

        using (Bitmap bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb)) {
            using (Graphics g = Graphics.FromImage(bmp)) {
                IntPtr hdc = g.GetHdc();
                bool ok = PrintWindow(hwnd, hdc, 2); // PW_RENDERFULLCONTENT = 2
                if (!ok) ok = PrintWindow(hwnd, hdc, 0);
                g.ReleaseHdc(hdc);
            }
            bmp.Save(savePath, ImageFormat.Png);
        }
        return true;
    }

    private static List<AutomationElement> GetTitleBarTabs(AutomationElement appWin, out AutomationElement homeTab) {
        homeTab = null;
        var result = new List<AutomationElement>();
        var tabItemCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem);
        var allTabs = appWin.FindAll(TreeScope.Descendants, tabItemCond);
        foreach (AutomationElement tab in allTabs) {
            try {
                Rect r = tab.Current.BoundingRectangle;
                // Title bar tabs are at the top (Y < 235)
                if (r.Y > 0 && r.Y < 235 && r.Width > 20) {
                    string name = tab.Current.Name;
                    if (name.Contains("Home") || name.Contains("Trang ch")) {
                        homeTab = tab;
                    } else {
                        result.Add(tab);
                    }
                }
            } catch {}
        }
        return result;
    }

    public static string RunVerification(int pid, string artifactDir) {
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
                        log += "Found window (HWND=" + hwnd + ")\n";
                        break;
                    }
                }

                if (appWin == null) {
                    log += "ERROR: Window not found for PID " + pid + "\n";
                    return;
                }

                SetForegroundWindow(hwnd);
                Thread.Sleep(2000);

                // Scenario 1: Initial state (Home alone in TabStripHeader)
                log += "--- Scenario 1: Home Tab Alone in TabStripHeader ---\n";
                AutomationElement homeTab;
                var dynamicTabs = GetTitleBarTabs(appWin, out homeTab);
                log += "Found HomeTab: " + (homeTab != null) + ", dynamic tabs: " + dynamicTabs.Count + "\n";

                bool homeCloseVisible = false;
                if (homeTab != null) {
                    Rect hr = homeTab.Current.BoundingRectangle;
                    log += "HomeTab rect: (" + (int)hr.X + "," + (int)hr.Y + "," + (int)hr.Width + "x" + (int)hr.Height + ")\n";
                    var btnCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button);
                    var tabButtons = homeTab.FindAll(TreeScope.Descendants, btnCond);
                    foreach (AutomationElement b in tabButtons) {
                        Rect br = b.Current.BoundingRectangle;
                        if (br.Width > 0 && br.Height > 0) {
                            homeCloseVisible = true;
                            log += "  Home Tab close button found: '" + b.Current.Name + "' (" + (int)br.Width + "x" + (int)br.Height + ")\n";
                        }
                    }
                }
                log += "Home Tab close button visible initially: " + homeCloseVisible + " (Expected: True)\n";
                CaptureWindow(hwnd, artifactDir + "\\01_initial_home_alone.png");

                // Scenario 2: Click Database Card on Home page
                log += "\n--- Scenario 2: Dynamic Tab Creation ---\n";
                var allButtons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
                AutomationElement dbCardBtn = null;
                foreach (AutomationElement btn in allButtons) {
                    try {
                        Rect r = btn.Current.BoundingRectangle;
                        if (r.Width > 200 && r.Height > 60) {
                            if (dbCardBtn == null || r.X < dbCardBtn.Current.BoundingRectangle.X) {
                                dbCardBtn = btn;
                            }
                        }
                    } catch {}
                }

                if (dbCardBtn != null) {
                    log += "Clicking / Invoking Database Card...\n";
                    ClickOrInvoke(dbCardBtn);
                }

                Thread.Sleep(3000);

                // Re-query tabs
                dynamicTabs = GetTitleBarTabs(appWin, out homeTab);
                log += "After click, found dynamic tabs: " + dynamicTabs.Count + "\n";

                bool homeCloseHiddenWhenDynOpen = true;
                if (homeTab != null) {
                    var btnCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button);
                    var tabButtons = homeTab.FindAll(TreeScope.Descendants, btnCond);
                    foreach (AutomationElement b in tabButtons) {
                        Rect br = b.Current.BoundingRectangle;
                        if (br.Width > 0 && br.Height > 0) {
                            homeCloseHiddenWhenDynOpen = false;
                        }
                    }
                }
                log += "Home close button hidden with dynamic tab open: " + homeCloseHiddenWhenDynOpen + " (Expected: True)\n";
                CaptureWindow(hwnd, artifactDir + "\\02_dynamic_tab_opened_home_close_hidden.png");

                // Scenario 4: Switch between Home and Dynamic Tab
                log += "\n--- Scenario 4: Switch to Home Tab ---\n";
                if (homeTab != null) {
                    log += "Selecting Home Tab...\n";
                    object selP;
                    if (homeTab.TryGetCurrentPattern(SelectionItemPattern.Pattern, out selP)) {
                        ((SelectionItemPattern)selP).Select();
                    } else {
                        Rect hr = homeTab.Current.BoundingRectangle;
                        int hx = (int)(hr.X + 35);
                        int hy = (int)(hr.Y + hr.Height / 2);
                        PhysicalClick(hx, hy);
                    }
                    Thread.Sleep(1500);
                }
                CaptureWindow(hwnd, artifactDir + "\\03_switch_back_to_home.png");

                // Switch back to Dynamic Tab
                log += "\n--- Switch back to Dynamic Tab ---\n";
                dynamicTabs = GetTitleBarTabs(appWin, out homeTab);
                if (dynamicTabs.Count > 0) {
                    log += "Selecting Dynamic Tab...\n";
                    object selP2;
                    if (dynamicTabs[0].TryGetCurrentPattern(SelectionItemPattern.Pattern, out selP2)) {
                        ((SelectionItemPattern)selP2).Select();
                    } else {
                        Rect dr = dynamicTabs[0].Current.BoundingRectangle;
                        int dx = (int)(dr.X + 35);
                        int dy = (int)(dr.Y + dr.Height / 2);
                        PhysicalClick(dx, dy);
                    }
                    Thread.Sleep(1500);
                }
                CaptureWindow(hwnd, artifactDir + "\\04_database_page_active.png");

                // Scenario 5: Close Dynamic Tab & verify Home fallback
                log += "\n--- Scenario 5: Close Dynamic Tab & verify Home fallback ---\n";
                dynamicTabs = GetTitleBarTabs(appWin, out homeTab);
                if (dynamicTabs.Count > 0) {
                    var btnCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button);
                    var tabButtons = dynamicTabs[0].FindAll(TreeScope.Descendants, btnCond);
                    AutomationElement dynCloseBtn = null;
                    foreach (AutomationElement b in tabButtons) {
                        Rect br = b.Current.BoundingRectangle;
                        if (br.Width > 0 && br.Height > 0) {
                            dynCloseBtn = b;
                            break;
                        }
                    }

                    if (dynCloseBtn != null) {
                        log += "Closing Dynamic Tab via close button invoke...\n";
                        ClickOrInvoke(dynCloseBtn);
                    } else {
                        Rect dr = dynamicTabs[0].Current.BoundingRectangle;
                        int closeX = (int)(dr.Right - 16);
                        int closeY = (int)(dr.Y + dr.Height / 2);
                        log += "Clicking close button on Dynamic Tab at (" + closeX + "," + closeY + ")...\n";
                        PhysicalClick(closeX, closeY);
                    }
                    Thread.Sleep(2000);
                }

                // Verify dynamic tabs closed and Home close button reappeared
                dynamicTabs = GetTitleBarTabs(appWin, out homeTab);
                log += "Dynamic tabs remaining: " + dynamicTabs.Count + " (Expected: 0)\n";

                bool homeCloseReappeared = false;
                AutomationElement homeReappearCloseBtn = null;
                if (homeTab != null) {
                    var btnCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button);
                    var tabButtons = homeTab.FindAll(TreeScope.Descendants, btnCond);
                    foreach (AutomationElement b in tabButtons) {
                        Rect br = b.Current.BoundingRectangle;
                        if (br.Width > 0 && br.Height > 0) {
                            homeCloseReappeared = true;
                            homeReappearCloseBtn = b;
                            log += "  Home Tab close button reappeared: '" + b.Current.Name + "' (" + (int)br.Width + "x" + (int)br.Height + ")\n";
                        }
                    }
                }
                log += "Home Tab close button reappeared: " + homeCloseReappeared + " (Expected: True)\n";
                CaptureWindow(hwnd, artifactDir + "\\05_home_alone_close_reappeared.png");

                // Scenario 6: Application Shutdown via Home Close Button
                log += "\n--- Scenario 6: Application Shutdown via Home Close Button ---\n";
                if (homeReappearCloseBtn != null) {
                    log += "Invoking Home close button...\n";
                    ClickOrInvoke(homeReappearCloseBtn);
                    Thread.Sleep(2500);
                } else if (homeTab != null) {
                    Rect hr = homeTab.Current.BoundingRectangle;
                    int closeX = (int)(hr.Right - 16);
                    int closeY = (int)(hr.Y + hr.Height / 2);
                    log += "Clicking Home Tab close button at (" + closeX + "," + closeY + ")...\n";
                    PhysicalClick(closeX, closeY);
                    Thread.Sleep(2500);
                }

                bool hasExited = false;
                try {
                    Process proc = Process.GetProcessById(pid);
                    hasExited = proc.HasExited;
                } catch {
                    hasExited = true;
                }
                log += "Process exited cleanly after closing sole Home tab: " + hasExited + " (Expected: True)\n";

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
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\1b5d973b-8647-4bce-af8d-364334e40b04"

Write-Host "Launching DataSphere on WinSta0\default..."
$appPid = [Feature013Verifier]::LaunchApp($exePath, $workingDir)
Write-Host "DataSphere launched with PID: $appPid"

$testLog = [Feature013Verifier]::RunVerification($appPid, $artifactDir)
Write-Host "================== VERIFICATION LOG =================="
Write-Host $testLog
Write-Host "======================================================"

# Clean up process if still running
try {
    $proc = Get-Process -Id $appPid -ErrorAction SilentlyContinue
    if ($proc -and -not $proc.HasExited) {
        Write-Host "Cleaning up remaining process PID $appPid..."
        $proc.Kill()
    }
} catch {}
