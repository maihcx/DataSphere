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

public class TabDragReproRunner {
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
    public const uint MOUSEEVENTF_MOVE = 0x0001;

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
        Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(400);
    }

    public static void PhysicalDrag(int startX, int startY, int endX, int endY) {
        SetCursorPos(startX, startY);
        Thread.Sleep(200);
        mouse_event(MOUSEEVENTF_MOVE, 0, 0, 0, 0);
        Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
        Thread.Sleep(200);

        // Move a few pixels down/right to trigger drag threshold
        for (int j = 1; j <= 5; j++) {
            SetCursorPos(startX + j * 2, startY + j * 4);
            mouse_event(MOUSEEVENTF_MOVE, 0, 0, 0, 0);
            Thread.Sleep(30);
        }

        // Smooth drag steps to destination
        int steps = 30;
        for (int i = 1; i <= steps; i++) {
            int cx = (startX + 10) + (endX - (startX + 10)) * i / steps;
            int cy = (startY + 20) + (endY - (startY + 20)) * i / steps;
            SetCursorPos(cx, cy);
            mouse_event(MOUSEEVENTF_MOVE, 0, 0, 0, 0);
            Thread.Sleep(25);
        }

        Thread.Sleep(500);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
        Thread.Sleep(500);
    }

    public static bool CaptureWindow(IntPtr hwnd, string savePath) {
        RECT r;
        if (!GetWindowRect(hwnd, out r)) return false;
        int w = r.Right - r.Left;
        int h = r.Bottom - r.Top;
        if (w <= 0 || h <= 0) return false;

        using (Bitmap bmp = new Bitmap(w, h)) {
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

    public static string RunDiagnostic(int pid, string artifactDir) {
        string log = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) {
                log += "Failed to open default desktop: " + Marshal.GetLastWin32Error() + "\n";
                return;
            }
            SetThreadDesktop(hDesk);

            try {
                // Find primary window
                AutomationElement win1 = null;
                IntPtr hwnd1 = IntPtr.Zero;
                for (int i = 0; i < 30; i++) {
                    Thread.Sleep(300);
                    var cond = new PropertyCondition(AutomationElement.ProcessIdProperty, pid);
                    win1 = AutomationElement.RootElement.FindFirst(TreeScope.Children, cond);
                    if (win1 != null) {
                        hwnd1 = (IntPtr)win1.Current.NativeWindowHandle;
                        log += "Found Window 1 (HWND=" + hwnd1 + ")\n";
                        break;
                    }
                }

                if (win1 == null) {
                    log += "ERROR: Window 1 not found for PID " + pid + "\n";
                    return;
                }

                SetForegroundWindow(hwnd1);
                Thread.Sleep(2000);

                // Step 1: Click Database Card to create a dynamic tab
                log += "Locating Database Card button...\n";
                var btnCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button);
                var allButtons = win1.FindAll(TreeScope.Descendants, btnCond);
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
                    Rect r = dbCardBtn.Current.BoundingRectangle;
                    log += "Clicking Database Card at (" + (int)(r.X + r.Width/2) + "," + (int)(r.Y + r.Height/2) + ")...\n";
                    PhysicalClick((int)(r.X + r.Width/2), (int)(r.Y + r.Height/2));
                } else {
                    log += "ERROR: Database Card button not found!\n";
                    return;
                }

                Thread.Sleep(2500);

                // Step 2: Find dynamic tab item
                RECT win1Rect;
                GetWindowRect(hwnd1, out win1Rect);
                log += "Window 1 Rect: Left=" + win1Rect.Left + " Top=" + win1Rect.Top + " Right=" + win1Rect.Right + " Bottom=" + win1Rect.Bottom + "\n";

                var tabCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem);
                var tabs = win1.FindAll(TreeScope.Descendants, tabCond);
                AutomationElement dynTab = null;
                AutomationElement homeTab1 = null;

                foreach (AutomationElement tab in tabs) {
                    try {
                        string name = tab.Current.Name;
                        Rect r = tab.Current.BoundingRectangle;
                        log += "Found Tab: '" + name + "' Rect: " + r + "\n";
                        // Top title bar tabs are strictly at r.Y < win1Rect.Top + 20
                        if (r.Y < win1Rect.Top + 20) {
                            if (name.Contains("Home") || name.Contains("Trang ch") || r.Width < 60) {
                                homeTab1 = tab;
                            } else {
                                dynTab = tab;
                            }
                        }
                    } catch {}
                }

                if (dynTab == null) {
                    log += "ERROR: Dynamic Tab not found!\n";
                    return;
                }

                // Capture initial state with 2 tabs
                CaptureWindow(hwnd1, artifactDir + "\\01_repro_two_tabs.png");
                log += "Captured 01_repro_two_tabs.png\n";

                // Step 3: Tear off dynamic tab to outside of Window 1
                Rect tabRect = dynTab.Current.BoundingRectangle;
                int startX = (int)(tabRect.X + tabRect.Width / 2);
                int startY = (int)(tabRect.Y + tabRect.Height / 2);
                int dropX = (int)(win1Rect.Right + 120);
                int dropY = (int)(win1Rect.Top + 250);

                log += "Tearing off dynamic tab from (" + startX + "," + startY + ") to (" + dropX + "," + dropY + ")...\n";
                PhysicalDrag(startX, startY, dropX, dropY);
                Thread.Sleep(3000);

                // Step 4: Find all windows for this PID
                var allWins = AutomationElement.RootElement.FindAll(
                    TreeScope.Children,
                    new PropertyCondition(AutomationElement.ProcessIdProperty, pid)
                );
                log += "Windows found for PID: " + allWins.Count + "\n";

                AutomationElement win2 = null;
                IntPtr hwnd2 = IntPtr.Zero;

                foreach (AutomationElement w in allWins) {
                    IntPtr handle = (IntPtr)w.Current.NativeWindowHandle;
                    if (handle != hwnd1) {
                        win2 = w;
                        hwnd2 = handle;
                        log += "Found Window 2 (Torn-off window, HWND=" + hwnd2 + ")\n";
                    }
                }

                // Capture Window 1 after tear-off (now Window 1 only has Home tab in TabStripHeader)
                CaptureWindow(hwnd1, artifactDir + "\\02_repro_win1_home_alone.png");
                log += "Captured 02_repro_win1_home_alone.png\n";

                if (win2 != null) {
                    CaptureWindow(hwnd2, artifactDir + "\\03_repro_win2_torn_off.png");
                    log += "Captured 03_repro_win2_torn_off.png\n";
                }

                // Step 5: Inspect Window 1's TitleBar / TabArea hierarchy
                log += "\n--- Inspecting Window 1 Elements (Sole Home Tab state) ---\n";
                var win1Tabs = win1.FindAll(TreeScope.Descendants, tabCond);
                log += "Window 1 TabItems count: " + win1Tabs.Count + "\n";
                foreach (AutomationElement tItem in win1Tabs) {
                    log += "  Win1 Tab: '" + tItem.Current.Name + "' Rect=" + tItem.Current.BoundingRectangle + "\n";
                }

                // Check CustomDragRegion or titlebar area in Window 1
                GetWindowRect(hwnd1, out win1Rect);
                log += "Window 1 Rect: Left=" + win1Rect.Left + " Top=" + win1Rect.Top + " Right=" + win1Rect.Right + " Bottom=" + win1Rect.Bottom + "\n";

                // Step 6: Drag tab from Window 2 back towards Window 1's tab area
                if (win2 != null) {
                    SetForegroundWindow(hwnd2);
                    Thread.Sleep(1000);

                    RECT win2Rect;
                    GetWindowRect(hwnd2, out win2Rect);
                    var win2Tabs = win2.FindAll(TreeScope.Descendants, tabCond);
                    AutomationElement win2DynTab = null;
                    foreach (AutomationElement tItem in win2Tabs) {
                        string name = tItem.Current.Name;
                        Rect r = tItem.Current.BoundingRectangle;
                        if (r.Y < win2Rect.Top + 20 && !name.Contains("Home") && !name.Contains("Trang ch") && r.Width >= 60) {
                            win2DynTab = tItem;
                            break;
                        }
                    }

                    if (win2DynTab != null) {
                        Rect w2TabRect = win2DynTab.Current.BoundingRectangle;
                        int w2X = (int)(w2TabRect.X + w2TabRect.Width / 2);
                        int w2Y = (int)(w2TabRect.Y + w2TabRect.Height / 2);

                        // Target in Window 1: right next to Home tab in the tabstrip area
                        // Window 1's home tab is at the left, tab strip is at Y ~ win1Rect.Top + 20
                        int targetX = win1Rect.Left + 150; // In the tabstrip area where dynamic tabs normally live
                        int targetY = win1Rect.Top + 20;

                        log += "Attempting to drag dynamic tab from Window 2 (" + w2X + "," + w2Y + ") back to Window 1 Tab Area (" + targetX + "," + targetY + ")...\n";
                        PhysicalDrag(w2X, w2Y, targetX, targetY);
                        Thread.Sleep(2500);

                        // Capture Window 1 after failed drop attempt
                        CaptureWindow(hwnd1, artifactDir + "\\04_repro_after_drop_attempt.png");
                        log += "Captured 04_repro_after_drop_attempt.png\n";

                        // Check Window 1 tabs again
                        var win1TabsAfter = win1.FindAll(TreeScope.Descendants, tabCond);
                        log += "Window 1 TabItems count after drag-back: " + win1TabsAfter.Count + " (Expected to fail/remain 1 due to the bug!)\n";
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
        t.Join(45000);
        return log;
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies WindowsBase, UIAutomationClient, UIAutomationTypes, System.Drawing

# 1. Kill existing DataSphere processes
Get-Process DataSphere -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500

$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\82efb6f9-3dcc-4e7e-ac8a-04c9e2fa180f"

Write-Host "Launching DataSphere on WinSta0\default..."
$pidNum = [TabDragReproRunner]::LaunchApp($exePath, $workingDir)
Write-Host "Launched DataSphere PID: $pidNum"

Start-Sleep -Seconds 2

Write-Host "Executing diagnostic reproduction..."
$resultLog = [TabDragReproRunner]::RunDiagnostic($pidNum, $artifactDir)
Write-Host $resultLog

# Clean up
Get-Process -Id $pidNum -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process DataSphere -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host "Diagnostic run finished."
