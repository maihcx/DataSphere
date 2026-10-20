Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public class AllWinFinder {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    public static List<string> GetAllVisible() {
        List<string> res = new List<string>();
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            if (IsWindowVisible(hWnd)) {
                StringBuilder sb = new StringBuilder(256);
                GetWindowText(hWnd, sb, 256);
                string title = sb.ToString();
                if (!string.IsNullOrEmpty(title)) {
                    uint pid = 0;
                    GetWindowThreadProcessId(hWnd, out pid);
                    res.Add("PID: " + pid + " | " + title);
                }
            }
            return true;
        }, IntPtr.Zero);
        return res;
    }
}
'@

$wins = [AllWinFinder]::GetAllVisible()
Write-Host "Total visible windows: $($wins.Count)"
$wins | Select-Object -First 20 | ForEach-Object { Write-Host $_ }
