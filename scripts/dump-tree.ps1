$source = @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Automation;

public class TreeItemDumper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseDesktop(IntPtr hDesktop);

    public static string DumpTree(int pid) {
        string log = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            SetThreadDesktop(hDesk);
            try {
                var cond = new PropertyCondition(AutomationElement.ProcessIdProperty, pid);
                var appWin = AutomationElement.RootElement.FindFirst(TreeScope.Children, cond);
                if (appWin == null) return;

                var allTI = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TreeItem));
                log += "Total TreeItems: " + allTI.Count + "\n";
                foreach (AutomationElement ti in allTI) {
                    var r = ti.Current.BoundingRectangle;
                    if (r.X > 0 && r.X < 500) {
                        var textChild = ti.FindFirst(TreeScope.Children, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                        string tName = textChild != null ? textChild.Current.Name : "(no text)";
                        log += "TreeItem '" + ti.Current.Name + "' [Text: " + tName + "] rect=(" + (int)r.X + "," + (int)r.Y + "," + (int)r.Width + "x" + (int)r.Height + ")\n";

                        // Check patterns
                        object ep;
                        if (ti.TryGetCurrentPattern(ExpandCollapsePattern.Pattern, out ep)) {
                            var pattern = ep as ExpandCollapsePattern;
                            log += "   -> ExpandCollapseState: " + pattern.Current.ExpandCollapseState + "\n";
                        }
                    }
                }
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
$p = Get-Process -Name "DataSphere" -ErrorAction SilentlyContinue
if ($p) {
    [TreeItemDumper]::DumpTree($p.Id)
}
