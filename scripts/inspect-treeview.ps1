$source = @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Automation;

public class TreeInspector {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseDesktop(IntPtr hDesktop);

    public static string Inspect(int pid) {
        string log = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            SetThreadDesktop(hDesk);
            try {
                var cond = new PropertyCondition(AutomationElement.ProcessIdProperty, pid);
                var appWin = AutomationElement.RootElement.FindFirst(TreeScope.Children, cond);
                if (appWin == null) {
                    log += "Window not found\n";
                    return;
                }

                var treeItems = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TreeItem));
                log += "Found " + treeItems.Count + " TreeItems\n";
                foreach (AutomationElement ti in treeItems) {
                    log += "TreeItem: Name='" + ti.Current.Name + "', ClassName='" + ti.Current.ClassName + "'\n";
                    var children = ti.FindAll(TreeScope.Children, Condition.TrueCondition);
                    foreach (AutomationElement ch in children) {
                        log += "   Child: ControlType=" + ch.Current.ControlType.ProgrammaticName + ", Name='" + ch.Current.Name + "', ClassName='" + ch.Current.ClassName + "'\n";
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
    [TreeInspector]::Inspect($p.Id)
} else {
    Write-Host "DataSphere not running"
}
