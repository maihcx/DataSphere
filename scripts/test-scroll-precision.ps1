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

    public static string TestDrag(int pid, string artifactDir) {
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
                Thread.Sleep(1000);

                // Find vertical scrollbar in DataRowsListView
                AutomationElement vScroll = null;
                var allScrollBars = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ScrollBar));
                log += "Found " + allScrollBars.Count + " scrollbars.\n";
                foreach (AutomationElement sb in allScrollBars) {
                    Rect r = sb.Current.BoundingRectangle;
                    log += "ScrollBar: " + r.ToString() + ", Name=" + sb.Current.Name + "\n";
                    if (r.Height > r.Width && r.Height > 100) {
                        // This is a vertical scrollbar!
                        vScroll = sb;
                        break;
                    }
                }

                if (vScroll != null) {
                    Rect sr = vScroll.Current.BoundingRectangle;
                    log += "Target Vertical ScrollBar: " + sr.ToString() + "\n";

                    // Find Thumb inside vertical scrollbar
                    AutomationElement thumb = vScroll.FindFirst(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Thumb));
                    int startX, startY, endY;
                    if (thumb != null) {
                        Rect tr = thumb.Current.BoundingRectangle;
                        log += "Found Thumb: " + tr.ToString() + "\n";
                        startX = (int)(tr.X + tr.Width / 2);
                        startY = (int)(tr.Y + tr.Height / 2);
                        endY = (int)(sr.Y + sr.Height - 30);
                    } else {
                        startX = (int)(sr.X + sr.Width / 2);
                        startY = (int)(sr.Y + 30);
                        endY = (int)(sr.Y + sr.Height - 30);
                    }

                    log += "Dragging from (" + startX + ", " + startY + ") to (" + startX + ", " + endY + ")...\n";
                    
                    // Hover first to expand scrollbar
                    SetCursorPos(startX, startY);
                    Thread.Sleep(300);

                    // Press down
                    mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)startX, (uint)startY, 0, 0);
                    Thread.Sleep(100);

                    // Drag fast down in small steps over 50ms
                    int steps = 10;
                    for (int s = 1; s <= steps; s++) {
                        int curY = startY + (endY - startY) * s / steps;
                        SetCursorPos(startX, curY);
                        Thread.Sleep(5);
                    }

                    // Capture during or immediately upon reaching bottom
                    string snapFast = artifactDir + "\\fixed_drag_in_action.png";
                    CaptureWindow(hwnd, snapFast);
                    log += "Captured drag in action: " + snapFast + "\n";

                    mouse_event(MOUSEEVENTF_LEFTUP, (uint)startX, (uint)endY, 0, 0);
                    Thread.Sleep(500);

                    string snapSettled = artifactDir + "\\fixed_drag_settled.png";
                    CaptureWindow(hwnd, snapSettled);
                    log += "Captured settled: " + snapSettled + "\n";
                } else {
                    log += "ERROR: Vertical scrollbar not found!\n";
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

# Reuse existing running DataSphere or launch if not running
$p = Get-Process -Name "DataSphere" -ErrorAction SilentlyContinue
if (-not $p) {
    Write-Host "DataSphere is not running. Launching with verify-fast-scroll-fixed.ps1..."
    & powershell -ExecutionPolicy Bypass -File scripts\verify-fast-scroll-fixed.ps1
} else {
    $pidToTest = $p[0].Id
    $artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363"
    Write-Host "Testing on running DataSphere PID $pidToTest..."
    $log = [ScrollTester]::TestDrag($pidToTest, $artifactDir)
    Write-Host $log
}
