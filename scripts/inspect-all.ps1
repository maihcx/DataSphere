Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public class WinInspector {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    public static List<string> Check(uint pid) {
        List<string> res = new List<string>();
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            uint pId = 0;
            GetWindowThreadProcessId(hWnd, out pId);
            if (pId == pid) {
                StringBuilder sbClass = new StringBuilder(256);
                GetClassName(hWnd, sbClass, 256);
                StringBuilder sbText = new StringBuilder(256);
                GetWindowText(hWnd, sbText, 256);
                res.Add("HWND: " + hWnd + " | Cls: " + sbClass.ToString() + " | Txt: '" + sbText.ToString() + "' | Vis: " + IsWindowVisible(hWnd));
            }
            return true;
        }, IntPtr.Zero);
        return res;
    }
}
'@

$proc = Get-Process DataSphere -ErrorAction SilentlyContinue | Select-Object -First 1
if ($proc) {
    $r = [WinInspector]::Check([uint32]$proc.Id)
    Write-Host "Count: $($r.Count)"
    foreach ($line in $r) {
        Write-Host $line
    }
} else {
    Write-Host "Not running"
}
