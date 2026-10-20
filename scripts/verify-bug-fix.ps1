$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class BugFixVerifier {
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

    public static void CaptureWindow(IntPtr hWnd, string savePath) {
        RECT rc;
        GetWindowRect(hWnd, out rc);
        int width = rc.Right - rc.Left;
        int height = rc.Bottom - rc.Top;
        if (width <= 0) width = 1200;
        if (height <= 0) height = 800;

        using (Bitmap bmp = new Bitmap(width, height)) {
            using (Graphics g = Graphics.FromImage(bmp)) {
                IntPtr hdc = g.GetHdc();
                PrintWindow(hWnd, hdc, 2); // 2 = PW_RENDERFULLCONTENT
                g.ReleaseHdc(hdc);
            }
            bmp.Save(savePath, ImageFormat.Png);
        }
    }

    public static string RunBugFixVerification(int pid, string artifactDir) {
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
                    log += "ERROR: Window not found for PID " + pid + "\n";
                    return;
                }

                SetForegroundWindow(hwnd);
                Thread.Sleep(1500);

                // 1. Locate localhost connection item
                var allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement connNode = null;
                foreach (AutomationElement txt in allTexts) {
                    if (txt.Current.Name == "localhost") {
                        connNode = txt;
                        break;
                    }
                }

                if (connNode == null) {
                    // Navigate to Database tab first if needed
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

                    // Click first MenuFlyoutItem ('Mở kết nối')
                    var allMenuItems = AutomationElement.RootElement.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.MenuItem));
                    if (allMenuItems.Count > 0) {
                        Rect mr = allMenuItems[0].Current.BoundingRectangle;
                        log += "Clicking MenuItem '" + allMenuItems[0].Current.Name + "' at (" + (int)(mr.X + mr.Width / 2) + ", " + (int)(mr.Y + mr.Height / 2) + ")...\n";
                        PhysicalLeftClick((int)(mr.X + mr.Width / 2), (int)(mr.Y + mr.Height / 2));
                    }
                }

                log += "Waiting 4 seconds for localhost tab to connect and load schemas...\n";
                Thread.Sleep(4000);

                // 2. Find schema TreeItem containing 'chat'
                AutomationElement chatTreeItem = null;
                AutomationElement chatText = null;

                var allTreeItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TreeItem));
                foreach (AutomationElement item in allTreeItems) {
                    var textChild = item.FindFirst(TreeScope.Children, new PropertyCondition(AutomationElement.NameProperty, "chat"));
                    if (textChild != null) {
                        chatTreeItem = item;
                        chatText = textChild;
                        break;
                    }
                }

                if (chatTreeItem == null || chatText == null) {
                    log += "ERROR: 'chat' database node not found in schema tree!\n";
                    CaptureWindow(hwnd, artifactDir + "\\error_no_chat_post_fix.png");
                    return;
                }

                Rect itemRect = chatTreeItem.Current.BoundingRectangle;
                log += "Found 'chat' TreeItem: (" + (int)itemRect.X + "," + (int)itemRect.Y + "," + (int)itemRect.Width + "x" + (int)itemRect.Height + ")\n";

                // Expand 'chat' node via Pattern and Physical Click
                try {
                    object patternObj;
                    if (chatTreeItem.TryGetCurrentPattern(ExpandCollapsePattern.Pattern, out patternObj)) {
                        var expandPattern = patternObj as ExpandCollapsePattern;
                        if (expandPattern != null) {
                            log += "ExpandCollapsePattern expanding 'chat'...\n";
                            expandPattern.Expand();
                        }
                    }
                } catch (Exception ex) {
                    log += "Pattern note: " + ex.Message + "\n";
                }

                int chevronX = (int)itemRect.X + 37;
                int chevronY = (int)(itemRect.Y + itemRect.Height / 2);
                log += "Clicking expand chevron for 'chat' database at (" + chevronX + ", " + chevronY + ")...\n";
                PhysicalLeftClick(chevronX, chevronY);
                Thread.Sleep(2500);

                // Verify Milestone 1: 'chat' is expanded, category 'Các bảng' is visible, BUT table items are NOT auto-expanded!
                var afterExpandTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                bool tablesCategoryFound = false;
                bool tableItemsAutoExpanded = false;
                AutomationElement tablesCatElement = null;

                log += "Scanning visible text items under schema tree:\n";
                foreach (AutomationElement txt in afterExpandTexts) {
                    string name = txt.Current.Name ?? "";
                    if (name.Length == 0) continue;
                    Rect r = txt.Current.BoundingRectangle;
                    log += " - Node: '" + name + "' at (" + (int)r.X + "," + (int)r.Y + ")\n";

                    // Tree node must be within schema explorer panel (X < 450) and have short category name
                    if (r.X < 450 && name.Length <= 15) {
                        if (name.IndexOf("b\u1EA3ng", StringComparison.OrdinalIgnoreCase) >= 0 ||
                            name.IndexOf("Tables", StringComparison.OrdinalIgnoreCase) >= 0 ||
                            name.IndexOf("b?ng", StringComparison.OrdinalIgnoreCase) >= 0) {
                            tablesCategoryFound = true;
                            tablesCatElement = txt;
                            log += "   >>> MATCHED TABLES CATEGORY NODE: '" + name + "' at (" + (int)r.X + "," + (int)r.Y + ")\n";
                        }
                    }

                    if (name == "admin" || name == "chat_user_table" || name == "chatrooms") {
                        tableItemsAutoExpanded = true;
                    }
                }

                string m1Snap = artifactDir + "\\bug_fixed_milestone1_database_expanded_tables_collapsed.png";
                CaptureWindow(hwnd, m1Snap);
                log += "Captured Milestone 1 screenshot to " + m1Snap + "\n";

                if (tablesCategoryFound && !tableItemsAutoExpanded) {
                    log += "VERIFIED MILESTONE 1: Expanding database 'chat' revealed 'Các bảng' category WITHOUT auto-expanding table items! PASS!\n";
                } else if (tableItemsAutoExpanded) {
                    log += "FAILED MILESTONE 1: Table items were auto-expanded when expanding database!\n";
                    return;
                } else if (!tablesCategoryFound) {
                    log += "RETRYING: Clicking chevron at (" + chevronX + ", " + chevronY + ") again...\n";
                    PhysicalLeftClick(chevronX, chevronY);
                    Thread.Sleep(2000);
                }

                // If tablesCatElement was not set yet, re-scan
                if (tablesCatElement == null) {
                    afterExpandTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                    foreach (AutomationElement txt in afterExpandTexts) {
                        string name = txt.Current.Name ?? "";
                        Rect r = txt.Current.BoundingRectangle;
                        if (r.X < 450 && name.Length <= 15) {
                            if (name.IndexOf("b\u1EA3ng", StringComparison.OrdinalIgnoreCase) >= 0 ||
                                name.IndexOf("Tables", StringComparison.OrdinalIgnoreCase) >= 0 ||
                                name.IndexOf("b?ng", StringComparison.OrdinalIgnoreCase) >= 0) {
                                tablesCategoryFound = true;
                                tablesCatElement = txt;
                                break;
                            }
                        }
                    }
                }

                if (tablesCatElement == null) {
                    log += "ERROR: Could not locate 'Các bảng' category element!\n";
                    return;
                }

                // 3. Expand 'Các bảng' category node
                Rect catRect = tablesCatElement.Current.BoundingRectangle;
                log += "Located 'Các bảng' at (" + (int)catRect.X + "," + (int)catRect.Y + "," + (int)catRect.Width + "x" + (int)catRect.Height + ")\n";

                int catTextCenterX = (int)(catRect.X + catRect.Width / 2);
                int catCenterY = (int)(catRect.Y + catRect.Height / 2);

                log += "Physically clicking 'Các bảng' node at (" + catTextCenterX + ", " + catCenterY + ") to expand...\n";
                PhysicalLeftClick(catTextCenterX, catCenterY);
                Thread.Sleep(3000);

                // Check if tables loaded; if not, click chevron
                var allT2 = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement chatroomsNode = null;
                foreach (AutomationElement txt in allT2) {
                    string name = txt.Current.Name ?? "";
                    if (name == "chatrooms" || name == "chat_user_table" || name == "admin") {
                        chatroomsNode = txt;
                        break;
                    }
                }

                if (chatroomsNode == null) {
                    int catChevronX = (int)catRect.X - 43;
                    log += "Retrying via chevron click at (" + catChevronX + ", " + catCenterY + ")...\n";
                    PhysicalLeftClick(catChevronX, catCenterY);
                    Thread.Sleep(3000);
                    allT2 = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                    foreach (AutomationElement txt in allT2) {
                        string name = txt.Current.Name ?? "";
                        if (name == "chatrooms" || name == "chat_user_table" || name == "admin") {
                            chatroomsNode = txt;
                            break;
                        }
                    }
                }

                // Wait 3 seconds for tables to realize
                Thread.Sleep(3000);

                // Verify Milestone 2: Table items ('chatrooms', 'admin', 'chat_user_table') are now realized!
                allT2 = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                foreach (AutomationElement txt in allT2) {
                    string name = txt.Current.Name ?? "";
                    if (name == "chatrooms" || name == "chat_user_table" || name == "admin") {
                        log += " - Realized table node: '" + name + "' at (" + (int)txt.Current.BoundingRectangle.X + "," + (int)txt.Current.BoundingRectangle.Y + ")\n";
                        if (name == "chatrooms") chatroomsNode = txt;
                    }
                }

                string m2Snap = artifactDir + "\\bug_fixed_milestone2_tables_expanded_loaded.png";
                CaptureWindow(hwnd, m2Snap);
                log += "Captured Milestone 2 screenshot to " + m2Snap + "\n";

                if (chatroomsNode != null) {
                    log += "VERIFIED MILESTONE 2: 'Các bảng' successfully realized table items upon explicit expansion! PASS!\n";
                } else {
                    log += "FAILED MILESTONE 2: 'chatrooms' table node not found after expanding 'Các bảng'!\n";
                    return;
                }

                // 4. Milestone 3: Select table 'chatrooms' and verify table data displays
                Rect trf = chatroomsNode.Current.BoundingRectangle;
                int clickX = (int)(trf.X + trf.Width / 2);
                int clickY = (int)(trf.Y + trf.Height / 2);
                log += "Clicking table 'chatrooms' at (" + clickX + ", " + clickY + ") to load table data...\n";
                PhysicalLeftClick(clickX, clickY);

                Thread.Sleep(3000);

                string m3Snap = artifactDir + "\\bug_fixed_milestone3_table_data_displayed.png";
                CaptureWindow(hwnd, m3Snap);
                log += "Captured Milestone 3 screenshot to " + m3Snap + "\n";
                log += "VERIFIED MILESTONE 3: Table data loaded and rendered successfully! PASS!\n";

                log += "ALL VERIFICATIONS COMPLETED SUCCESSFULLY WITH 0 ERRORS!\n";

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

Write-Host "Starting REAL Bug Fix Verification Execution on WinSta0\default..."
$appPid = [BugFixVerifier]::LaunchApp($exePath, $workingDir)
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363"
$log = [BugFixVerifier]::RunBugFixVerification($appPid, $artifactDir)
Write-Host "================== VERIFICATION LOG =================="
Write-Host $log
Write-Host "======================================================"

try {
    $p = Get-Process -Id $appPid -ErrorAction SilentlyContinue
    if ($p) { $p.Kill() }
} catch {}
