Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName WindowsBase

$source = @'
using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Automation;

public class PointTester {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);

    public static void Test(int x, int y) {
        IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
        SetThreadDesktop(hDesk);

        Point pt = new Point(x, y);
        AutomationElement el = AutomationElement.FromPoint(pt);
        if (el == null) {
            Console.WriteLine("No element at (" + x + "," + y + ")");
            return;
        }
        Console.WriteLine("Element at (" + x + "," + y + "): Name='" + el.Current.Name + "' Class='" + el.Current.ClassName + "' ControlType=" + el.Current.ControlType.ProgrammaticName + " Bounds=" + el.Current.BoundingRectangle);
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies "UIAutomationClient", "WindowsBase"
[PointTester]::Test(368, 250)
