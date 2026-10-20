$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class ScrollTester {
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

    public static void PhysicalLeftClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(200);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, 0);
        Thread.Sleep(500);
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

    public static string TestCurrentWindow(string artifactDir) {
        string log = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) {
                log += "Failed to open default desktop\n";
                return;
            }
            SetThreadDesktop(hDesk);

            try {
                var cond = new PropertyCondition(AutomationElement.NameProperty, "DataSphere");
                var procs = Process.GetProcessesByName("DataSphere");
                if (procs.Length == 0) {
                    log += "No DataSphere running\n";
                    return;
                }

                int pid = procs[0].Id;
                var appWin = AutomationElement.RootElement.FindFirst(TreeScope.Children, new PropertyCondition(AutomationElement.ProcessIdProperty, pid));
                if (appWin == null) {
                    log += "AppWin not found\n";
                    return;
                }

                IntPtr hwnd = (IntPtr)appWin.Current.NativeWindowHandle;
                SetForegroundWindow(hwnd);
                Thread.Sleep(500);

                RECT winRect;
                GetWindowRect(hwnd, out winRect);
                log += string.Format("DataSphere Window: ({0},{1}) to ({2},{3}), Width={4}, Height={5}\n",
                    winRect.Left, winRect.Top, winRect.Right, winRect.Bottom, winRect.Right - winRect.Left, winRect.Bottom - winRect.Top);

                // Dump all ScrollViewers and ScrollBars
                var sbs = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ScrollBar));
                log += "Total ScrollBars found: " + sbs.Count + "\n";
                foreach (AutomationElement sb in sbs) {
                    Rect r = sb.Current.BoundingRectangle;
                    log += string.Format("ScrollBar: Name='{0}', Rect=({1},{2},{3}x{4})\n",
                        sb.Current.Name, (int)r.X, (int)r.Y, (int)r.Width, (int)r.Height);
                }

                // Drag or click horizontal scroll bar to scroll right
                // The horizontal scrollbar is near the bottom of DataViewControl, above the pagination footer.
                // In a 1029px window, let's find the horizontal scrollbar or click the right track:
                // From the user screenshot, pagination is at Y ~ 930. The horizontal scrollbar is at Y ~ 920.
                // Right side of table area is X ~ 1640.
                int scrollTrackX = winRect.Right - 50;
                int scrollTrackY = winRect.Bottom - 80;
                log += string.Format("Clicking horizontal scroll track at ({0},{1})...\n", scrollTrackX, scrollTrackY);
                for (int i = 0; i < 5; i++) {
                    PhysicalLeftClick(scrollTrackX, scrollTrackY);
                    Thread.Sleep(300);
                }

                Thread.Sleep(1000);
                string scrolledSnap = artifactDir + "\\bug_scrollbar_scrolled_to_right.png";
                CaptureWindow(hwnd, scrolledSnap);
                log += "Captured scrolled screenshot: " + scrolledSnap + "\n";

                // Check ScrollBars again after scrolling right
                sbs = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ScrollBar));
                log += "Total ScrollBars after scrolling right: " + sbs.Count + "\n";
                foreach (AutomationElement sb in sbs) {
                    Rect r = sb.Current.BoundingRectangle;
                    log += string.Format("ScrollBar after scroll: Name='{0}', Rect=({1},{2},{3}x{4})\n",
                        sb.Current.Name, (int)r.X, (int)r.Y, (int)r.Width, (int)r.Height);
                }

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
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363"
$log = [ScrollTester]::TestCurrentWindow($artifactDir)
Write-Host $log
