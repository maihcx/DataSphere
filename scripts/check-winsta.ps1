Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public class WinStationHelper {
    [DllImport("user32.dll")]
    public static extern IntPtr GetProcessWindowStation();

    [DllImport("user32.dll")]
    public static extern IntPtr GetThreadDesktop(int dwThreadId);

    [DllImport("kernel32.dll")]
    public static extern int GetCurrentThreadId();

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool GetUserObjectInformation(IntPtr hObj, int nIndex, StringBuilder pvInfo, int nLength, out int lpnLengthNeeded);

    public static string GetInfo() {
        IntPtr hStation = GetProcessWindowStation();
        StringBuilder sb = new StringBuilder(256);
        int needed = 0;
        GetUserObjectInformation(hStation, 2, sb, 256, out needed);
        string station = sb.ToString();

        IntPtr hDesktop = GetThreadDesktop(GetCurrentThreadId());
        StringBuilder sbD = new StringBuilder(256);
        GetUserObjectInformation(hDesktop, 2, sbD, 256, out needed);
        string desktop = sbD.ToString();

        return "Station: " + station + ", Desktop: " + desktop;
    }
}
'@
Write-Host ([WinStationHelper]::GetInfo())
