Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public class WinUIFinder {
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

    public static void FindAll() {
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            StringBuilder sbClass = new StringBuilder(256);
            GetClassName(hWnd, sbClass, 256);
            string cls = sbClass.ToString();
            if (cls.Contains("WinUI") || cls.Contains("DataSphere")) {
                uint pid = 0;
                GetWindowThreadProcessId(hWnd, out pid);
                StringBuilder sbText = new StringBuilder(256);
                GetWindowText(hWnd, sbText, 256);
                Console.WriteLine("HWND: " + hWnd + " PID: " + pid + " Class: " + cls + " Title: " + sbText.ToString() + " Visible: " + IsWindowVisible(hWnd));
            }
            return true;
        }, IntPtr.Zero);
    }
}
'@
[WinUIFinder]::FindAll()
