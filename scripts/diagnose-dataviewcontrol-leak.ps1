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

public class DataViewLeakDiagnoser {
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

    public static int LaunchApp(string exePath, string workingDir) {
        STARTUPINFO si = new STARTUPINFO();
        si.cb = Marshal.SizeOf(si);
        si.lpDesktop = @"WinSta0\default";

        PROCESS_INFORMATION pi = new PROCESS_INFORMATION();
        bool success = CreateProcess(exePath, null, IntPtr.Zero, IntPtr.Zero, false, 0, IntPtr.Zero, workingDir, ref si, out pi);
        if (!success) {
            int err = Marshal.GetLastWin32Error();
            throw new Exception("CreateProcess failed with code " + err);
        }

        return pi.dwProcessId;
    }

    public static void PhysicalLeftClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(50);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
        Thread.Sleep(50);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
        Thread.Sleep(100);
    }

    public static void PhysicalDoubleClick(int x, int y) {
        PhysicalLeftClick(x, y);
        Thread.Sleep(80);
        PhysicalLeftClick(x, y);
        Thread.Sleep(150);
    }

    public static void CaptureWindow(IntPtr hwnd, string savePath) {
        RECT rect;
        GetWindowRect(hwnd, out rect);
        int width = rect.Right - rect.Left;
        int height = rect.Bottom - rect.Top;

        if (width <= 0) width = 1280;
        if (height <= 0) height = 800;

        using (Bitmap bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb)) {
            using (Graphics g = Graphics.FromImage(bmp)) {
                IntPtr hdc = g.GetHdc();
                try {
                    PrintWindow(hwnd, hdc, 2); // PW_RENDERFULLCONTENT = 2
                } finally {
                    g.ReleaseHdc(hdc);
                }
            }
            bmp.Save(savePath, ImageFormat.Png);
        }
    }

    public static string RunDiagnosis(string exePath, string workingDir, string artifactDir) {
        string log = "";
        string logFile = @"C:\Users\huynh\AppData\Local\Temp\datasphere_dispose_test.txt";
        if (File.Exists(logFile)) {
            File.Delete(logFile);
        }

        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) {
                log += "Failed to OpenDesktop(default)\n";
                return;
            }

            if (!SetThreadDesktop(hDesk)) {
                log += "Failed to SetThreadDesktop\n";
                CloseDesktop(hDesk);
                return;
            }

            int pid = 0;
            try {
                foreach (var p in Process.GetProcessesByName("DataSphere")) {
                    try { p.Kill(); p.WaitForExit(2000); } catch {}
                }
                Thread.Sleep(1000);

                log += "1. Launching DataSphere...\n";
                pid = LaunchApp(exePath, workingDir);
                log += "Started pid " + pid + "\n";

                IntPtr hwnd = IntPtr.Zero;
                AutomationElement appWin = null;
                for (int i = 0; i < 40; i++) {
                    Thread.Sleep(500);
                    try {
                        Process p = Process.GetProcessById(pid);
                        if (p.MainWindowHandle != IntPtr.Zero) {
                            hwnd = p.MainWindowHandle;
                            appWin = AutomationElement.FromHandle(hwnd);
                            if (appWin != null) break;
                        }
                    } catch {}
                }

                if (appWin == null) {
                    log += "ERROR: Could not get main window automation element\n";
                    return;
                }

                SetForegroundWindow(hwnd);
                Thread.Sleep(1500);

                RECT winRect;
                GetWindowRect(hwnd, out winRect);
                log += "Main window bounds: (" + winRect.Left + ", " + winRect.Top + ", " + winRect.Right + ", " + winRect.Bottom + ")\n";

                // Step 1: Open Database Page
                log += "2. Clicking Database button on Home page...\n";
                var allButtons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
                AutomationElement dbBtn = null;
                foreach (AutomationElement btn in allButtons) {
                    Rect r = btn.Current.BoundingRectangle;
                    if (r.Y > winRect.Top + 100 && r.X > winRect.Left + 50 && r.X < winRect.Left + 350 && r.Width > 150) {
                        dbBtn = btn;
                        break;
                    }
                }
                if (dbBtn == null && allButtons.Count > 0) dbBtn = allButtons[0];
                if (dbBtn != null) {
                    Rect r = dbBtn.Current.BoundingRectangle;
                    PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(2000);
                }

                // Step 2: Double-click connection localhost
                log += "3. Double-clicking connection in tree...\n";
                var treeItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TreeItem));
                log += "Found " + treeItems.Count + " tree items\n";
                if (treeItems.Count > 0) {
                    Rect r = treeItems[0].Current.BoundingRectangle;
                    PhysicalDoubleClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(3000);
                }

                // Step 3: Expand database, expand Tables, and click table
                log += "4. Expanding database and tables...\n";
                var allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement targetDbNode = null;
                foreach (AutomationElement txt in allTexts) {
                    string name = txt.Current.Name ?? "";
                    if (name == "ngocthamcatalog" || name == "banggiada") {
                        targetDbNode = txt;
                        break;
                    }
                }
                if (targetDbNode != null) {
                    Rect r = targetDbNode.Current.BoundingRectangle;
                    log += "Expanding db node '" + targetDbNode.Current.Name + "' at (" + (int)(r.X + r.Width / 2) + ", " + (int)(r.Y + r.Height / 2) + ")\n";
                    PhysicalDoubleClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(2500);
                }

                allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                log += "All texts count after expanding db: " + allTexts.Count + "\n";
                for (int i = 0; i < allTexts.Count; i++) {
                    Rect r = allTexts[i].Current.BoundingRectangle;
                    if (r.X > winRect.Left && r.X < winRect.Left + 400) {
                        log += string.Format("Text {0}: '{1}' at ({2}, {3})\n", i, allTexts[i].Current.Name, (int)r.X, (int)r.Y);
                    }
                }
                // Double-click 'Các bảng' at (840, 786)
                log += "Expanding 'Các bảng' at (840, 786)...\n";
                PhysicalDoubleClick(840, 786);
                Thread.Sleep(3000);

                allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                log += "All texts count after expanding tables: " + allTexts.Count + "\n";
                AutomationElement targetTableNode = null;
                for (int i = 0; i < allTexts.Count; i++) {
                    Rect r = allTexts[i].Current.BoundingRectangle;
                    string name = allTexts[i].Current.Name ?? "";
                    if (r.X > winRect.Left && r.X < winRect.Left + 400 && r.Y > 776) {
                        log += string.Format("Table candidate {0}: '{1}' at ({2}, {3})\n", i, name, (int)r.X, (int)r.Y);
                        if (name.Contains("banggiada") || name.Contains("backup") || name.Contains("accessed") || targetTableNode == null) {
                            targetTableNode = allTexts[i];
                            if (name.Contains("backup")) break;
                        }
                    }
                }

                if (targetTableNode != null) {
                    Rect r = targetTableNode.Current.BoundingRectangle;
                    log += "Clicking table node '" + targetTableNode.Current.Name + "' at (" + (int)(r.X + r.Width / 2) + ", " + (int)(r.Y + r.Height / 2) + ")\n";
                    PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(3500);
                } else {
                    log += "WARNING: targetTableNode not found!\n";
                }

                string capTable = Path.Combine(artifactDir, "01_diagnose_table_active.png");
                CaptureWindow(hwnd, capTable);
                log += "Captured 01: Table active (" + capTable + ")\n";

                // Step 4: Close the TOP Database Tab (Tab 1 in ShellTabView)
                log += "5. Locating and closing TOP Database Tab in ShellTabView...\n";
                var allTabs = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                log += "Total TabItems found: " + allTabs.Count + "\n";
                AutomationElement topDbTab = null;
                for (int i = 0; i < allTabs.Count; i++) {
                    var tab = allTabs[i];
                    Rect r = tab.Current.BoundingRectangle;
                    log += string.Format("Tab {0}: Name='{1}', Rect=({2}, {3}, {4}, {5})\n", i, tab.Current.Name, r.X, r.Y, r.Width, r.Height);
                    // Top tab strip is at Y < winRect.Top + 45 and X > winRect.Left + 40
                    if (r.Y < winRect.Top + 45 && r.X > winRect.Left + 40) {
                        topDbTab = tab;
                        break;
                    }
                }

                if (topDbTab != null) {
                    Rect tabRect = topDbTab.Current.BoundingRectangle;
                    log += "Found TOP Database Tab: Name='" + topDbTab.Current.Name + "', Rect=(" + tabRect.X + ", " + tabRect.Y + ", " + tabRect.Width + ", " + tabRect.Height + ")\n";
                    // Hover over top tab
                    SetCursorPos((int)(tabRect.X + tabRect.Width / 2), (int)(tabRect.Y + tabRect.Height / 2));
                    Thread.Sleep(300);

                    var closeBtns = topDbTab.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
                    log += "Close buttons on TOP tab: " + closeBtns.Count + "\n";
                    if (closeBtns.Count > 0) {
                        Rect cbr = closeBtns[0].Current.BoundingRectangle;
                        log += "Clicking TOP tab close button at (" + (int)(cbr.X + cbr.Width / 2) + ", " + (int)(cbr.Y + cbr.Height / 2) + ")\n";
                        PhysicalLeftClick((int)(cbr.X + cbr.Width / 2), (int)(cbr.Y + cbr.Height / 2));
                    } else {
                        log += "Clicking TOP tab close position at (" + (int)(tabRect.X + tabRect.Width - 14) + ", " + (int)(tabRect.Y + tabRect.Height / 2) + ")\n";
                        PhysicalLeftClick((int)(tabRect.X + tabRect.Width - 14), (int)(tabRect.Y + tabRect.Height / 2));
                    }
                    Thread.Sleep(2500);
                } else {
                    log += "ERROR: Could not locate TOP Database Tab!\n";
                }

                string capClosed = Path.Combine(artifactDir, "02_diagnose_tab_closed.png");
                CaptureWindow(hwnd, capClosed);
                log += "Captured 02: Tab closed (" + capClosed + ")\n";

                // Step 5: Read diagnostics file
                if (File.Exists(logFile)) {
                    log += "\n--- LIFECYCLE LOG FILE OUTPUT ---\n" + File.ReadAllText(logFile) + "\n--------------------------------\n";
                } else {
                    log += "\n--- LIFECYCLE LOG FILE WAS NOT CREATED (NOTHING CALLED DISPOSE!) ---\n";
                }

                try { Process.GetProcessById(pid).Kill(); } catch {}

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

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Windows.Forms", "UIAutomationClient", "UIAutomationTypes", "WindowsBase", "System.Drawing"

$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\22f010de-611d-4d85-b016-e7e887f4bd9d"

$res = [DataViewLeakDiagnoser]::RunDiagnosis($exePath, $workingDir, $artifactDir)
Write-Output $res
