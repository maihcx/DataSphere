Add-Type @'
using System;
using System.Runtime.InteropServices;

public class DesktopHelper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);

    public static bool SwitchToDefault() {
        IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
        if (hDesk != IntPtr.Zero) {
            return SetThreadDesktop(hDesk);
        }
        return false;
    }
}
'@

$switched = [DesktopHelper]::SwitchToDefault()
Write-Host "Switched to default desktop: $switched"

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$root = [System.Windows.Automation.AutomationElement]::RootElement
$children = $root.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)

Write-Host "UIA Root Children Count on default desktop: $($children.Count)"
foreach ($child in $children) {
    if (-not [string]::IsNullOrEmpty($child.Current.Name)) {
        Write-Host "Name: '$($child.Current.Name)' | Class: '$($child.Current.ClassName)' | PID: $($child.Current.ProcessId)"
    }
}
