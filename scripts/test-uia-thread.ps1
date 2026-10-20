Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;

public class ThreadDesktopRunner {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseDesktop(IntPtr hDesktop);

    public static List<string> RunOnDefaultDesktop() {
        List<string> results = new List<string>();
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) {
                results.Add("OpenDesktop failed: " + Marshal.GetLastWin32Error());
                return;
            }

            bool set = SetThreadDesktop(hDesk);
            if (!set) {
                results.Add("SetThreadDesktop failed: " + Marshal.GetLastWin32Error());
                CloseDesktop(hDesk);
                return;
            }

            try {
                var root = System.Windows.Automation.AutomationElement.RootElement;
                var children = root.FindAll(
                    System.Windows.Automation.TreeScope.Children,
                    System.Windows.Automation.Condition.TrueCondition
                );

                results.Add("SUCCESS! Found " + children.Count + " top-level UIA elements on default desktop:");
                foreach (System.Windows.Automation.AutomationElement el in children) {
                    try {
                        string name = el.Current.Name;
                        if (!string.IsNullOrEmpty(name)) {
                            results.Add(" - [" + el.Current.ProcessId + "] " + name + " (" + el.Current.ClassName + ")");
                        }
                    } catch {}
                }
            } catch (Exception ex) {
                results.Add("Exception in UIA: " + ex.Message);
            } finally {
                CloseDesktop(hDesk);
            }
        });

        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join();
        return results;
    }
}
'@ -ReferencedAssemblies UIAutomationClient, UIAutomationTypes

$out = [ThreadDesktopRunner]::RunOnDefaultDesktop()
foreach ($line in $out) {
    Write-Host $line
}
