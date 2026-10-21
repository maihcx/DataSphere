$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class DatabaseTabVerifier {
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

    public static void PhysicalLeftClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(120);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(80);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(300);
    }

    public static void CaptureWindow(IntPtr hWnd, string savePath) {
        RECT rc;
        GetWindowRect(hWnd, out rc);
        int width = rc.Right - rc.Left;
        int height = rc.Bottom - rc.Top;
        if (width <= 0 || height <= 0) return;

        using (Bitmap bmp = new Bitmap(width, height)) {
            using (Graphics g = Graphics.FromImage(bmp)) {
                IntPtr hdc = g.GetHdc();
                try {
                    PrintWindow(hWnd, hdc, 2); // PW_RENDERFULLCONTENT = 2
                } finally {
                    g.ReleaseHdc(hdc);
                }
            }
            bmp.Save(savePath, ImageFormat.Png);
        }
    }

    public static bool Verify(string exePath, string workingDir, string artifactDir) {
        bool allPassed = true;
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) {
                Console.WriteLine("Failed to open desktop!");
                allPassed = false;
                return;
            }
            SetThreadDesktop(hDesk);

            STARTUPINFO si = new STARTUPINFO();
            si.cb = Marshal.SizeOf(si);
            si.lpDesktop = @"WinSta0\default";
            PROCESS_INFORMATION pi = new PROCESS_INFORMATION();

            bool ok = CreateProcess(exePath, null, IntPtr.Zero, IntPtr.Zero, false, 0, IntPtr.Zero, workingDir, ref si, out pi);
            if (!ok) {
                Console.WriteLine("CreateProcess failed: " + Marshal.GetLastWin32Error());
                allPassed = false;
                return;
            }

            Console.WriteLine("Launched DataSphere PID: " + pi.dwProcessId);
            AutomationElement appWin = null;
            IntPtr hwnd = IntPtr.Zero;

            for (int i = 0; i < 30; i++) {
                Thread.Sleep(300);
                var cond = new PropertyCondition(AutomationElement.ProcessIdProperty, pi.dwProcessId);
                appWin = AutomationElement.RootElement.FindFirst(TreeScope.Children, cond);
                if (appWin != null) {
                    hwnd = (IntPtr)appWin.Current.NativeWindowHandle;
                    break;
                }
            }

            if (appWin == null) {
                Console.WriteLine("Could not find DataSphere window!");
                try { Process.GetProcessById(pi.dwProcessId).Kill(); } catch {}
                allPassed = false;
                return;
            }

            SetForegroundWindow(hwnd);
            Thread.Sleep(2500);

            var tabItemCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem);

            // Helper to get top-level Shell TabItems
            Func<int> getTopShellTabsCount = () => {
                Rect wr = appWin.Current.BoundingRectangle;
                var allTabs = appWin.FindAll(TreeScope.Descendants, tabItemCond);
                int count = 0;
                foreach (AutomationElement item in allTabs) {
                    Rect r = item.Current.BoundingRectangle;
                    if (r.Y < wr.Y + 80 && r.Height > 25 && r.Height < 45) {
                        count++;
                    }
                }
                return count;
            };

            // Helper to select the Home tab
            Action selectHomeTab = () => {
                Rect wr = appWin.Current.BoundingRectangle;
                var allTabs = appWin.FindAll(TreeScope.Descendants, tabItemCond);
                foreach (AutomationElement item in allTabs) {
                    Rect r = item.Current.BoundingRectangle;
                    if (r.Y < wr.Y + 80 && (item.Current.Name.Contains("Trang chủ") || item.Current.Name.Contains("Home"))) {
                        try {
                            var sip = (SelectionItemPattern)item.GetCurrentPattern(SelectionItemPattern.Pattern);
                            sip.Select();
                        } catch {
                            PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                        }
                        Thread.Sleep(1500);
                        break;
                    }
                }
            };

            // Helper to click Database button on Home page
            Action clickDatabaseButton = () => {
                var buttons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
                AutomationElement dbBtn = null;
                foreach (AutomationElement btn in buttons) {
                    Rect r = btn.Current.BoundingRectangle;
                    if (r.Width > 200 && r.Height > 60) {
                        if (dbBtn == null || r.X < dbBtn.Current.BoundingRectangle.X) {
                            dbBtn = btn;
                        }
                    }
                }
                if (dbBtn != null) {
                    Rect r = dbBtn.Current.BoundingRectangle;
                    try {
                        var ip = (InvokePattern)dbBtn.GetCurrentPattern(InvokePattern.Pattern);
                        ip.Invoke();
                    } catch {
                        PhysicalLeftClick((int)(r.X + r.Width / 2), (int)(r.Y + r.Height / 2));
                    }
                    Thread.Sleep(2000);
                } else {
                    Console.WriteLine("Database button not found on Home page!");
                }
            };

            // Step 1: Initial state
            int initialCount = getTopShellTabsCount();
            Console.WriteLine("Initial top tabs: " + initialCount);
            if (initialCount != 1) {
                Console.WriteLine("[FAIL] Expected 1 initial tab.");
                allPassed = false;
            }

            // Step 2: 1st click on Database card
            Console.WriteLine("1st Click: Opening 1st Database tab...");
            clickDatabaseButton();
            int countAfter1 = getTopShellTabsCount();
            Console.WriteLine("Tabs after 1st click: " + countAfter1);
            if (countAfter1 == 2) {
                Console.WriteLine("[PASS] 1st Database tab opened successfully!");
            } else {
                Console.WriteLine("[FAIL] Expected 2 tabs after 1st click, got: " + countAfter1);
                allPassed = false;
            }

            // Step 3: Switch back to Home, 2nd click on Database card
            Console.WriteLine("Switching to Home tab...");
            selectHomeTab();
            Console.WriteLine("2nd Click: Opening 2nd Database tab...");
            clickDatabaseButton();
            int countAfter2 = getTopShellTabsCount();
            Console.WriteLine("Tabs after 2nd click: " + countAfter2);
            if (countAfter2 == 3) {
                Console.WriteLine("[PASS] 2nd Database tab created successfully!");
            } else {
                Console.WriteLine("[FAIL] Expected 3 tabs after 2nd click, got: " + countAfter2);
                allPassed = false;
            }

            // Step 4: Switch back to Home, 3rd click on Database card
            Console.WriteLine("Switching to Home tab...");
            selectHomeTab();
            Console.WriteLine("3rd Click: Opening 3rd Database tab...");
            clickDatabaseButton();
            int countAfter3 = getTopShellTabsCount();
            Console.WriteLine("Tabs after 3rd click: " + countAfter3);
            if (countAfter3 == 4) {
                Console.WriteLine("[PASS] 3rd Database tab created successfully!");
            } else {
                Console.WriteLine("[FAIL] Expected 4 tabs after 3rd click, got: " + countAfter3);
                allPassed = false;
            }

            // List all top tabs names
            Rect winBoundingRect = appWin.Current.BoundingRectangle;
            var finalTabs = appWin.FindAll(TreeScope.Descendants, tabItemCond);
            Console.WriteLine("Final active tabs list:");
            foreach (AutomationElement item in finalTabs) {
                Rect r = item.Current.BoundingRectangle;
                if (r.Y < winBoundingRect.Y + 80 && r.Height > 25 && r.Height < 45) {
                    Console.WriteLine("  - " + item.Current.Name + " (Bounds: " + r + ")");
                }
            }

            // Capture DirectComposition screenshot of verified multiple database tabs
            string verifiedShot = System.IO.Path.Combine(artifactDir, "winui_multiple_database_tabs_verified.png");
            CaptureWindow(hwnd, verifiedShot);
            Console.WriteLine("Saved multiple database tabs verification screenshot: " + verifiedShot);

            try { Process.GetProcessById(pi.dwProcessId).Kill(); } catch {}
        });

        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join(50000);

        return allPassed;
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing", "UIAutomationClient", "UIAutomationTypes", "WindowsBase"

$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363"

$result = [DatabaseTabVerifier]::Verify($exePath, $workingDir, $artifactDir)

if ($result) {
    Write-Host "ALL MULTIPLE DATABASE TAB CREATION TESTS PASSED!"
    exit 0
} else {
    Write-Host "VERIFICATION FAILED!"
    exit 1
}
