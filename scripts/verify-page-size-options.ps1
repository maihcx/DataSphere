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

public class PageSizeVerifier {
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

    public static string RunTest(int appPid, string artifactDir) {
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
                log += "1. App Window acquired.\n";

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
                log += "2. Navigated to Database Page.\n";

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
                log += "3. Opened Connection Tab.\n";

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

                // Find 'Các bảng' node under ngocthamcatalog
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
                    log += "Found 'Các bảng' under ngocthamcatalog. Clicking chevron...\n";
                    PhysicalLeftClick((int)(r.X - 40), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(4000);
                }

                // Find table 'accessed' or 'admin' or 'banggiada'
                allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement tableNode = null;
                foreach (AutomationElement txt in allTexts) {
                    string name = txt.Current.Name ?? "";
                    if (name == "admin" || name == "banggiada" || name == "accessed") {
                        Rect r = txt.Current.BoundingRectangle;
                        if (r.X > 0 && r.Y > 0) {
                            tableNode = txt;
                            log += "Found table: " + name + "\n";
                            break;
                        }
                    }
                }

                if (tableNode != null) {
                    Rect r = tableNode.Current.BoundingRectangle;
                    PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(3000);
                }

                // Capture initial state (Default 1000 rows per page)
                string cap1 = System.IO.Path.Combine(artifactDir, "01_page_size_default_1000.png");
                CaptureWindow(hwnd, cap1);
                log += "Captured default view (1000): " + cap1 + "\n";

                // Locate the ComboBox in the pagination footer
                var allCombos = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ComboBox));
                log += "Found " + allCombos.Count + " ComboBoxes.\n";

                AutomationElement pageSizeCombo = null;
                foreach (AutomationElement cb in allCombos) {
                    Rect r = cb.Current.BoundingRectangle;
                    // Footer ComboBox is near the bottom
                    if (r.Y > 300) {
                        pageSizeCombo = cb;
                        break;
                    }
                }

                if (pageSizeCombo != null) {
                    Rect cr = pageSizeCombo.Current.BoundingRectangle;
                    log += "Found PageSize ComboBox at (" + cr.X + ", " + cr.Y + ", " + cr.Width + ", " + cr.Height + "). Value: " + pageSizeCombo.Current.Name + "\n";

                    // 1. Click ComboBox to open dropdown
                    PhysicalLeftClick((int)(cr.X + cr.Width / 2), (int)(cr.Y + cr.Height / 2));
                    Thread.Sleep(1000);

                    // Capture Dropdown open
                    string capDropdown = System.IO.Path.Combine(artifactDir, "02_page_size_dropdown_open.png");
                    CaptureWindow(hwnd, capDropdown);
                    log += "Captured dropdown open: " + capDropdown + "\n";

                    // Inspect list items
                    var allListItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ListItem));
                    log += "Dropdown list items count: " + allListItems.Count + "\n";
                    foreach (AutomationElement li in allListItems) {
                        log += "  - Item: '" + li.Current.Name + "'\n";
                    }

                    // Test selecting 5000
                    foreach (AutomationElement li in allListItems) {
                        if ((li.Current.Name ?? "").Trim() == "5000") {
                            Rect lir = li.Current.BoundingRectangle;
                            log += "Clicking item 5000 at (" + lir.X + ", " + lir.Y + ")...\n";
                            PhysicalLeftClick((int)(lir.X + lir.Width / 2), (int)(lir.Y + lir.Height / 2));
                            break;
                        }
                    }
                    Thread.Sleep(2500);
                    string cap5000 = System.IO.Path.Combine(artifactDir, "03_page_size_selected_5000.png");
                    CaptureWindow(hwnd, cap5000);
                    log += "Captured after selecting 5000: " + cap5000 + "\n";

                    // 2. Open ComboBox and select Infinity
                    cr = pageSizeCombo.Current.BoundingRectangle;
                    PhysicalLeftClick((int)(cr.X + cr.Width / 2), (int)(cr.Y + cr.Height / 2));
                    Thread.Sleep(1000);

                    allListItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ListItem));
                    foreach (AutomationElement li in allListItems) {
                        if ((li.Current.Name ?? "").Trim().IndexOf("Infinity", StringComparison.OrdinalIgnoreCase) >= 0) {
                            Rect lir = li.Current.BoundingRectangle;
                            log += "Clicking item Infinity at (" + lir.X + ", " + lir.Y + ")...\n";
                            PhysicalLeftClick((int)(lir.X + lir.Width / 2), (int)(lir.Y + lir.Height / 2));
                            break;
                        }
                    }
                    Thread.Sleep(2500);
                    string capInfinity = System.IO.Path.Combine(artifactDir, "04_page_size_selected_infinity.png");
                    CaptureWindow(hwnd, capInfinity);
                    log += "Captured after selecting Infinity: " + capInfinity + "\n";

                    // 3. Open ComboBox and select 10000
                    cr = pageSizeCombo.Current.BoundingRectangle;
                    PhysicalLeftClick((int)(cr.X + cr.Width / 2), (int)(cr.Y + cr.Height / 2));
                    Thread.Sleep(1000);

                    allListItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ListItem));
                    foreach (AutomationElement li in allListItems) {
                        if ((li.Current.Name ?? "").Trim() == "10000") {
                            Rect lir = li.Current.BoundingRectangle;
                            log += "Clicking item 10000 at (" + lir.X + ", " + lir.Y + ")...\n";
                            PhysicalLeftClick((int)(lir.X + lir.Width / 2), (int)(lir.Y + lir.Height / 2));
                            break;
                        }
                    }
                    Thread.Sleep(2500);
                    string cap10000 = System.IO.Path.Combine(artifactDir, "05_page_size_selected_10000.png");
                    CaptureWindow(hwnd, cap10000);
                    log += "Captured after selecting 10000: " + cap10000 + "\n";
                } else {
                    log += "Could NOT find PageSize ComboBox!\n";
                }
            } catch (Exception ex) {
                log += "Error during test: " + ex.ToString() + "\n";
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
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\6a042fbb-da21-411f-8aa8-3ee3c378e2d5"

Write-Host "Killing any existing DataSphere instances..."
Get-Process -Name "DataSphere" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

Write-Host "Launching DataSphere on WinSta0\default..."
$pidApp = [PageSizeVerifier]::LaunchApp($exePath, $workingDir)
Write-Host "App launched with PID: $pidApp"

try {
    $report = [PageSizeVerifier]::RunTest($pidApp, $artifactDir)
    Write-Host "=== TEST REPORT ==="
    Write-Host $report
} finally {
    Write-Host "Cleaning up DataSphere process (PID $pidApp)..."
    Get-Process -Id $pidApp -ErrorAction SilentlyContinue | Stop-Process -Force
}
