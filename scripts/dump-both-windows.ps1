$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class BothWindowsDumper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, uint nFlags);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    public static void Capture(IntPtr hwnd, string path) {
        RECT rc; GetWindowRect(hwnd, out rc);
        int w = rc.Right - rc.Left; int h = rc.Bottom - rc.Top;
        if (w <= 0 || h <= 0) return;
        using (Bitmap bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb)) {
            using (Graphics g = Graphics.FromImage(bmp)) {
                IntPtr hdc = g.GetHdc();
                try { PrintWindow(hwnd, hdc, 2); } finally { g.ReleaseHdc(hdc); }
            }
            bmp.Save(path, ImageFormat.Png);
        }
    }

    public static void Run() {
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            SetThreadDesktop(hDesk);

            var procs = Process.GetProcessesByName("DataSphere");
            if (procs.Length == 0) { Console.WriteLine("No process"); return; }
            int pid = procs[0].Id;
            var cond = new PropertyCondition(AutomationElement.ProcessIdProperty, pid);
            var wins = AutomationElement.RootElement.FindAll(TreeScope.Children, cond);
            Console.WriteLine("Windows count: " + wins.Count);
            for (int i = 0; i < wins.Count; i++) {
                var w = wins[i];
                IntPtr h = (IntPtr)w.Current.NativeWindowHandle;
                RECT rc; GetWindowRect(h, out rc);
                Console.WriteLine("Win " + i + ": HWND=" + h + " Name='" + w.Current.Name + "' Rect=(" + rc.Left + "," + rc.Top + ")-(" + rc.Right + "," + rc.Bottom + ") W=" + (rc.Right - rc.Left) + " H=" + (rc.Bottom - rc.Top));
                Capture(h, @"D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule\dump_win_" + i + ".png");

                var tabs = w.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                Console.WriteLine("  Tabs in Win " + i + ": " + tabs.Count);
                for (int j = 0; j < tabs.Count; j++) {
                    Console.WriteLine("    Tab " + j + ": Name='" + tabs[j].Current.Name + "' Bounds=" + tabs[j].Current.BoundingRectangle);
                }
            }
        });
        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join();
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing", "UIAutomationClient", "UIAutomationTypes", "WindowsBase"
[BothWindowsDumper]::Run()
