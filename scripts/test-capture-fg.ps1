Add-Type @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;

public class ForegroundCapturer {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseDesktop(IntPtr hDesktop);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

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

    public static string Capture(string outPath) {
        string res = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) {
                res = "OpenDesktop failed: " + Marshal.GetLastWin32Error();
                return;
            }

            SetThreadDesktop(hDesk);
            IntPtr fg = GetForegroundWindow();
            if (fg == IntPtr.Zero) {
                res = "No foreground window.";
                CloseDesktop(hDesk);
                return;
            }

            RECT r;
            GetWindowRect(fg, out r);
            int w = r.Right - r.Left;
            int h = r.Bottom - r.Top;

            if (w <= 0 || h <= 0) {
                res = "Invalid rect: " + w + "x" + h;
                CloseDesktop(hDesk);
                return;
            }

            using (Bitmap bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb)) {
                using (Graphics g = Graphics.FromImage(bmp)) {
                    IntPtr hdc = g.GetHdc();
                    PrintWindow(fg, hdc, 2);
                    g.ReleaseHdc(hdc);
                }
                bmp.Save(outPath, ImageFormat.Png);
            }

            res = "SAVED: " + outPath + " (HWND=" + fg + ", " + w + "x" + h + ")";
            CloseDesktop(hDesk);
        });

        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join();
        return res;
    }
}
'@ -ReferencedAssemblies System.Drawing

$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\aca4648a-7af8-48c3-9b8a-ae269a772d90"
$snapPath = "$artifactDir\verification_visual_evidence.png"
$res = [ForegroundCapturer]::Capture($snapPath)
Write-Host $res
