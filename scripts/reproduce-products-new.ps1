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

public class ProductsNewReproducer {
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
        Thread.Sleep(300);
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
        Thread.Sleep(300);
    }

    public static void PhysicalRightClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(150);
        mouse_event(MOUSEEVENTF_RIGHTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_RIGHTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(300);
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

    public static string Reproduce(int appPid, string artifactDir) {
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
                    PhysicalDoubleClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(2500);
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
                    PhysicalLeftClick((int)(r.X - 40), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(4000);
                }

                // 1. Click table 'accessed'
                allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement accessedNode = null;
                foreach (AutomationElement txt in allTexts) {
                    if ((txt.Current.Name ?? "") == "accessed") {
                        Rect r = txt.Current.BoundingRectangle;
                        if (r.X > 0 && r.Y > 0) {
                            accessedNode = txt;
                            break;
                        }
                    }
                }

                if (accessedNode != null) {
                    Rect r = accessedNode.Current.BoundingRectangle;
                    PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(2500);
                }

                // Set PageSize to Infinity
                var allCombos = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ComboBox));
                AutomationElement pageSizeCombo = null;
                foreach (AutomationElement cb in allCombos) {
                    Rect r = cb.Current.BoundingRectangle;
                    if (r.Y > 300) {
                        pageSizeCombo = cb;
                        break;
                    }
                }

                if (pageSizeCombo != null) {
                    Rect cr = pageSizeCombo.Current.BoundingRectangle;
                    PhysicalLeftClick((int)(cr.X + cr.Width / 2), (int)(cr.Y + cr.Height / 2));
                    Thread.Sleep(1000);

                    var allListItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ListItem));
                    foreach (AutomationElement li in allListItems) {
                        if ((li.Current.Name ?? "").Trim().IndexOf("Infinity", StringComparison.OrdinalIgnoreCase) >= 0) {
                            Rect lir = li.Current.BoundingRectangle;
                            log += "Setting PageSize to Infinity...\n";
                            PhysicalLeftClick((int)(lir.X + lir.Width / 2), (int)(lir.Y + lir.Height / 2));
                            break;
                        }
                    }
                    Thread.Sleep(2000);
                }

                string capAccessed = System.IO.Path.Combine(artifactDir, "01_diagnostic_accessed_infinity_loaded.png");
                CaptureWindow(hwnd, capAccessed);
                log += "Captured table 'accessed' with Infinity: " + capAccessed + "\n";

                // Find 'products_new' in TreeView. If offscreen, scroll TreeView down.
                allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement prodNewNode = null;
                foreach (AutomationElement txt in allTexts) {
                    if ((txt.Current.Name ?? "") == "products_new") {
                        prodNewNode = txt;
                        break;
                    }
                }

                if (prodNewNode != null) {
                    object scrollPatternObj;
                    if (prodNewNode.TryGetCurrentPattern(ScrollItemPattern.Pattern, out scrollPatternObj)) {
                        ((ScrollItemPattern)scrollPatternObj).ScrollIntoView();
                        Thread.Sleep(500);
                    }
                }

                // If still not visible, move mouse to treeview pane and scroll down
                if (prodNewNode == null || prodNewNode.Current.BoundingRectangle.Y <= 0 || prodNewNode.Current.BoundingRectangle.Y > 1000) {
                    // Scroll treeview down with wheel
                    SetCursorPos(100, 700);
                    for (int s = 0; s < 15; s++) {
                        mouse_event(0x0800, 0, 0, unchecked((uint)-240), 0); // WHEEL DOWN
                        Thread.Sleep(60);
                    }
                    Thread.Sleep(1000);

                    allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                    foreach (AutomationElement txt in allTexts) {
                        if ((txt.Current.Name ?? "") == "products_new") {
                            Rect r = txt.Current.BoundingRectangle;
                            if (r.X > 0 && r.Y > 100 && r.Y < 950) {
                                prodNewNode = txt;
                                break;
                            }
                        }
                    }
                }

                if (prodNewNode != null) {
                    Rect r = prodNewNode.Current.BoundingRectangle;
                    log += "Found 'products_new' at (" + r.X + ", " + r.Y + "). Switching...\n";
                    PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));

                    // Capture IMMEDIATELY while query is loading in background!
                    Thread.Sleep(200);
                    string capLingering = System.IO.Path.Combine(artifactDir, "02_diagnostic_stale_data_lingering_during_load.png");
                    CaptureWindow(hwnd, capLingering);
                    log += "Captured screen during loading: " + capLingering + "\n";

                    // Wait 6 seconds for 116,978 rows of products_new to finish loading
                    Thread.Sleep(6000);
                    string capProductsDone = System.IO.Path.Combine(artifactDir, "03_diagnostic_products_new_loaded.png");
                    CaptureWindow(hwnd, capProductsDone);
                    log += "Captured screen after products_new loaded: " + capProductsDone + "\n";
                } else {
                    log += "Could NOT locate 'products_new' in TreeView!\n";
                }
            } catch (Exception ex) {
                log += "Error: " + ex.ToString() + "\n";
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

Get-Process -Name "DataSphere" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

$pidApp = [ProductsNewReproducer]::LaunchApp($exePath, $workingDir)
try {
    $report = [ProductsNewReproducer]::Reproduce($pidApp, $artifactDir)
    Write-Host $report
} finally {
    Get-Process -Id $pidApp -ErrorAction SilentlyContinue | Stop-Process -Force
}
