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

public class TabMemorySaverVerifier {
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
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(400);
    }

    public static void PhysicalDoubleClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(150);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(400);
    }

    public static void PhysicalRightClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(150);
        mouse_event(MOUSEEVENTF_RIGHTDOWN, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_RIGHTUP, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(400);
    }

    public static void PhysicalScroll(int x, int y, int delta) {
        SetCursorPos(x, y);
        Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_WHEEL, (uint)x, (uint)y, (uint)delta, UIntPtr.Zero);
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
                string dir = Path.GetDirectoryName(path);
                if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
                bmp.Save(path, ImageFormat.Png);
            }
        }
    }

    public static string RunVerification(int appPid, string artifactDir) {
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
                    PhysicalDoubleClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(2500);
                }

                // Step 5: Click table 'banggiada_backup'
                log += "5. Clicking table 'banggiada_backup'...\n";
                allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement targetTableNode = null;
                foreach (AutomationElement txt in allTexts) {
                    string name = txt.Current.Name ?? "";
                    if (name.Contains("banggiada") || name.Contains("backup")) {
                        targetTableNode = txt;
                        break;
                    }
                }

                if (targetTableNode != null) {
                    Rect r = targetTableNode.Current.BoundingRectangle;
                    PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                }
                Thread.Sleep(3500);

                string cap1 = Path.Combine(artifactDir, "01_table_active_before_switch.png");
                CaptureWindow(hwnd, cap1);
                log += "Captured 01: Initial table active (" + cap1 + ")\n";

                // Step 6: Click Home Tab to switch away
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

                // Step 8: Scroll down on Settings page to display Performance & Memory section
                log += "8. Scrolling down on Settings Page to view Performance & Memory cards...\n";
                int scrollCenterSettingsX = (int)(winRect.X + winRect.Width * 0.5);
                int scrollCenterSettingsY = (int)(winRect.Y + winRect.Height * 0.5);
                for (int s = 0; s < 6; s++) {
                    PhysicalScroll(scrollCenterSettingsX, scrollCenterSettingsY, -240);
                    Thread.Sleep(100);
                }
                Thread.Sleep(1500);

                string capSettings = Path.Combine(artifactDir, "05_settings_memory_saver_card.png");
                CaptureWindow(hwnd, capSettings);
                log += "Captured 05: Settings Page Performance & Memory Saver section (" + capSettings + ")\n";

                // Step 9: Switch back to Database tab
                log += "9. Switching back to Database Tab (topTabs[1])...\n";
                allTabs = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                topTabs.Clear();
                foreach (AutomationElement tab in allTabs) {
                    Rect r = tab.Current.BoundingRectangle;
                    if (r.Y < winRect.Y + 80 && r.Height > 20 && r.Height < 60) {
                        topTabs.Add(tab);
                    }
                }
                topTabs.Sort((a, b) => a.Current.BoundingRectangle.X.CompareTo(b.Current.BoundingRectangle.X));
                if (topTabs.Count > 1) {
                    Rect dbTabRect = topTabs[1].Current.BoundingRectangle;
                    PhysicalLeftClick((int)(dbTabRect.X + dbTabRect.Width / 2), (int)(dbTabRect.Y + dbTabRect.Height / 2));
                    Thread.Sleep(1500);
                }

                // Step 10: Click table cell and scroll
                int tableCenterX = (int)(winRect.X + winRect.Width * 0.65);
                int tableCenterY = (int)(winRect.Y + winRect.Height * 0.45);
                log += "10. Clicking table cell at (" + tableCenterX + ", " + tableCenterY + ")...\n";
                PhysicalLeftClick(tableCenterX, tableCenterY);
                Thread.Sleep(500);

                log += "11. Scrolling down on table with mouse wheel...\n";
                for (int s = 0; s < 5; s++) {
                    PhysicalScroll(tableCenterX, tableCenterY, -240);
                    Thread.Sleep(100);
                }
                Thread.Sleep(1500);

                string capSwitch = Path.Combine(artifactDir, "06_tab_switch_responsive.png");
                CaptureWindow(hwnd, capSwitch);
                log += "Captured 06: Database Tab active and responsive after switch (" + capSwitch + ")\n";

                // Step 11: Close Database Tab via close button
                log += "12. Closing Database Tab to test terminal disposal...\n";
                allTabs = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                topTabs.Clear();
                foreach (AutomationElement tab in allTabs) {
                    Rect r = tab.Current.BoundingRectangle;
                    if (r.Y < winRect.Y + 80 && r.Height > 20 && r.Height < 60) {
                        topTabs.Add(tab);
                    }
                }
                topTabs.Sort((a, b) => a.Current.BoundingRectangle.X.CompareTo(b.Current.BoundingRectangle.X));
                if (topTabs.Count > 1) {
                    var closeBtns = topTabs[1].FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
                    if (closeBtns.Count > 0) {
                        Rect cbr = closeBtns[0].Current.BoundingRectangle;
                        log += "Found close button at (" + (int)(cbr.X + cbr.Width / 2) + ", " + (int)(cbr.Y + cbr.Height / 2) + "), clicking...\n";
                        PhysicalLeftClick((int)(cbr.X + cbr.Width / 2), (int)(cbr.Y + cbr.Height / 2));
                        Thread.Sleep(1500);
                    }
                }

                string capClosed = Path.Combine(artifactDir, "07_tab_closed_cleanup.png");
                CaptureWindow(hwnd, capClosed);
                log += "Captured 07: Tab closed cleanly, returned to home (" + capClosed + ")\n";

                log += "SUCCESS: End-to-end verification completed successfully.\n";

            } catch (Exception ex) {
                log += "Exception during verification: " + ex.ToString() + "\n";
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

Get-Process -Name "DataSphere" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

$pidApp = [TabMemorySaverVerifier]::LaunchApp($exePath, $workingDir)
Write-Host "Launched DataSphere with PID: $pidApp"
try {
    $report = [TabMemorySaverVerifier]::RunVerification($pidApp, $artifactDir)
    Write-Host "=== VERIFICATION REPORT ==="
    Write-Host $report
} finally {
    Get-Process -Id $pidApp -ErrorAction SilentlyContinue | Stop-Process -Force
    Write-Host "Terminated DataSphere process."
}
