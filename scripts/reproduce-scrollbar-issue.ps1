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

public class ScrollbarReproducer {
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
        Thread.Sleep(300);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(600);
    }

    public static void PhysicalRightClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(300);
        mouse_event(MOUSEEVENTF_RIGHTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_RIGHTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(600);
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
                    PrintWindow(hwnd, hdc, 2); // PW_RENDERFULLCONTENT
                } finally {
                    g.ReleaseHdc(hdc);
                }
            }
            bmp.Save(filename, ImageFormat.Png);
        }
    }

    public static string Reproduce(int pid, string artifactDir) {
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
                        log += "Found DataSphere window (HWND=" + hwnd + ")\n";
                        break;
                    }
                }

                if (appWin == null) {
                    log += "ERROR: Window not found\n";
                    return;
                }

                SetForegroundWindow(hwnd);
                Thread.Sleep(1500);

                // 1. Locate localhost connection
                var allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement connNode = null;
                foreach (AutomationElement txt in allTexts) {
                    if (txt.Current.Name == "localhost") {
                        connNode = txt;
                        break;
                    }
                }

                if (connNode == null) {
                    var btnCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button);
                    var allButtons = appWin.FindAll(TreeScope.Descendants, btnCond);
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
                    int cx = (int)(r.X + r.Width / 2);
                    int cy = (int)(r.Y + r.Height / 2);
                    log += "Right-clicking 'localhost' at (" + cx + ", " + cy + ")...\n";
                    PhysicalRightClick(cx, cy);
                    Thread.Sleep(1000);

                    var allMenuItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.MenuItem));
                    if (allMenuItems.Count > 0) {
                        Rect mr = allMenuItems[0].Current.BoundingRectangle;
                        log += "Clicking MenuItem '" + allMenuItems[0].Current.Name + "' at (" + (int)(mr.X + mr.Width / 2) + ", " + (int)(mr.Y + mr.Height / 2) + ")...\n";
                        PhysicalLeftClick((int)(mr.X + mr.Width / 2), (int)(mr.Y + mr.Height / 2));
                    }
                }

                log += "Waiting 4 seconds for localhost tab to connect...\n";
                Thread.Sleep(4000);

                // 2. Locate 'ngocthamcatalog' database
                AutomationElement targetDbTreeItem = null;
                var allTreeItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TreeItem));
                log += "Scanning " + allTreeItems.Count + " TreeItems in appWin...\n";
                foreach (AutomationElement item in allTreeItems) {
                    var child = item.FindFirst(TreeScope.Descendants, new PropertyCondition(AutomationElement.NameProperty, "ngocthamcatalog"));
                    if (child != null) {
                        targetDbTreeItem = item;
                        break;
                    }
                }

                if (targetDbTreeItem == null) {
                    log += "ERROR: 'ngocthamcatalog' TreeItem not found!\n";
                    return;
                }

                Rect dbRect = targetDbTreeItem.Current.BoundingRectangle;
                log += string.Format("Found 'ngocthamcatalog' TreeItem at ({0},{1},{2}x{3})\n",
                    (int)dbRect.X, (int)dbRect.Y, (int)dbRect.Width, (int)dbRect.Height);

                // Try ExpandCollapsePattern first
                try {
                    object patternObj;
                    if (targetDbTreeItem.TryGetCurrentPattern(ExpandCollapsePattern.Pattern, out patternObj)) {
                        var expandPattern = patternObj as ExpandCollapsePattern;
                        if (expandPattern != null) {
                            log += "ExpandCollapsePattern expanding 'ngocthamcatalog'...\n";
                            expandPattern.Expand();
                        }
                    }
                } catch (Exception ex) {
                    log += "Pattern note: " + ex.Message + "\n";
                }

                // Also click chevron (itemRect.X + 37)
                int dbChevronX = (int)dbRect.X + 37;
                int dbChevronY = (int)(dbRect.Y + dbRect.Height / 2);
                log += "Clicking chevron for ngocthamcatalog at (" + dbChevronX + ", " + dbChevronY + ")...\n";
                PhysicalLeftClick(dbChevronX, dbChevronY);
                Thread.Sleep(2500);

                // 3. Locate 'Các bảng' under ngocthamcatalog
                AutomationElement tablesCatTreeItem = null;
                for (int attempt = 0; attempt < 5; attempt++) {
                    var treeItemsAfter = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TreeItem));
                    foreach (AutomationElement item in treeItemsAfter) {
                        var texts = item.FindAll(TreeScope.Children, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                        foreach (AutomationElement txt in texts) {
                            string name = txt.Current.Name ?? "";
                            if (name.IndexOf("b\u1EA3ng", StringComparison.OrdinalIgnoreCase) >= 0 ||
                                name.IndexOf("Tables", StringComparison.OrdinalIgnoreCase) >= 0 ||
                                name.IndexOf("b?ng", StringComparison.OrdinalIgnoreCase) >= 0) {
                                tablesCatTreeItem = item;
                                break;
                            }
                        }
                        if (tablesCatTreeItem != null) break;
                    }
                    if (tablesCatTreeItem != null) break;
                    log += "Retrying click on ngocthamcatalog chevron...\n";
                    PhysicalLeftClick(dbChevronX, dbChevronY);
                    Thread.Sleep(1500);
                }

                if (tablesCatTreeItem == null) {
                    log += "ERROR: 'Các bảng' node not found under 'ngocthamcatalog'!\n";
                    return;
                }

                Rect catRect = tablesCatTreeItem.Current.BoundingRectangle;
                log += string.Format("Found 'Các bảng' at ({0},{1},{2}x{3})\n",
                    (int)catRect.X, (int)catRect.Y, (int)catRect.Width, (int)catRect.Height);

                // Single click to expand 'Các bảng' (the chevron is at catRect.X + 37 or 57)
                // Let's try ExpandCollapsePattern or chevron click
                try {
                    object patternObj;
                    if (tablesCatTreeItem.TryGetCurrentPattern(ExpandCollapsePattern.Pattern, out patternObj)) {
                        var expandPattern = patternObj as ExpandCollapsePattern;
                        if (expandPattern != null) {
                            log += "ExpandCollapsePattern expanding 'Các bảng'...\n";
                            expandPattern.Expand();
                        }
                    }
                } catch (Exception ex) {
                    log += "Pattern note: " + ex.Message + "\n";
                }

                // In verify-ring-fix.ps1:
                // AutomationElement tablesCatElement was the Text element, and catChevronX was catRect.X - 43.
                // Let's find the text child inside tablesCatTreeItem
                var catTextChild = tablesCatTreeItem.FindFirst(TreeScope.Children, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                int catChevronX = (int)catRect.X + 37;
                if (catTextChild != null) {
                    Rect tr = catTextChild.Current.BoundingRectangle;
                    catChevronX = (int)tr.X - 43;
                }
                int catChevronY = (int)(catRect.Y + catRect.Height / 2);
                log += "Clicking chevron for 'Các bảng' at (" + catChevronX + ", " + catChevronY + ")...\n";
                PhysicalLeftClick(catChevronX, catChevronY);
                Thread.Sleep(3500);

                // 4. Locate 'admin' table
                AutomationElement adminTableNode = null;
                for (int attempt = 0; attempt < 3; attempt++) {
                    var allT = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                    foreach (AutomationElement txt in allT) {
                        if (txt.Current.Name == "admin") {
                            adminTableNode = txt;
                            break;
                        }
                    }
                    if (adminTableNode != null) break;
                    Thread.Sleep(1000);
                }

                if (adminTableNode == null) {
                    log += "ERROR: 'admin' table not found under 'ngocthamcatalog'!\n";
                    return;
                }

                Rect adminRect = adminTableNode.Current.BoundingRectangle;
                log += "Found 'admin' table at (" + (int)adminRect.X + "," + (int)adminRect.Y + ")\n";
                PhysicalLeftClick((int)(adminRect.X + adminRect.Width / 2), (int)(adminRect.Y + adminRect.Height / 2));

                log += "Waiting 4 seconds for admin table rows (399 items) to load...\n";
                Thread.Sleep(4000);

                // 5. Capture Initial Viewport Screenshot
                string snapInitial = artifactDir + "\\bug_scrollbar_reproduction_initial.png";
                CaptureWindow(hwnd, snapInitial);
                log += "Captured initial viewport: " + snapInitial + "\n";

                // 6. Diagnose Scrollbars and Viewport Geometry
                var allScrollBars = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ScrollBar));
                log += "Found " + allScrollBars.Count + " ScrollBar elements in DataSphere:\n";
                AutomationElement horizScrollBar = null;
                AutomationElement vertScrollBar = null;

                foreach (AutomationElement sb in allScrollBars) {
                    Rect sbr = sb.Current.BoundingRectangle;
                    string orient = "Unknown";
                    try {
                        orient = sb.Current.Orientation.ToString();
                    } catch {}
                    log += string.Format("  - ScrollBar [{0}]: pos=({1},{2}), size=({3}x{4}), name='{5}'\n",
                        orient, (int)sbr.X, (int)sbr.Y, (int)sbr.Width, (int)sbr.Height, sb.Current.Name);
                    
                    if (sbr.Width > sbr.Height && sbr.Width > 200) {
                        horizScrollBar = sb;
                    } else if (sbr.Height > sbr.Width && sbr.Height > 100) {
                        vertScrollBar = sb;
                    }
                }

                RECT winRect;
                GetWindowRect(hwnd, out winRect);
                log += string.Format("Window Rect: ({0},{1}) to ({2},{3}), Width={4}\n",
                    winRect.Left, winRect.Top, winRect.Right, winRect.Bottom, winRect.Right - winRect.Left);

                if (vertScrollBar != null) {
                    Rect vr = vertScrollBar.Current.BoundingRectangle;
                    log += string.Format("Vertical ScrollBar position: X={0}, Y={1}, RightEdge={2}. Window RightEdge={3}. Is Offscreen/Clipped? {4}\n",
                        vr.X, vr.Y, vr.X + vr.Width, winRect.Right, (vr.X > winRect.Right ? "YES (Off-screen)" : "NO"));
                } else {
                    log += "WARNING: No vertical ScrollBar found in visual tree!\n";
                }

                // 7. Scroll horizontally to the right if horizontal scrollbar exists
                if (horizScrollBar != null) {
                    Rect hr = horizScrollBar.Current.BoundingRectangle;
                    // Click near right edge of horizontal scrollbar track
                    int clickTrackX = (int)(hr.X + hr.Width - 40);
                    int clickTrackY = (int)(hr.Y + hr.Height / 2);
                    log += string.Format("Clicking horizontal scrollbar track near right edge ({0}, {1}) to scroll right...\n", clickTrackX, clickTrackY);
                    PhysicalLeftClick(clickTrackX, clickTrackY);
                    Thread.Sleep(1000);
                    PhysicalLeftClick(clickTrackX, clickTrackY);
                    Thread.Sleep(1000);

                    string snapScrolled = artifactDir + "\\bug_scrollbar_reproduction_scrolled.png";
                    CaptureWindow(hwnd, snapScrolled);
                    log += "Captured scrolled viewport: " + snapScrolled + "\n";
                }

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

Write-Host "Running Scrollbar Reproduction on WinSta0\default..."
$appPid = [ScrollbarReproducer]::LaunchApp($exePath, $workingDir)
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363"
$log = [ScrollbarReproducer]::Reproduce($appPid, $artifactDir)
Write-Host "================== REPRODUCTION LOG =================="
Write-Host $log
Write-Host "======================================================"

try {
    $p = Get-Process -Id $appPid -ErrorAction SilentlyContinue
    if ($p) { $p.Kill() }
} catch {}
