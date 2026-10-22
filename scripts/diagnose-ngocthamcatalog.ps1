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

public class NgocthamProfiler {
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

    public static void PhysicalDoubleClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(60);
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

    public static string GetMem(int pid) {
        try {
            var proc = Process.GetProcessById(pid);
            proc.Refresh();
            double ws = Math.Round(proc.WorkingSet64 / (1024.0 * 1024.0), 2);
            double priv = Math.Round(proc.PrivateMemorySize64 / (1024.0 * 1024.0), 2);
            return string.Format("WS: {0:F2} MB | Private: {1:F2} MB", ws, priv);
        } catch {
            return "N/A";
        }
    }

    public static string RunProfile(int appPid, string artifactDir) {
        string log = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) {
                log += "Failed to open default desktop.\n";
                return;
            }
            SetThreadDesktop(hDesk);

            try {
                AutomationElement appWin = null;
                IntPtr hwnd = IntPtr.Zero;

                for (int i = 0; i < 30; i++) {
                    Thread.Sleep(300);
                    var cond = new PropertyCondition(AutomationElement.ProcessIdProperty, appPid);
                    appWin = AutomationElement.RootElement.FindFirst(TreeScope.Children, cond);
                    if (appWin != null) {
                        hwnd = (IntPtr)appWin.Current.NativeWindowHandle;
                        break;
                    }
                }

                if (appWin == null) {
                    log += "Could not find window for PID " + appPid + "\n";
                    return;
                }

                SetForegroundWindow(hwnd);
                Thread.Sleep(2000);
                log += "1. Initial Startup: " + GetMem(appPid) + "\n";

                // Click Database Card
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
                log += "2. Navigated to Database Page: " + GetMem(appPid) + "\n";

                // Right click localhost -> Open connection
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
                    PhysicalRightClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(1000);
                    var allMenuItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.MenuItem));
                    if (allMenuItems.Count > 0) {
                        Rect mr = allMenuItems[0].Current.BoundingRectangle;
                        PhysicalLeftClick((int)(mr.X + mr.Width / 2), (int)(mr.Y + mr.Height / 2));
                    }
                }
                Thread.Sleep(3000);
                log += "3. Opened Connection Tab (Databases loaded): " + GetMem(appPid) + "\n";

                // Double click 'ngocthamcatalog' database
                allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement targetDbNode = null;
                foreach (AutomationElement txt in allTexts) {
                    if ((txt.Current.Name ?? "") == "ngocthamcatalog") {
                        targetDbNode = txt;
                        break;
                    }
                }

                if (targetDbNode != null) {
                    Rect r = targetDbNode.Current.BoundingRectangle;
                    log += "Found 'ngocthamcatalog' at (" + r.X + ", " + r.Y + "). Double-clicking...\n";
                    PhysicalDoubleClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(2500);
                } else {
                    log += "Could NOT find 'ngocthamcatalog' node!\n";
                }
                log += "4. Expanded 'ngocthamcatalog' database: " + GetMem(appPid) + "\n";

                // Find 'Các bảng' node under ngocthamcatalog
                allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement tablesCatNode = null;
                foreach (AutomationElement txt in allTexts) {
                    string name = txt.Current.Name ?? "";
                    if (name.Contains("ng") || name.Contains("Tabl") || name.Contains("bảng")) {
                        // Make sure it's below ngocthamcatalog's Y position
                        if (targetDbNode != null && txt.Current.BoundingRectangle.Y > targetDbNode.Current.BoundingRectangle.Y) {
                            tablesCatNode = txt;
                            break;
                        }
                    }
                }

                if (tablesCatNode != null) {
                    Rect r = tablesCatNode.Current.BoundingRectangle;
                    log += "Found 'Các bảng' under ngocthamcatalog at (" + r.X + ", " + r.Y + "). Clicking chevron...\n";
                    // Click chevron to the left
                    PhysicalLeftClick((int)(r.X - 40), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(4000);
                } else {
                    log += "Could NOT find 'Các bảng' under ngocthamcatalog!\n";
                }
                log += "5. After Expanding Tables Category: " + GetMem(appPid) + "\n";

                // Find visible tables under 'Các bảng'
                allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                var candidateNames = new List<string> { "accessed", "admin", "banggiada", "banggiada_backup", "banggiada_hoadon" };
                var foundTables = new List<AutomationElement>();
                foreach (string cName in candidateNames) {
                    foreach (AutomationElement txt in allTexts) {
                        if ((txt.Current.Name ?? "") == cName) {
                            Rect r = txt.Current.BoundingRectangle;
                            if (r.X > 0 && r.Y > 0) {
                                foundTables.Add(txt);
                                break;
                            }
                        }
                    }
                }

                log += "Found " + foundTables.Count + " visible candidate tables in tree.\n";

                int step = 1;
                foreach (var tbl in foundTables) {
                    string tName = tbl.Current.Name;
                    Rect r = tbl.Current.BoundingRectangle;
                    log += "Selecting table '" + tName + "' at (" + (int)(r.X + r.Width / 2) + ", " + (int)(r.Y + r.Height / 2) + ")...\n";
                    PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(3000);
                    log += "6." + step + " Clicked table '" + tName + "': " + GetMem(appPid) + "\n";
                    CaptureWindow(hwnd, System.IO.Path.Combine(artifactDir, "ngoctham_step_" + step + "_" + tName + ".png"));
                    step++;
                }

                // Switch back and forth between 'admin' and 'banggiada' 5 times!
                if (foundTables.Count >= 3) {
                    var adminTbl = foundTables[1];
                    var banggiadaTbl = foundTables[2];
                    for (int cycle = 1; cycle <= 5; cycle++) {
                        // Switch to admin
                        Rect rAdmin = adminTbl.Current.BoundingRectangle;
                        PhysicalLeftClick((int)(rAdmin.X + rAdmin.Width / 2), (int)(rAdmin.Y + rAdmin.Height / 2));
                        Thread.Sleep(2000);
                        log += "Cycle " + cycle + " 'admin': " + GetMem(appPid) + "\n";

                        // Switch to banggiada
                        Rect rBgd = banggiadaTbl.Current.BoundingRectangle;
                        PhysicalLeftClick((int)(rBgd.X + rBgd.Width / 2), (int)(rBgd.Y + rBgd.Height / 2));
                        Thread.Sleep(2000);
                        log += "Cycle " + cycle + " 'banggiada': " + GetMem(appPid) + "\n";
                    }
                }

                Thread.Sleep(3000);
                log += "7. Idle after rapid table switching: " + GetMem(appPid) + "\n";
                CaptureWindow(hwnd, System.IO.Path.Combine(artifactDir, "03_diagnostic_ngoctham_table_data.png"));

            } catch (Exception ex) {
                log += "Exception: " + ex.ToString() + "\n";
            } finally {
                CloseDesktop(hDesk);
            }
        });

        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join(90000);
        return log;
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing", "UIAutomationClient", "UIAutomationTypes", "WindowsBase"

$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\6a042fbb-da21-411f-8aa8-3ee3c378e2d5"

Get-Process DataSphere -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

Write-Host "Launching DataSphere on WinSta0\default..."
$appPid = [NgocthamProfiler]::LaunchApp($exePath, $workingDir)
Write-Host "Launched PID: $appPid"

$resultLog = [NgocthamProfiler]::RunProfile($appPid, $artifactDir)
Write-Host "--- Profile Results ---"
Write-Host $resultLog

Stop-Process -Id $appPid -Force
Write-Host "Complete."
