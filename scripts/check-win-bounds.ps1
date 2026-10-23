$source = @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Automation;

public class WinDumper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);

    public static void Dump() {
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            SetThreadDesktop(hDesk);

            var procs = Process.GetProcessesByName("DataSphere");
            if (procs.Length == 0) {
                Console.WriteLine("No DataSphere process");
                return;
            }
            int pid = procs[0].Id;
            var cond = new PropertyCondition(AutomationElement.ProcessIdProperty, pid);
            var wins = AutomationElement.RootElement.FindAll(TreeScope.Children, cond);
            Console.WriteLine("Windows for PID " + pid + ": " + wins.Count);
            for (int i = 0; i < wins.Count; i++) {
                var w = wins[i];
                Console.WriteLine("Win " + i + ": Handle=" + w.Current.NativeWindowHandle + " Name='" + w.Current.Name + "' Bounds=" + w.Current.BoundingRectangle);
            }
        });
        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join();
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies "UIAutomationClient", "UIAutomationTypes", "WindowsBase"
[WinDumper]::Dump()
