param(
    [string]$ProcessName = "DataSphere",
    [string]$OutputPath = ""
)

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;

public class WindowCapture
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseDesktop(IntPtr hDesktop);

    [DllImport("user32.dll")]
    public static extern bool EnumDesktopWindows(IntPtr hDesktop, EnumWindowsProc enumProc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, int nFlags);

    public static IntPtr FindWindowForProcess(uint pid)
    {
        IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
        IntPtr found = IntPtr.Zero;

        EnumWindowsProc proc = delegate(IntPtr hWnd, IntPtr lParam)
        {
            uint procId = 0;
            GetWindowThreadProcessId(hWnd, out procId);
            if (procId == pid && IsWindowVisible(hWnd))
            {
                RECT r;
                GetWindowRect(hWnd, out r);
                int w = r.Right - r.Left;
                int h = r.Bottom - r.Top;
                if (w > 100 && h > 100)
                {
                    found = hWnd;
                    return false;
                }
            }
            return true;
        };

        if (hDesk != IntPtr.Zero)
        {
            EnumDesktopWindows(hDesk, proc, IntPtr.Zero);
            CloseDesktop(hDesk);
        }

        if (found == IntPtr.Zero)
        {
            EnumWindows(proc, IntPtr.Zero);
        }

        return found;
    }

    public static Bitmap CaptureWindow(IntPtr handle)
    {
        IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
        if (hDesk != IntPtr.Zero)
        {
            SetThreadDesktop(hDesk);
        }

        RECT rect;
        GetWindowRect(handle, out rect);
        int width = rect.Right - rect.Left;
        int height = rect.Bottom - rect.Top;

        if (width <= 0 || height <= 0)
        {
            if (hDesk != IntPtr.Zero) CloseDesktop(hDesk);
            throw new InvalidOperationException("Window rectangle has invalid dimensions: " + width + "x" + height);
        }

        Bitmap bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb);
        using (Graphics gfxBmp = Graphics.FromImage(bmp))
        {
            IntPtr hdcBitmap = gfxBmp.GetHdc();
            try
            {
                // 2 = PW_RENDERFULLCONTENT (captures DirectComposition / WinUI 3 XAML windows)
                bool success = PrintWindow(handle, hdcBitmap, 2);
                if (!success)
                {
                    // Fallback to standard PrintWindow
                    PrintWindow(handle, hdcBitmap, 0);
                }
            }
            finally
            {
                gfxBmp.ReleaseHdc(hdcBitmap);
            }
        }

        if (hDesk != IntPtr.Zero) CloseDesktop(hDesk);
        return bmp;
    }
}
'@ -ReferencedAssemblies System.Drawing

$proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) {
    Write-Error "Process '$ProcessName' not found. Ensure DataSphere is running."
    exit 1
}

$hwnd = $proc.MainWindowHandle
if ($hwnd -eq [IntPtr]::Zero) {
    $hwnd = [WindowCapture]::FindWindowForProcess([uint32]$proc.Id)
}

if ($hwnd -eq [IntPtr]::Zero) {
    Write-Error "Process '$ProcessName' (PID $($proc.Id)) has no visible window handle."
    exit 1
}

[WindowCapture]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 250

$bmp = [WindowCapture]::CaptureWindow($hwnd)

if (-not $OutputPath) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputPath = "C:\Users\huynh\.gemini\antigravity\brain\aca4648a-7af8-48c3-9b8a-ae269a772d90\ui_snapshot_$timestamp.png"
}

$bmp.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Output "SCREENSHOT_SAVED: $OutputPath"
