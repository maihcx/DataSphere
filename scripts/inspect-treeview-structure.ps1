$source = @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Automation;

public class TreeViewItemInspector {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseDesktop(IntPtr hDesktop);

    public static string Inspect() {
        string log = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) return;
            SetThreadDesktop(hDesk);

            try {
                var procs = Process.GetProcessesByName("DataSphere");
                if (procs.Length == 0) return;

                var appWin = AutomationElement.RootElement.FindFirst(TreeScope.Children, new PropertyCondition(AutomationElement.ProcessIdProperty, procs[0].Id));
                if (appWin == null) return;

                var allTreeItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TreeItem));
                log += "TreeItems count: " + allTreeItems.Count + "\n";
                foreach (AutomationElement ti in allTreeItems) {
                    log += "TreeItem: " + ti.Current.Name + " rect=" + ti.Current.BoundingRectangle + "\n";
                    var children = ti.FindAll(TreeScope.Children, Condition.TrueCondition);
                    foreach (AutomationElement ch in children) {
                        log += "  Child: type=" + ch.Current.ControlType.ProgrammaticName + ", name=" + ch.Current.Name + ", id=" + ch.Current.AutomationId + "\n";
                    }
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

Add-Type -TypeDefinition $source -ReferencedAssemblies WindowsBase, UIAutomationClient, UIAutomationTypes
[TreeViewItemInspector]::Inspect()
