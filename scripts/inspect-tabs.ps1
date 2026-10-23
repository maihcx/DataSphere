$source = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class TabInspector {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseDesktop(IntPtr hDesktop);

    public static string InspectTabs() {
        string log = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            SetThreadDesktop(hDesk);

            try {
                var procs = Process.GetProcessesByName("DataSphere");
                if (procs.Length == 0) {
                    log += "No DataSphere process found\n";
                    return;
                }

                IntPtr hwnd = procs[0].MainWindowHandle;
                AutomationElement appWin = AutomationElement.FromHandle(hwnd);
                var allTabs = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.TabItem));
                log += "Total TabItems: " + allTabs.Count + "\n";
                for (int i = 0; i < allTabs.Count; i++) {
                    var tab = allTabs[i];
                    Rect r = tab.Current.BoundingRectangle;
                    log += string.Format("Tab {0}: Name='{1}', Class='{2}', Rect=({3}, {4}, {5}, {6})\n",
                        i, tab.Current.Name, tab.Current.ClassName, r.X, r.Y, r.Width, r.Height);

                    var btns = tab.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
                    log += "   Buttons: " + btns.Count + "\n";
                    for (int j = 0; j < btns.Count; j++) {
                        Rect br = btns[j].Current.BoundingRectangle;
                        log += string.Format("   Btn {0}: Name='{1}', Rect=({2}, {3}, {4}, {5})\n",
                            j, btns[j].Current.Name, br.X, br.Y, br.Width, br.Height);
                    }
                }
            } catch (Exception ex) {
                log += "Error: " + ex.Message + "\n";
            } finally {
                CloseDesktop(hDesk);
            }
        });

        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join(10000);
        return log;
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Windows.Forms", "UIAutomationClient", "UIAutomationTypes", "WindowsBase", "System.Drawing"

[TabInspector]::InspectTabs()
