$source = @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Automation;

public class WindowDumper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);

    public static void Dump() {
        IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
        SetThreadDesktop(hDesk);

        Process[] procs = Process.GetProcessesByName("DataSphere");
        if (procs.Length == 0) {
            Console.WriteLine("DataSphere is not running.");
            return;
        }

        var cond = new PropertyCondition(AutomationElement.ProcessIdProperty, procs[0].Id);
        AutomationElement appWin = AutomationElement.RootElement.FindFirst(TreeScope.Children, cond);
        if (appWin == null) {
            Console.WriteLine("Window not found.");
            return;
        }

        Console.WriteLine("Window Bounds: " + appWin.Current.BoundingRectangle);
        var buttons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
        Console.WriteLine("Total Buttons: " + buttons.Count);
        for (int i = 0; i < buttons.Count; i++) {
            Console.WriteLine("Button " + i + ": Name='" + buttons[i].Current.Name + "' Bounds=" + buttons[i].Current.BoundingRectangle);
        }
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies "UIAutomationClient", "UIAutomationTypes", "WindowsBase"
[WindowDumper]::Dump()
