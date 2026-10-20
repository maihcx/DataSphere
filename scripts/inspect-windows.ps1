param([int]$TargetPid = 0)

if ($TargetPid -eq 0) {
    $proc = Get-Process DataSphere -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $proc) {
        Write-Host "DataSphere process not found."
        exit 1
    }
    $TargetPid = $proc.Id
}

Write-Host "Target PID: $TargetPid"

Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public class WinHelper {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    public static List<IntPtr> FindWindowsForProcess(uint pid) {
        List<IntPtr> list = new List<IntPtr>();
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            uint pId = 0;
            GetWindowThreadProcessId(hWnd, out pId);
            if (pId == pid) {
                list.Add(hWnd);
            }
            return true;
        }, IntPtr.Zero);
        return list;
    }
}
'@

$windows = [WinHelper]::FindWindowsForProcess($TargetPid)
Write-Host "Found $($windows.Count) raw window handles for PID $TargetPid"

foreach ($h in $windows) {
    $isVisible = [WinHelper]::IsWindowVisible($h)
    $sbTitle = New-Object System.Text.StringBuilder 256
    [WinHelper]::GetWindowText($h, $sbTitle, 256) | Out-Null
    $sbClass = New-Object System.Text.StringBuilder 256
    [WinHelper]::GetClassName($h, $sbClass, 256) | Out-Null
    
    Write-Host "HWND: $h | Visible: $isVisible | Class: $($sbClass.ToString()) | Title: '$($sbTitle.ToString())'"
}
