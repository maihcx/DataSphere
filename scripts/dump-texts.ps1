$source = @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Automation;

public class TextLogger {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseDesktop(IntPtr hDesktop);

    public static string DumpTexts(int pid) {
        string log = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            SetThreadDesktop(hDesk);
            try {
                var cond = new PropertyCondition(AutomationElement.ProcessIdProperty, pid);
                var appWin = AutomationElement.RootElement.FindFirst(TreeScope.Children, cond);
                if (appWin == null) return;

                var allT = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text));
                foreach (AutomationElement txt in allT) {
                    string n = txt.Current.Name ?? "";
                    if (n.Length > 0) {
                        log += "TXT: '" + n + "' (len=" + n.Length + ", hex=";
                        foreach (char c in n) log += ((int)c).ToString("X4") + " ";
                        log += ") at (" + (int)txt.Current.BoundingRectangle.X + "," + (int)txt.Current.BoundingRectangle.Y + ")\n";
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
    [TextLogger]::DumpTexts($p.Id)
}
