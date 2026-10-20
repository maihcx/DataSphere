Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public class WinUIFinder2 {
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

    public static List<string> FindAll(uint targetPid) {
        List<string> result = new List<string>();
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            uint pid = 0;
            GetWindowThreadProcessId(hWnd, out pid);
            if (pid == targetPid) {
                StringBuilder sbClass = new StringBuilder(256);
                GetClassName(hWnd, sbClass, 256);
                StringBuilder sbText = new StringBuilder(256);
                GetWindowText(hWnd, sbText, 256);
                result.Add("HWND: " + hWnd + " | Class: " + sbClass.ToString() + " | Title: '" + sbText.ToString() + "' | Visible: " + IsWindowVisible(hWnd));
            }
            return true;
        }, IntPtr.Zero);
        return result;
    }
}
'@

$proc = Get-Process DataSphere -ErrorAction SilentlyContinue | Select-Object -First 1
if ($proc) {
    Write-Host "Found DataSphere PID $($proc.Id)"
    $lines = [WinUIFinder2]::FindAll([uint32]$proc.Id)
    Write-Host "Total HWNDs for PID: $($lines.Count)"
    foreach ($l in $lines) {
        Write-Host $l
    }
} else {
    Write-Host "DataSphere process not found."
}
