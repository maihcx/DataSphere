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

public class TabSwitchFreezeReproducer {
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
    public const uint MOUSEEVENTF_WHEEL = 0x0800;

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
        Thread.Sleep(150);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(400);
    }

    public static void PhysicalDoubleClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(150);
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

    public static void PhysicalScroll(int x, int y, int delta) {
        SetCursorPos(x, y);
        Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_WHEEL, (uint)x, (uint)y, (uint)delta, 0);
        Thread.Sleep(200);
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

    public static string ReproduceAndDiagnose(int appPid, string artifactDir, string bugDir) {
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

                // Step 1: Click Database Card on Home page
                log += "1. Clicking Database Card on Home page...\n";
                var allButtons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
                AutomationElement dbBtn = null;
                AutomationElement settingsBtn = null;
                foreach (AutomationElement btn in allButtons) {
                    Rect r = btn.Current.BoundingRectangle;
                    if (r.Width > 200 && r.Height > 60) {
                        if (dbBtn == null || r.X < dbBtn.Current.BoundingRectangle.X) {
                            settingsBtn = dbBtn;
                            dbBtn = btn;
                        } else {
                            settingsBtn = btn;
                        }
                    }
                }
                if (dbBtn != null) {
                    Rect r = dbBtn.Current.BoundingRectangle;
                    PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                }
                Thread.Sleep(2500);

                // Step 2: Open connection to localhost
                log += "2. Connecting to localhost...\n";
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

                // Step 3: Expand ngocthamcatalog database
                log += "3. Expanding ngocthamcatalog...\n";
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
                    PhysicalDoubleClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(2500);
                }

                // Step 4: Expand 'Các bảng' node
                log += "4. Expanding 'Các bảng' category...\n";
                allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement tablesCatNode = null;
                foreach (AutomationElement txt in allTexts) {
                    string name = txt.Current.Name ?? "";
                    if (name.Contains("ng") || name.Contains("Tabl") || name.Contains("bảng")) {
                        if (targetDbNode != null && txt.Current.BoundingRectangle.Y > targetDbNode.Current.BoundingRectangle.Y) {
                            tablesCatNode = txt;
                            break;
                        }
                    }
                }

                if (tablesCatNode != null) {
                    Rect r = tablesCatNode.Current.BoundingRectangle;
                    PhysicalLeftClick((int)(r.X - 40), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(3000);
                }

                // Step 5: Click table 'banggiada_backup'
                log += "5. Clicking table 'banggiada_backup'...\n";
                allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement targetTableNode = null;
                foreach (AutomationElement txt in allTexts) {
                    if ((txt.Current.Name ?? "") == "banggiada_backup") {
                        Rect r = txt.Current.BoundingRectangle;
                        if (r.X > 0 && r.Y > 0) {
                            targetTableNode = txt;
                            break;
                        }
                    }
                }

                // Fallback to banggiada if banggiada_backup not found
                if (targetTableNode == null) {
                    foreach (AutomationElement txt in allTexts) {
                        if ((txt.Current.Name ?? "") == "banggiada") {
                            Rect r = txt.Current.BoundingRectangle;
                            if (r.X > 0 && r.Y > 0) {
                                targetTableNode = txt;
                                break;
                            }
                        }
                    }
                }

                if (targetTableNode != null) {
                    Rect r = targetTableNode.Current.BoundingRectangle;
                    PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                }

                // Wait 4s for data loading
                Thread.Sleep(4000);

                string cap1Artifact = Path.Combine(artifactDir, "01_table_active_before_switch.png");
                string cap1Bug = Path.Combine(bugDir, "01_table_active_before_switch.png");
                CaptureWindow(hwnd, cap1Artifact);
                File.Copy(cap1Artifact, cap1Bug, true);
                log += "Captured 01: Initial table active (" + cap1Artifact + ")\n";

                // Step 6: Switch away! Click Home Tab
                log += "6. Clicking Home Tab to switch away...\n";
                Rect winRect = appWin.Current.BoundingRectangle;
                var allTabs = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                var topTabs = new List<AutomationElement>();
                foreach (AutomationElement tab in allTabs) {
                    Rect r = tab.Current.BoundingRectangle;
                    if (r.Y < winRect.Y + 80 && r.Height > 20 && r.Height < 60) {
                        topTabs.Add(tab);
                    }
                }
                topTabs.Sort((a, b) => a.Current.BoundingRectangle.X.CompareTo(b.Current.BoundingRectangle.X));
                log += "Found " + topTabs.Count + " top tabs before switching to Home.\n";
                for (int i = 0; i < topTabs.Count; i++) {
                    log += "  Tab[" + i + "]: '" + topTabs[i].Current.Name + "' at X=" + (int)topTabs[i].Current.BoundingRectangle.X + "\n";
                }

                if (topTabs.Count > 0) {
                    Rect hr = topTabs[0].Current.BoundingRectangle;
                    PhysicalLeftClick((int)(hr.X + hr.Width / 2), (int)(hr.Y + hr.Height / 2));
                    Thread.Sleep(1500);
                }

                // Step 7: On Home Page, click Settings Card
                log += "7. Clicking Settings Card on Home Page...\n";
                allButtons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
                AutomationElement foundSettingsBtn = null;
                foreach (AutomationElement btn in allButtons) {
                    Rect r = btn.Current.BoundingRectangle;
                    if (r.Width > 200 && r.Height > 60) {
                        if (foundSettingsBtn == null || r.X > foundSettingsBtn.Current.BoundingRectangle.X) {
                            foundSettingsBtn = btn;
                        }
                    }
                }

                if (foundSettingsBtn != null) {
                    Rect sr = foundSettingsBtn.Current.BoundingRectangle;
                    PhysicalLeftClick((int)(sr.X + sr.Width / 2), (int)(sr.Y + sr.Height / 2));
                    Thread.Sleep(2500);
                }

                string cap2Artifact = Path.Combine(artifactDir, "02_settings_tab_opened.png");
                string cap2Bug = Path.Combine(bugDir, "02_settings_tab_opened.png");
                CaptureWindow(hwnd, cap2Artifact);
                File.Copy(cap2Artifact, cap2Bug, true);
                log += "Captured 02: Settings tab opened (" + cap2Artifact + ")\n";

                // Step 8: Switch back to Database tab!
                log += "8. Switching back to Database Tab (topTabs[1])...\n";
                allTabs = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                topTabs.Clear();
                foreach (AutomationElement tab in allTabs) {
                    Rect r = tab.Current.BoundingRectangle;
                    if (r.Y < winRect.Y + 80 && r.Height > 20 && r.Height < 60) {
                        topTabs.Add(tab);
                    }
                }
                topTabs.Sort((a, b) => a.Current.BoundingRectangle.X.CompareTo(b.Current.BoundingRectangle.X));
                log += "Found " + topTabs.Count + " top tabs after opening Settings.\n";
                for (int i = 0; i < topTabs.Count; i++) {
                    log += "  Tab[" + i + "]: '" + topTabs[i].Current.Name + "' at X=" + (int)topTabs[i].Current.BoundingRectangle.X + "\n";
                }

                if (topTabs.Count >= 2) {
                    // topTabs[1] is the Database tab
                    Rect dbr = topTabs[1].Current.BoundingRectangle;
                    log += "Clicking Database Tab at (" + (int)(dbr.X + dbr.Width / 2) + ", " + (int)(dbr.Y + dbr.Height / 2) + ")...\n";
                    PhysicalLeftClick((int)(dbr.X + dbr.Width / 2), (int)(dbr.Y + dbr.Height / 2));
                    Thread.Sleep(2500);
                }

                string cap3Artifact = Path.Combine(artifactDir, "03_switched_back_frozen.png");
                string cap3Bug = Path.Combine(bugDir, "03_switched_back_frozen.png");
                CaptureWindow(hwnd, cap3Artifact);
                File.Copy(cap3Artifact, cap3Bug, true);
                log += "Captured 03: Switched back to Database tab (" + cap3Artifact + ")\n";

                // Step 9: Attempt interaction on the table:
                // 9a. Click inside table cells
                int tableCenterX = (int)(winRect.Left + winRect.Width * 0.65);
                int tableCenterY = (int)(winRect.Top + winRect.Height * 0.45);
                log += "9. Attempting click on table cell at (" + tableCenterX + ", " + tableCenterY + ")...\n";
                PhysicalLeftClick(tableCenterX, tableCenterY);
                Thread.Sleep(500);

                // 9b. Attempt scroll down with mouse wheel
                log += "10. Attempting scroll down on table with mouse wheel...\n";
                for (int s = 0; s < 5; s++) {
                    PhysicalScroll(tableCenterX, tableCenterY, -240);
                    Thread.Sleep(100);
                }
                Thread.Sleep(1500);

                string cap4Artifact = Path.Combine(artifactDir, "04_scrolled_blank_frozen.png");
                string cap4Bug = Path.Combine(bugDir, "04_scrolled_blank_frozen.png");
                CaptureWindow(hwnd, cap4Artifact);
                File.Copy(cap4Artifact, cap4Bug, true);
                log += "Captured 04: Scrolled state - table blank / frozen (" + cap4Artifact + ")\n";

                // Step 10: Check UI Automation elements in table area
                log += "11. Diagnostic UIA inspection of Table viewport...\n";
                allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                int tableTextCount = 0;
                foreach (AutomationElement txt in allTexts) {
                    Rect tr = txt.Current.BoundingRectangle;
                    if (tr.X > winRect.Left + 300 && tr.Y > winRect.Top + 150) {
                        tableTextCount++;
                    }
                }
                log += "Found " + tableTextCount + " text elements in table area.\n";
                log += "Diagnostic reproduction completed successfully.\n";

            } catch (Exception ex) {
                log += "Exception during reproduction: " + ex.ToString() + "\n";
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

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Windows.Forms", "UIAutomationClient", "UIAutomationTypes", "WindowsBase", "System.Drawing"

$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\22f010de-611d-4d85-b016-e7e887f4bd9d"
$bugDir = "D:\DEV\C#DOTNET\DataSphere\.specify\bugs\database-tab-switch-freeze"

Get-Process -Name "DataSphere" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

$pidApp = [TabSwitchFreezeReproducer]::LaunchApp($exePath, $workingDir)
Write-Host "Launched DataSphere with PID: $pidApp"
try {
    $report = [TabSwitchFreezeReproducer]::ReproduceAndDiagnose($pidApp, $artifactDir, $bugDir)
    Write-Host "=== REPRODUCTION & DIAGNOSIS REPORT ==="
    Write-Host $report
} finally {
    Get-Process -Id $pidApp -ErrorAction SilentlyContinue | Stop-Process -Force
    Write-Host "Terminated DataSphere process."
}
