Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public class DesktopSwitcher {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseDesktop(IntPtr hDesktop);

    [DllImport("user32.dll")]
    public static extern bool EnumDesktopWindows(IntPtr hDesktop, EnumWindowsProc enumProc, IntPtr lParam);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    public const uint GENERIC_ALL = 0x10000000;
    public const uint DESKTOP_ENUMERATE = 0x0040;
    public const uint DESKTOP_READOBJECTS = 0x0001;
    public const uint DESKTOP_SWITCHDESKTOP = 0x0100;

    public static List<string> ListDefaultDesktopWindows() {
        List<string> list = new List<string>();
        IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
        if (hDesk == IntPtr.Zero) {
            int err = Marshal.GetLastWin32Error();
            list.Add("Failed to open default desktop: " + err);
            return list;
        }

        EnumDesktopWindows(hDesk, delegate(IntPtr hWnd, IntPtr lParam) {
            if (IsWindowVisible(hWnd)) {
                StringBuilder sb = new StringBuilder(256);
                GetWindowText(hWnd, sb, 256);
                string title = sb.ToString();
                if (!string.IsNullOrEmpty(title)) {
                    uint pid = 0;
                    GetWindowThreadProcessId(hWnd, out pid);
                    list.Add("PID: " + pid + " | " + title);
                }
            }
            return true;
        }, IntPtr.Zero);

        CloseDesktop(hDesk);
        return list;
    }
}
'@

$res = [DesktopSwitcher]::ListDefaultDesktopWindows()
Write-Host "Count on default desktop: $($res.Count)"
$res | Select-Object -First 15 | ForEach-Object { Write-Host $_ }
