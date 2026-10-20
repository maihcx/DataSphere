$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class ScrollPatternTester {
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
        if (!success) throw new InvalidOperationException("CreateProcess failed");
        return pi.dwProcessId;
    }

    public static void PhysicalLeftClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(200);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(400);
    }

    public static void CaptureWindow(IntPtr hwnd, string filename) {
        RECT r;
        GetWindowRect(hwnd, out r);
        int w = r.Right - r.Left;
        int h = r.Bottom - r.Top;
        if (w <= 0 || h <= 0) return;
        using (Bitmap bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb)) {
            using (Graphics g = Graphics.FromImage(bmp)) {
                IntPtr hdc = g.GetHdc();
                try {
                    PrintWindow(hwnd, hdc, 2);
                } finally {
                    g.ReleaseHdc(hdc);
                }
            }
            bmp.Save(filename, ImageFormat.Png);
        }
    }

    public static string RunTest(int pid, string artifactDir) {
        string log = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) return;
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
                if (appWin == null) return;
                SetForegroundWindow(hwnd);
                Thread.Sleep(1500);

                // Right click localhost -> Connect
                var allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement connNode = null;
                foreach (AutomationElement txt in allTexts) {
                    if (txt.Current.Name == "localhost") {
                        connNode = txt;
                        break;
                    }
                }
                if (connNode == null) {
                    var allButtons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
                    foreach (AutomationElement btn in allButtons) {
                        Rect r = btn.Current.BoundingRectangle;
                        if (r.Width > 200 && r.Height > 60) {
                            PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                            Thread.Sleep(2000);
                            break;
                        }
                    }
                    allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                    foreach (AutomationElement txt in allTexts) {
                        if (txt.Current.Name == "localhost") {
                            connNode = txt;
                            break;
                        }
                    }
                }

                if (connNode != null) {
                    Rect r = connNode.Current.BoundingRectangle;
                    SetCursorPos((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(200);
                    mouse_event(0x0008, 0, 0, 0, 0); // Right down
                    Thread.Sleep(100);
                    mouse_event(0x0010, 0, 0, 0, 0); // Right up
                    Thread.Sleep(1000);

                    var allMenuItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.MenuItem));
                    if (allMenuItems.Count > 0) {
                        Rect mr = allMenuItems[0].Current.BoundingRectangle;
                        PhysicalLeftClick((int)(mr.X + mr.Width / 2), (int)(mr.Y + mr.Height / 2));
                    }
                }

                Thread.Sleep(4000);

                // Expand ngocthamcatalog
                var allTreeItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TreeItem));
                AutomationElement targetDbTreeItem = null;
                foreach (AutomationElement item in allTreeItems) {
                    var child = item.FindFirst(TreeScope.Descendants, new PropertyCondition(AutomationElement.NameProperty, "ngocthamcatalog"));
                    if (child != null) {
                        targetDbTreeItem = item;
                        break;
                    }
                }

                if (targetDbTreeItem == null) {
                    log += "ERROR: ngocthamcatalog not found\n";
                    return;
                }

                Rect dbRect = targetDbTreeItem.Current.BoundingRectangle;
                PhysicalLeftClick((int)dbRect.X + 37, (int)(dbRect.Y + dbRect.Height / 2));
                Thread.Sleep(2500);

                // Expand Các bảng
                var treeItemsAfter = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TreeItem));
                AutomationElement tablesCat = null;
                foreach (AutomationElement item in treeItemsAfter) {
                    var texts = item.FindAll(TreeScope.Children, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                    foreach (AutomationElement txt in texts) {
                        string name = txt.Current.Name ?? "";
                        if (name.IndexOf("b\u1EA3ng", StringComparison.OrdinalIgnoreCase) >= 0 ||
                            name.IndexOf("Tables", StringComparison.OrdinalIgnoreCase) >= 0 ||
                            name.IndexOf("b?ng", StringComparison.OrdinalIgnoreCase) >= 0) {
                            tablesCat = item;
                            break;
                        }
                    }
                    if (tablesCat != null) break;
                }

                if (tablesCat == null) {
                    log += "ERROR: Các bảng not found\n";
                    return;
                }

                Rect catRect = tablesCat.Current.BoundingRectangle;
                var catTextChild = tablesCat.FindFirst(TreeScope.Children, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                int catChevronX = (int)catRect.X + 37;
                if (catTextChild != null) catChevronX = (int)catTextChild.Current.BoundingRectangle.X - 43;
                PhysicalLeftClick(catChevronX, (int)(catRect.Y + catRect.Height / 2));
                Thread.Sleep(3000);

                // Click admin table
                AutomationElement adminNode = null;
                var allT = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                foreach (AutomationElement txt in allT) {
                    if (txt.Current.Name == "admin") {
                        adminNode = txt;
                        break;
                    }
                }

                if (adminNode == null) {
                    log += "ERROR: admin table node not found\n";
                    return;
                }

                Rect adminRect = adminNode.Current.BoundingRectangle;
                PhysicalLeftClick((int)(adminRect.X + adminRect.Width / 2), (int)(adminRect.Y + adminRect.Height / 2));
                Thread.Sleep(1000);
                PhysicalLeftClick((int)(adminRect.X + adminRect.Width / 2), (int)(adminRect.Y + adminRect.Height / 2));
                Thread.Sleep(4000);

                // Check List control & ScrollPattern
                var allLists = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.List));
                log += "Lists found: " + allLists.Count + "\n";
                foreach (AutomationElement l in allLists) {
                    Rect lr = l.Current.BoundingRectangle;
                    log += string.Format("List: rect=({0},{1},{2}x{3})\n", (int)lr.X, (int)lr.Y, (int)lr.Width, (int)lr.Height);
                    object patternObj;
                    if (l.TryGetCurrentPattern(ScrollPattern.Pattern, out patternObj)) {
                        var sp = patternObj as ScrollPattern;
                        if (sp != null) {
                            log += string.Format("  ScrollPattern: HorizScrollable={0}, HorizPercent={1:F1}%, VertScrollable={2}, VertPercent={3:F1}%\n",
                                sp.Current.HorizontallyScrollable, sp.Current.HorizontalScrollPercent,
                                sp.Current.VerticallyScrollable, sp.Current.VerticalScrollPercent);
                            
                            // Test Vertical Scroll!
                            log += "  Testing Vertical Scroll down via ScrollPattern...\n";
                            sp.Scroll(ScrollAmount.NoAmount, ScrollAmount.SmallIncrement);
                            Thread.Sleep(1000);
                            log += string.Format("  VertPercent after scroll: {0:F1}%\n", sp.Current.VerticalScrollPercent);

                            // Test Horizontal Scroll!
                            log += "  Testing Horizontal Scroll right via ScrollPattern...\n";
                            sp.Scroll(ScrollAmount.SmallIncrement, ScrollAmount.NoAmount);
                            Thread.Sleep(1000);
                            log += string.Format("  HorizPercent after scroll: {0:F1}%\n", sp.Current.HorizontalScrollPercent);
                        }
                    }
                }

                // Check all child elements inside List
                if (allLists.Count > 0) {
                    var listChildren = allLists[0].FindAll(TreeScope.Children, Condition.TrueCondition);
                    log += "List direct children: " + listChildren.Count + "\n";
                    var scrollBarsInside = allLists[0].FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ScrollBar));
                    log += "ScrollBars inside List: " + scrollBarsInside.Count + "\n";
                    foreach (AutomationElement sb in scrollBarsInside) {
                        Rect sbr = sb.Current.BoundingRectangle;
                        log += string.Format("  ScrollBar: Name='{0}', rect=({1},{2},{3}x{4})\n",
                            sb.Current.Name, (int)sbr.X, (int)sbr.Y, (int)sbr.Width, (int)sbr.Height);
                    }
                }

                RECT winRect;
                GetWindowRect(hwnd, out winRect);
                CaptureWindow(hwnd, artifactDir + "\\bug_scrollbar_tested_clean.png");
                log += "Captured bug_scrollbar_tested_clean.png\n";

            } catch (Exception ex) {
                log += "Exception: " + ex.ToString() + "\n";
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

$appPid = [ScrollPatternTester]::LaunchApp($exePath, $workingDir)
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363"
$log = [ScrollPatternTester]::RunTest($appPid, $artifactDir)
Write-Host "================== TEST LOG =================="
Write-Host $log
Write-Host "=============================================="

try {
    $p = Get-Process -Id $appPid -ErrorAction SilentlyContinue
    if ($p) { $p.Kill() }
} catch {}
