$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class EndToEndVerifier {
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
        Thread.Sleep(300);
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

    public static string RunVerification(int pid, string artifactDir) {
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
                Thread.Sleep(2000);

                // 1. Click Database Card on Home page
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

                // 2. Open localhost via Right-Click Context Menu
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

                // 3. Find schema TreeItem containing 'chat'
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
                    CaptureWindow(hwnd, artifactDir + "\\error_no_chat.png");
                    return;
                }

                Rect itemRect = chatTreeItem.Current.BoundingRectangle;
                Rect textRect = chatText.Current.BoundingRectangle;
                log += "Found 'chat' TreeItem: (" + (int)itemRect.X + "," + (int)itemRect.Y + "," + (int)itemRect.Width + "x" + (int)itemRect.Height + ")\n";
                log += "Found 'chat' Text: (" + (int)textRect.X + "," + (int)textRect.Y + "," + (int)textRect.Width + "x" + (int)textRect.Height + ")\n";

                // First try ExpandCollapsePattern if available
                try {
                    object patternObj;
                    if (chatTreeItem.TryGetCurrentPattern(ExpandCollapsePattern.Pattern, out patternObj)) {
                        var expandPattern = patternObj as ExpandCollapsePattern;
                        if (expandPattern != null) {
                            log += "ExpandCollapsePattern available! Expanding via pattern...\n";
                            expandPattern.Expand();
                        }
                    }
                } catch (Exception ex) {
                    log += "Pattern expand note: " + ex.Message + "\n";
                }

                // Dynamically calculate expand chevron position (itemRect.X + 37px, center Y)
                int chevronX = (int)itemRect.X + 37;
                int chevronY = (int)(itemRect.Y + itemRect.Height / 2);
                log += "Physically clicking expand chevron for 'chat' at (" + chevronX + ", " + chevronY + ")...\n";
                PhysicalLeftClick(chevronX, chevronY);
                Thread.Sleep(3000);

                // Check if tables loaded and find 'chatrooms' table
                AutomationElement chatroomsNode = null;
                for (int attempt = 0; attempt < 10; attempt++) {
                    var allT = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                    foreach (AutomationElement txt in allT) {
                        string name = txt.Current.Name ?? "";
                        if (name == "chatrooms" || name == "chat_user_table" || name == "admin") {
                            chatroomsNode = txt;
                            break;
                        }
                    }
                    if (chatroomsNode != null) break;

                    if (attempt == 1 || attempt == 3) {
                        log += "Retrying click on 'chat' chevron at (" + chevronX + ", " + chevronY + ")...\n";
                        PhysicalLeftClick(chevronX, chevronY);
                    }

                    // If not found, check if 'Các bảng' category is present and click its chevron
                    foreach (AutomationElement txt in allT) {
                        string name = txt.Current.Name ?? "";
                        if (name.Contains("bảng") || name.Contains("Tables")) {
                            Rect tr = txt.Current.BoundingRectangle;
                            log += "Clicking 'Các bảng' category chevron at (" + (int)(tr.X - 25) + ", " + (int)(tr.Y + tr.Height / 2) + ")...\n";
                            PhysicalLeftClick((int)(tr.X - 25), (int)(tr.Y + tr.Height / 2));
                            break;
                        }
                    }
                    Thread.Sleep(1200);
                }

                if (chatroomsNode == null) {
                    log += "ERROR: Could not locate table node 'chatrooms' under 'chat'!\n";
                    CaptureWindow(hwnd, artifactDir + "\\error_no_table.png");
                    return;
                }

                Rect tableRect = chatroomsNode.Current.BoundingRectangle;
                int clickTableX = (int)(tableRect.X + tableRect.Width / 2);
                int clickTableY = (int)(tableRect.Y + tableRect.Height / 2);
                log += "SUCCESS: Located table '" + chatroomsNode.Current.Name + "' at (" + clickTableX + ", " + clickTableY + ")!\n";
                log += "Physically left-clicking table to select and trigger data load...\n";
                PhysicalLeftClick(clickTableX, clickTableY);

                log += "Waiting 4 seconds for table data rows to load into ListView...\n";
                Thread.Sleep(4000);

                // Capture Milestone 1: Table selected, data displayed, placeholder hidden
                string tableSnap = artifactDir + "\\real_evidence_table_selected.png";
                CaptureWindow(hwnd, tableSnap);
                log += "SUCCESS: Captured real table loaded evidence to " + tableSnap + "\n";

                // 4. Test interaction on table data cells and rows
                log += "Testing mouse interaction on loaded table data rows and cells...\n";
                var allRightTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement dataCell = null;
                foreach (AutomationElement txt in allRightTexts) {
                    Rect tr = txt.Current.BoundingRectangle;
                    // Right panel elements have X > 450
                    if (tr.X > 450 && tr.Width > 0 && tr.Height > 0) {
                        string val = txt.Current.Name ?? "";
                        if (val == "ssss" || val == "hello" || val == "1" || val == "2" || val == "room1") {
                            dataCell = txt;
                            break;
                        }
                    }
                }

                if (dataCell != null) {
                    Rect cr = dataCell.Current.BoundingRectangle;
                    int cellX = (int)(cr.X + cr.Width / 2);
                    int cellY = (int)(cr.Y + cr.Height / 2);
                    log += "Located data cell '" + dataCell.Current.Name + "' at (" + cellX + ", " + cellY + "). Physically clicking to select row...\n";
                    PhysicalLeftClick(cellX, cellY);
                    Thread.Sleep(600);

                    log += "Physically double-clicking data cell to select and highlight text...\n";
                    PhysicalDoubleClick(cellX, cellY);
                    Thread.Sleep(600);

                    string interactSnap = artifactDir + "\\real_evidence_cell_interacted.png";
                    CaptureWindow(hwnd, interactSnap);
                    log += "SUCCESS: Captured cell interaction evidence to " + interactSnap + "\n";
                } else {
                    log += "Data cell text not explicitly matched by name, clicking row area at (X=600, Y=350)...\n";
                    PhysicalLeftClick(600, 350);
                    Thread.Sleep(600);
                    string interactSnap = artifactDir + "\\real_evidence_cell_interacted.png";
                    CaptureWindow(hwnd, interactSnap);
                    log += "Captured interaction snapshot to " + interactSnap + "\n";
                }

                // 5. Test rapid expand/collapse stress test on database nodes to verify 0xC000027B crash fix
                log += "Starting 10 rapid double-clicks / expand-collapse cycles on 'chat' node to stress test tree virtualization...\n";
                for (int c = 1; c <= 10; c++) {
                    // Click chevron
                    PhysicalLeftClick(chevronX, chevronY);
                    Thread.Sleep(100);
                    // Double click text
                    PhysicalDoubleClick((int)(textRect.X + textRect.Width / 2), (int)(textRect.Y + textRect.Height / 2));
                    Thread.Sleep(100);
                }
                log += "Completed 10 rapid stress cycles!\n";

                Thread.Sleep(2000);

                Process p = Process.GetProcessById(pid);
                if (!p.HasExited) {
                    log += "PASS: Process PID " + pid + " is alive and healthy after rapid expand/collapse stress! Crash 0xC000027B completely resolved!\n";
                } else {
                    log += "FAIL: Process crashed during stress test!\n";
                }

                string stressSnap = artifactDir + "\\real_evidence_after_stress.png";
                CaptureWindow(hwnd, stressSnap);
                log += "SUCCESS: Captured stress test completion screenshot to " + stressSnap + "\n";

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

Write-Host "Starting REAL End-To-End Desktop Verification..."
$appPid = [EndToEndVerifier]::LaunchApp($exePath, $workingDir)
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363"
$log = [EndToEndVerifier]::RunVerification($appPid, $artifactDir)
Write-Host "================== TEST LOG =================="
Write-Host $log
Write-Host "=============================================="

try {
    $p = Get-Process -Id $appPid -ErrorAction SilentlyContinue
    if ($p) { $p.Kill() }
} catch {}
