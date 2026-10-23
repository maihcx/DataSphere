$source = @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class TabDumper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseDesktop(IntPtr hDesktop);

    public static void Dump() {
        IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
        SetThreadDesktop(hDesk);
        try {
            var procs = Process.GetProcessesByName("DataSphere");
            if (procs.Length == 0) { Console.WriteLine("No process"); return; }
            int pid = procs[0].Id;
            var wins = AutomationElement.RootElement.FindAll(TreeScope.Children, new PropertyCondition(AutomationElement.ProcessIdProperty, pid));
            Console.WriteLine("Total windows: " + wins.Count);
            for (int w = 0; w < wins.Count; w++) {
                Console.WriteLine("--- Window " + w + " ---");
                var tabs = wins[w].FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                for (int t = 0; t < tabs.Count; t++) {
                    Rect r = tabs[t].Current.BoundingRectangle;
                    Console.WriteLine(string.Format("  Tab {0}: Name='{1}', Class='{2}', Rect=({3},{4},{5},{6})",
                        t, tabs[t].Current.Name, tabs[t].Current.ClassName, r.X, r.Y, r.Width, r.Height));
                }
            }
        } finally {
            CloseDesktop(hDesk);
        }
    }
}
'@
Add-Type -TypeDefinition $source -ReferencedAssemblies "UIAutomationClient", "UIAutomationTypes", "WindowsBase"
[TabDumper]::Dump()
