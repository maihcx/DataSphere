$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class DatabaseTabReproduction {
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

    public static bool Reproduce(string exePath, string workingDir, string artifactDir) {
        bool bugReproduced = false;
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) {
                Console.WriteLine("Failed to open desktop!");
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
                return;
            }

            SetForegroundWindow(hwnd);
            Thread.Sleep(2500);

            var tabItemCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem);
            var initialTabs = appWin.FindAll(TreeScope.Descendants, tabItemCond);
            Console.WriteLine("Initial Tabs: " + initialTabs.Count);

            // Step 1: Find the Databases card button on HomePage
            // The Database card is the first card button in Grid.Column="0"
            var allButtons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
            AutomationElement dbBtn = null;
            foreach (AutomationElement btn in allButtons) {
                Rect r = btn.Current.BoundingRectangle;
                if (r.Width > 200 && r.Height > 60) {
                    if (dbBtn == null || r.X < dbBtn.Current.BoundingRectangle.X) {
                        dbBtn = btn;
                    }
                }
            }

            if (dbBtn == null) {
                Console.WriteLine("Database button NOT found on Home Page!");
                try { Process.GetProcessById(pi.dwProcessId).Kill(); } catch {}
                return;
            }

            // Click Databases button (1st time)
            Rect dbr = dbBtn.Current.BoundingRectangle;
            Console.WriteLine("Clicking Database card button 1st time at (" + (int)(dbr.X + dbr.Width / 2) + ", " + (int)(dbr.Y + dbr.Height / 2) + ")...");
            PhysicalLeftClick((int)(dbr.X + dbr.Width / 2), (int)(dbr.Y + dbr.Height / 2));
            Thread.Sleep(2000);

            var tabsAfterFirst = appWin.FindAll(TreeScope.Descendants, tabItemCond);
            Console.WriteLine("Tabs after 1st click: " + tabsAfterFirst.Count);
            for (int i = 0; i < tabsAfterFirst.Count; i++) {
                Console.WriteLine("  Tab " + (i + 1) + ": " + tabsAfterFirst[i].Current.Name);
            }

            // Step 2: Switch back to Home Tab using SelectionItemPattern
            var topTabItems = appWin.FindAll(TreeScope.Descendants, tabItemCond);
            AutomationElement homeTab = topTabItems[0];
            Console.WriteLine("Selecting Home tab via SelectionItemPattern: " + homeTab.Current.Name);
            try {
                var sip = (SelectionItemPattern)homeTab.GetCurrentPattern(SelectionItemPattern.Pattern);
                sip.Select();
            } catch {
                Rect hr = homeTab.Current.BoundingRectangle;
                PhysicalLeftClick((int)(hr.X + hr.Width / 2), (int)(hr.Y + hr.Height / 2));
            }
            Thread.Sleep(2000);

            // Step 3: Find Database button again on Home Page
            allButtons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
            dbBtn = null;
            foreach (AutomationElement btn in allButtons) {
                Rect r = btn.Current.BoundingRectangle;
                if (r.Width > 200 && r.Height > 60) {
                    if (dbBtn == null || r.X < dbBtn.Current.BoundingRectangle.X) {
                        dbBtn = btn;
                    }
                }
            }

            if (dbBtn != null) {
                dbr = dbBtn.Current.BoundingRectangle;
                Console.WriteLine("Clicking Database card button 2nd time at (" + (int)(dbr.X + dbr.Width / 2) + ", " + (int)(dbr.Y + dbr.Height / 2) + ")...");
                try {
                    var ip = (InvokePattern)dbBtn.GetCurrentPattern(InvokePattern.Pattern);
                    ip.Invoke();
                } catch {
                    PhysicalLeftClick((int)(dbr.X + dbr.Width / 2), (int)(dbr.Y + dbr.Height / 2));
                }
                Thread.Sleep(2000);

                var tabsAfterSecond = appWin.FindAll(TreeScope.Descendants, tabItemCond);
                Console.WriteLine("Tabs after 2nd click: " + tabsAfterSecond.Count);
                for (int i = 0; i < tabsAfterSecond.Count; i++) {
                    Console.WriteLine("  Tab " + (i + 1) + ": " + tabsAfterSecond[i].Current.Name);
                }

                // Check top-level ShellTabView tabs (tabs with Height around 34px in the titlebar)
                Rect wRect = appWin.Current.BoundingRectangle;
                int topTabsCount = 0;
                foreach (AutomationElement tItem in tabsAfterSecond) {
                    if (tItem.Current.BoundingRectangle.Y < wRect.Y + 100) {
                        topTabsCount++;
                    }
                }
                Console.WriteLine("Top-level Shell tabs count: " + topTabsCount);

                if (topTabsCount == 2) {
                    Console.WriteLine("[BUG CONFIRMED] Clicking Database button a 2nd time did NOT create a new tab! It only focused the existing tab!");
                    bugReproduced = true;
                } else if (topTabsCount >= 3) {
                    Console.WriteLine("[INFO] A new tab was created (topTabsCount = " + topTabsCount + ").");
                }
            } else {
                Console.WriteLine("Database button not found after returning to Home tab!");
            }

            // Capture DirectComposition Screenshot of the reproduced bug state
            string diagShot = System.IO.Path.Combine(artifactDir, "diagnose_database_tab_reuse.png");
            CaptureWindow(hwnd, diagShot);
            Console.WriteLine("Saved diagnostic screenshot: " + diagShot);

            try { Process.GetProcessById(pi.dwProcessId).Kill(); } catch {}
        });

        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join(45000);

        return bugReproduced;
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing", "UIAutomationClient", "UIAutomationTypes", "WindowsBase"

$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363"

$result = [DatabaseTabReproduction]::Reproduce($exePath, $workingDir, $artifactDir)

if ($result) {
    Write-Host "BUG REPRODUCED SUCCESSFULLY (CONFIRMED)"
    exit 0
} else {
    Write-Host "REPRODUCTION CHECK FINISHED"
    exit 0
}
