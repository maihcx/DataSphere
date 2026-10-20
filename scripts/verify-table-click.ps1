$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class TableClickVerifier {
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
        if (!success) {
            int err = Marshal.GetLastWin32Error();
            throw new InvalidOperationException("CreateProcess on WinSta0\\default failed: " + err);
        }
        return pi.dwProcessId;
    }

    public static void PhysicalClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(200);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(80);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(300);
    }

    public static void PhysicalDoubleClick(int x, int y) {
        PhysicalClick(x, y);
        Thread.Sleep(80);
        PhysicalClick(x, y);
    }

    public static string ExecuteVerification(int pid, string screenshotPath) {
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
                        break;
                    }
                }

                if (appWin == null) return;
                SetForegroundWindow(hwnd);
                Thread.Sleep(1500);

                // 1. Click Database Card
                var allButtons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
                AutomationElement dbBtn = null;
                foreach (AutomationElement btn in allButtons) {
                    Rect r = btn.Current.BoundingRectangle;
                    if (r.Width > 200 && r.Height > 60) {
                        if (dbBtn == null || r.X < dbBtn.Current.BoundingRectangle.X) dbBtn = btn;
                    }
                }
                if (dbBtn != null) {
                    Rect rect = dbBtn.Current.BoundingRectangle;
                    PhysicalClick((int)(rect.X + rect.Width / 2), (int)(rect.Y + rect.Height / 2));
                }

                Thread.Sleep(2500);

                // 2. Double-click localhost in ConnectionsTree
                var allText = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement connTextEl = null;
                foreach (AutomationElement txt in allText) {
                    string name = txt.Current.Name ?? "";
                    if (name.Contains("localhost") || name.Contains("MySQL") || name.Contains("Local")) {
                        connTextEl = txt;
                        break;
                    }
                }
                if (connTextEl != null) {
                    Rect rect = connTextEl.Current.BoundingRectangle;
                    PhysicalDoubleClick((int)(rect.X + rect.Width / 2), (int)(rect.Y + rect.Height / 2));
                } else {
                    var treeItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TreeItem));
                    if (treeItems.Count > 0) {
                        Rect rect = treeItems[0].Current.BoundingRectangle;
                        PhysicalDoubleClick((int)(rect.X + rect.Width / 2), (int)(rect.Y + rect.Height / 2));
                    }
                }

                Thread.Sleep(3500);

                // 3. Find the text 'chat' in the SchemaTree
                var textNodes = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                AutomationElement chatNode = null;
                foreach (AutomationElement txt in textNodes) {
                    if (txt.Current.Name == "chat") {
                        chatNode = txt;
                        break;
                    }
                }

                if (chatNode != null) {
                    Rect r = chatNode.Current.BoundingRectangle;
                    log += "Found 'chat' node at (" + (int)r.X + "," + (int)r.Y + "). Double-clicking to expand...\n";
                    PhysicalDoubleClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    Thread.Sleep(2000);

                    // 4. Find 'Các bảng'
                    var textNodes2 = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                    AutomationElement tablesNode = null;
                    foreach (AutomationElement txt in textNodes2) {
                        string n = txt.Current.Name ?? "";
                        if (n.Contains("bảng") || n.Contains("Tables")) {
                            tablesNode = txt;
                            break;
                        }
                    }

                    if (tablesNode != null) {
                        Rect r2 = tablesNode.Current.BoundingRectangle;
                        log += "Found 'Các bảng' node at (" + (int)r2.X + "," + (int)r2.Y + "). Double-clicking to expand...\n";
                        PhysicalDoubleClick((int)(r2.X + r2.Width / 2), (int)(r2.Y + r2.Height / 2));
                        Thread.Sleep(2000);

                        // 5. Find 'chatrooms'
                        var textNodes3 = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                        AutomationElement tableItem = null;
                        foreach (AutomationElement txt in textNodes3) {
                            string n = txt.Current.Name ?? "";
                            if (n == "chatrooms" || n == "chat_user_table" || n == "admin") {
                                tableItem = txt;
                                break;
                            }
                        }

                        if (tableItem != null) {
                            Rect r3 = tableItem.Current.BoundingRectangle;
                            log += "Found table item '" + tableItem.Current.Name + "' at (" + (int)r3.X + "," + (int)r3.Y + "). Clicking to select...\n";
                            PhysicalClick((int)(r3.X + r3.Width / 2), (int)(r3.Y + r3.Height / 2));
                            Thread.Sleep(3000);

                            // 6. Click inside a data cell to verify cell / row selection
                            RECT winR2;
                            GetWindowRect(hwnd, out winR2);
                            // Table data area starts around X = winR2.Left + 350, Y = winR2.Top + 240
                            int cellX = winR2.Left + 400;
                            int cellY = winR2.Top + 240;
                            log += "Clicking table data cell at (" + cellX + ", " + cellY + ")...\n";
                            PhysicalClick(cellX, cellY);
                            Thread.Sleep(1000);
                        } else {
                            log += "Table item not found in expanded tables.\n";
                        }
                    } else {
                        log += "'Các bảng' node not found.\n";
                    }
                } else {
                    log += "'chat' database node not found.\n";
                }

                // 7. Capture visual evidence of the running UI
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
                        bmp.Save(screenshotPath, ImageFormat.Png);
                    }
                    log += "SUCCESS: Captured visual evidence to " + screenshotPath + " (" + w + "x" + h + ")\n";
                }

                Thread.Sleep(1000);
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

Write-Host "Starting Real Desktop Table Click Verification..."
$appPid = [TableClickVerifier]::LaunchApp($exePath, $workingDir)

$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363"
$snapPath = "$artifactDir\verification_table_selected.png"

$log = [TableClickVerifier]::ExecuteVerification($appPid, $snapPath)
Write-Host "================== TEST LOG =================="
Write-Host $log
Write-Host "=============================================="

# Terminate test process
try {
    $p = Get-Process -Id $appPid -ErrorAction SilentlyContinue
    if ($p) {
        Write-Host "Terminating test instance (PID: $appPid)..."
        $p.Kill()
    }
} catch {}
