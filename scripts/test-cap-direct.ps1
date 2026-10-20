$code = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class WinCapDirect {
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, int nFlags);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public static string CaptureHandle(IntPtr hWnd, string outPath) {
        RECT r;
        GetWindowRect(hWnd, out r);
        int w = r.Right - r.Left;
        int h = r.Bottom - r.Top;
        if (w <= 0 || h <= 0) {
            return "Invalid rect: " + w + "x" + h;
        }

        using (Bitmap bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb)) {
            using (Graphics g = Graphics.FromImage(bmp)) {
                IntPtr hdc = g.GetHdc();
                // 2 = PW_RENDERFULLCONTENT
                bool ok = PrintWindow(hWnd, hdc, 2);
                if (!ok) {
                    PrintWindow(hWnd, hdc, 0);
                }
                g.ReleaseHdc(hdc);
            }
            bmp.Save(outPath, ImageFormat.Png);
        }
        return "SUCCESS: " + outPath + " (" + w + "x" + h + ")";
    }
}
'@

Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing

$proc = Get-Process -Name DataSphere -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) {
    Write-Host "DataSphere not found!"
    exit 1
}

Write-Host "Found DataSphere PID: $($proc.Id), HWND: $($proc.MainWindowHandle)"
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\aca4648a-7af8-48c3-9b8a-ae269a772d90"
$outPath = "$artifactDir\datasphere_capture_test.png"

$res = [WinCapDirect]::CaptureHandle($proc.MainWindowHandle, $outPath)
Write-Host $res
