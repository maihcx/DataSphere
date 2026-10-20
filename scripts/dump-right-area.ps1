$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class UiDumper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseDesktop(IntPtr hDesktop);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

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

    public static string DumpElements() {
        string log = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) return;
            SetThreadDesktop(hDesk);

            try {
                var procs = Process.GetProcessesByName("DataSphere");
                if (procs.Length == 0) {
                    log += "No DataSphere running\n";
                    return;
                }

                var appWin = AutomationElement.RootElement.FindFirst(TreeScope.Children, new PropertyCondition(AutomationElement.ProcessIdProperty, procs[0].Id));
                if (appWin == null) return;

                var allTexts = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                log += "All texts count: " + allTexts.Count + "\n";
                foreach (AutomationElement txt in allTexts) {
                    Rect r = txt.Current.BoundingRectangle;
                    if (r.X > 500) {
                        log += string.Format("Text in right area: '{0}' at ({1},{2},{3}x{4})\n",
                            txt.Current.Name, (int)r.X, (int)r.Y, (int)r.Width, (int)r.Height);
                    }
                }

                var allScrollBars = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.ScrollBar));
                log += "All scrollbars count: " + allScrollBars.Count + "\n";
                foreach (AutomationElement sb in allScrollBars) {
                    Rect r = sb.Current.BoundingRectangle;
                    log += string.Format("ScrollBar: '{0}' at ({1},{2},{3}x{4})\n",
                        sb.Current.Name, (int)r.X, (int)r.Y, (int)r.Width, (int)r.Height);
                }

                var allLists = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.List));
                log += "All Lists count: " + allLists.Count + "\n";
                foreach (AutomationElement l in allLists) {
                    Rect r = l.Current.BoundingRectangle;
                    log += string.Format("List: '{0}' at ({1},{2},{3}x{4})\n",
                        l.Current.Name, (int)r.X, (int)r.Y, (int)r.Width, (int)r.Height);
                }

            } catch (Exception ex) {
                log += ex.ToString();
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
[UiDumper]::DumpElements()
