$code = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;

public class WinDirectTester {
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, int nFlags);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public static string Capture(IntPtr hWnd, string outPath) {
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

$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"

Write-Host "Launching DataSphere..."
$proc = Start-Process -FilePath $exePath -WorkingDirectory $workingDir -PassThru

try {
    Write-Host "Process PID: $($proc.Id)"
    $hwnd = [IntPtr]::Zero
    for ($i = 0; $i -lt 15; $i++) {
        Start-Sleep -Milliseconds 500
        $proc.Refresh()
        if ($proc.HasExited) {
            Write-Host "Process exited unexpectedly! Exit code: $($proc.ExitCode)"
            break
        }
        if ($proc.MainWindowHandle -ne [IntPtr]::Zero) {
            $hwnd = $proc.MainWindowHandle
            Write-Host "Found MainWindowHandle: $hwnd after $($i * 500) ms"
            break
        }
    }

    if ($hwnd -ne [IntPtr]::Zero) {
        # Give WinUI time to render its content
        Start-Sleep -Seconds 2

        $artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\aca4648a-7af8-48c3-9b8a-ae269a772d90"
        $outPath = "$artifactDir\datasphere_live_capture.png"
        $res = [WinDirectTester]::Capture($hwnd, $outPath)
        Write-Host "Capture result: $res"
    } else {
        Write-Host "Failed to find window handle!"
    }
} finally {
    if (-not $proc.HasExited) {
        Write-Host "Stopping test process..."
        $proc.Kill()
    }
}
