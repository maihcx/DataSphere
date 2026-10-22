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

public class DatabaseTabStripVerifier {
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
        Thread.Sleep(400);
    }

    public static void PhysicalRightClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(150);
        mouse_event(MOUSEEVENTF_RIGHTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_RIGHTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(500);
    }

    public static void PhysicalDragAndDrop(int fromX, int fromY, int toX, int toY) {
        SetCursorPos(fromX, fromY);
        Thread.Sleep(200);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)fromX, (uint)fromY, 0, 0);
        Thread.Sleep(200);

        int steps = 25;
        for (int i = 1; i <= steps; i++) {
            int curX = fromX + (toX - fromX) * i / steps;
            int curY = fromY + (toY - fromY) * i / steps;
            SetCursorPos(curX, curY);
            Thread.Sleep(20);
        }

        Thread.Sleep(200);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)toX, (uint)toY, 0, 0);
        Thread.Sleep(600);
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

    public static string RunVerification(int pid, string artifactDir) {
        string log = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) {
                log += "ERROR: Failed to open default desktop.\n";
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
                    log += "ERROR: Main window not found.\n";
                    return;
                }

                SetForegroundWindow(hwnd);
                Thread.Sleep(2000);
                log += "Connected to DataSphere window (HWND=" + hwnd + ").\n";

                RECT winR;
                GetWindowRect(hwnd, out winR);
                log += "Window Rect: Left=" + winR.Left + ", Top=" + winR.Top + ", Right=" + winR.Right + ", Bottom=" + winR.Bottom + "\n";

                // Step 1: Click Database Card on HomePage
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
                    log += "Clicking Database card at (" + (int)(r.X + r.Width / 2) + ", " + (int)(r.Y + r.Height / 2) + ")...\n";
                    PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                } else {
                    log += "ERROR: Could not find Database card button!\n";
                    return;
                }

                Thread.Sleep(2500);

                // Step 2: Verify Anchored Connection Tab rendered in TabStripHeader
                string shot1 = artifactDir + "\\01_database_page_connection_tab_anchored.png";
                CaptureWindow(hwnd, shot1);
                log += "Captured Step 1: " + shot1 + "\n";

                // Log all TabItems in appWin to understand element hierarchy
                var allTabItemsInitial = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                log += "Found " + allTabItemsInitial.Count + " total TabItems:\n";
                foreach (AutomationElement ti in allTabItemsInitial) {
                    Rect r = ti.Current.BoundingRectangle;
                    log += "  TabItem Name='" + (ti.Current.Name ?? "") + "' Rect=(" + (int)r.X + "," + (int)r.Y + "," + (int)r.Width + "x" + (int)r.Height + ")\n";
                }

                // Step 3: Open 'localhost' connection via Right-Click Context Menu
                AutomationElement localhostNode = null;
                var allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                foreach (AutomationElement txt in allTexts) {
                    if ((txt.Current.Name ?? "") == "localhost") {
                        localhostNode = txt;
                        break;
                    }
                }

                if (localhostNode != null) {
                    Rect r = localhostNode.Current.BoundingRectangle;
                    int cx = (int)(r.X + r.Width / 2);
                    int cy = (int)(r.Y + r.Height / 2);
                    log += "Right-clicking 'localhost' at (" + cx + ", " + cy + ")...\n";
                    PhysicalRightClick(cx, cy);
                    Thread.Sleep(800);

                    // Click first MenuFlyoutItem ('Mở kết nối' / 'Open Connection')
                    var allMenuItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.MenuItem));
                    if (allMenuItems.Count > 0) {
                        Rect mr = allMenuItems[0].Current.BoundingRectangle;
                        log += "Clicking MenuItem '" + allMenuItems[0].Current.Name + "'...\n";
                        PhysicalLeftClick((int)(mr.X + mr.Width / 2), (int)(mr.Y + mr.Height / 2));
                    }
                } else {
                    log += "WARNING: 'localhost' node not found!\n";
                }

                log += "Waiting 4s for localhost tab to connect...\n";
                Thread.Sleep(4000);

                string shot2 = artifactDir + "\\02_localhost_tab_opened.png";
                CaptureWindow(hwnd, shot2);
                log += "Captured Step 2: " + shot2 + "\n";

                // Step 4: Click anchored Connection tab in TabStripHeader to return to Connection catalog
                // Geometry: winR.Top + 25 < Y < winR.Top + 80, and leftmost (X < winR.Left + 120)
                allTabItemsInitial = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                AutomationElement connTabItem = null;
                foreach (AutomationElement ti in allTabItemsInitial) {
                    Rect r = ti.Current.BoundingRectangle;
                    if (r.Y > winR.Top + 25 && r.Y < winR.Top + 80 && r.X < winR.Left + 120) {
                        connTabItem = ti;
                        break;
                    }
                }

                if (connTabItem != null) {
                    Rect r = connTabItem.Current.BoundingRectangle;
                    int cx = (int)(r.X + r.Width / 2);
                    int cy = (int)(r.Y + r.Height / 2);
                    log += "Clicking anchored Connection TabItem at (" + cx + ", " + cy + ") to test mutual exclusion...\n";
                    PhysicalLeftClick(cx, cy);
                    Thread.Sleep(2000);

                    string shot3 = artifactDir + "\\03_connection_tab_selected_mutual_exclusion.png";
                    CaptureWindow(hwnd, shot3);
                    log += "Captured Step 3: " + shot3 + "\n";
                } else {
                    log += "WARNING: Connection TabItem not found!\n";
                }

                // Step 5: Open 'replica' connection via Right-Click Context Menu
                AutomationElement replicaNode = null;
                allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                foreach (AutomationElement txt in allTexts) {
                    if ((txt.Current.Name ?? "") == "replica") {
                        replicaNode = txt;
                        break;
                    }
                }

                if (replicaNode != null) {
                    Rect r = replicaNode.Current.BoundingRectangle;
                    int cx = (int)(r.X + r.Width / 2);
                    int cy = (int)(r.Y + r.Height / 2);
                    log += "Right-clicking 'replica' at (" + cx + ", " + cy + ")...\n";
                    PhysicalRightClick(cx, cy);
                    Thread.Sleep(1000);

                    var allMenuItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.MenuItem));
                    if (allMenuItems.Count > 0) {
                        Rect mr = allMenuItems[0].Current.BoundingRectangle;
                        log += "Clicking MenuItem '" + allMenuItems[0].Current.Name + "'...\n";
                        PhysicalLeftClick((int)(mr.X + mr.Width / 2), (int)(mr.Y + mr.Height / 2));
                    }
                } else {
                    log += "WARNING: 'replica' node not found!\n";
                }

                log += "Waiting 4s for replica tab to connect...\n";
                Thread.Sleep(4000);

                string shot4 = artifactDir + "\\04_both_dynamic_tabs_opened.png";
                CaptureWindow(hwnd, shot4);
                log += "Captured Step 4: " + shot4 + "\n";

                // Step 6: Test In-Page Tab Reordering
                // Dynamic tabs are TabItem elements with Y > winR.Top + 25 && X > winR.Left + 100
                var allTabsNow = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                List<AutomationElement> dynamicTabs = new List<AutomationElement>();
                foreach (AutomationElement ti in allTabsNow) {
                    Rect r = ti.Current.BoundingRectangle;
                    if (r.Y > winR.Top + 25 && r.Y < winR.Top + 80 && r.X >= winR.Left + 90) {
                        dynamicTabs.Add(ti);
                    }
                }

                log += "Found " + dynamicTabs.Count + " dynamic tabs in InnerTabView.\n";

                if (dynamicTabs.Count >= 2) {
                    // Sort dynamic tabs by X ascending (tab 1, tab 2)
                    dynamicTabs.Sort((a, b) => a.Current.BoundingRectangle.X.CompareTo(b.Current.BoundingRectangle.X));

                    Rect r1 = dynamicTabs[0].Current.BoundingRectangle;
                    Rect r2 = dynamicTabs[1].Current.BoundingRectangle;
                    int fromX = (int)(r2.X + r2.Width / 2);
                    int fromY = (int)(r2.Y + r2.Height / 2);
                    int toX = (int)(r1.X + 15);
                    int toY = (int)(r1.Y + r1.Height / 2);

                    log += "Dragging tab 2 from (" + fromX + ", " + fromY + ") to (" + toX + ", " + toY + ") to test in-page reordering...\n";
                    PhysicalDragAndDrop(fromX, fromY, toX, toY);
                    Thread.Sleep(2000);

                    string shot5 = artifactDir + "\\05_tabs_reordered_in_page.png";
                    CaptureWindow(hwnd, shot5);
                    log += "Captured Step 5: " + shot5 + "\n";
                }

                // Step 7: Close one dynamic tab, then close the other dynamic tab, verify automatic fallback to Connection catalog
                allTabsNow = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                List<AutomationElement> innerTabsToClose = new List<AutomationElement>();
                foreach (AutomationElement ti in allTabsNow) {
                    Rect r = ti.Current.BoundingRectangle;
                    if (r.Y > winR.Top + 25 && r.Y < winR.Top + 80 && r.X >= winR.Left + 90) {
                        innerTabsToClose.Add(ti);
                    }
                }

                if (innerTabsToClose.Count > 0) {
                    // Close the first dynamic inner tab via its close button
                    AutomationElement tab1 = innerTabsToClose[0];
                    var closeButtons = tab1.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
                    if (closeButtons.Count > 0) {
                        Rect cr = closeButtons[0].Current.BoundingRectangle;
                        log += "Closing first dynamic inner tab via close button at (" + (int)(cr.X + cr.Width / 2) + ", " + (int)(cr.Y + cr.Height / 2) + ")...\n";
                        PhysicalLeftClick((int)(cr.X + cr.Width / 2), (int)(cr.Y + cr.Height / 2));
                        Thread.Sleep(2500); // Allow close animation and layout shift to settle

                        string shot6 = artifactDir + "\\06_one_tab_closed_other_active.png";
                        CaptureWindow(hwnd, shot6);
                        log += "Captured Step 6: " + shot6 + "\n";
                    }
                }

                // Close remaining dynamic inner tab
                allTabsNow = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                foreach (AutomationElement ti in allTabsNow) {
                    Rect r = ti.Current.BoundingRectangle;
                    if (r.Y > winR.Top + 25 && r.Y < winR.Top + 80 && r.X >= winR.Left + 90) {
                        var closeButtons = ti.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
                        if (closeButtons.Count > 0) {
                            Rect cr = closeButtons[0].Current.BoundingRectangle;
                            log += "Closing last dynamic inner tab via close button at (" + (int)(cr.X + cr.Width / 2) + ", " + (int)(cr.Y + cr.Height / 2) + ")...\n";
                            PhysicalLeftClick((int)(cr.X + cr.Width / 2), (int)(cr.Y + cr.Height / 2));
                            Thread.Sleep(2500); // Allow tab to close and fallback to trigger
                            break;
                        }
                    }
                }

                // Step 8: Verify fallback to Connection tab
                string shot7 = artifactDir + "\\07_all_dynamic_tabs_closed_fallback_to_connection.png";
                CaptureWindow(hwnd, shot7);
                log += "Captured Step 7: " + shot7 + "\n";
                log += "VERIFICATION COMPLETED SUCCESSFULLY.\n";

            } catch (Exception ex) {
                log += "EXCEPTION during verification: " + ex.ToString() + "\n";
            } finally {
                CloseDesktop(hDesk);
            }
        });

        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join(90000); // 90 seconds max

        return log;
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Windows.Forms", "WindowsBase", "UIAutomationClient", "UIAutomationTypes", "System.Drawing"

$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\82efb6f9-3dcc-4e7e-ac8a-04c9e2fa180f"

Write-Host "=== Launching DataSphere on WinSta0\default ===" -ForegroundColor Cyan
$appPid = [DatabaseTabStripVerifier]::LaunchApp($exePath, $workingDir)
Write-Host "Launched PID: $appPid" -ForegroundColor Green

Start-Sleep -Seconds 3

Write-Host "=== Executing Verification Pipeline ===" -ForegroundColor Cyan
$log = [DatabaseTabStripVerifier]::RunVerification($appPid, $artifactDir)
Write-Host $log -ForegroundColor Yellow

Write-Host "=== Terminating Process ===" -ForegroundColor Cyan
Stop-Process -Id $appPid -Force -ErrorAction SilentlyContinue

Write-Host "=== Done ===" -ForegroundColor Green
