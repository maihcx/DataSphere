$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Automation;

public class ScrollPatternInspector {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseDesktop(IntPtr hDesktop);

    public static string Inspect(string imagePath) {
        // Inspect the image on the right edge (X between 950 and 1029, Y between 300 and 700)
        string log = "";
        using (var bmp = new Bitmap(imagePath)) {
            log += string.Format("Image size: {0}x{1}\n", bmp.Width, bmp.Height);
            int scrollbarX = bmp.Width - 15;
            log += string.Format("Sampling vertical column at X={0} (right edge):\n", scrollbarX);
            for (int y = 200; y < bmp.Height - 50; y += 30) {
                var c = bmp.GetPixel(scrollbarX, y);
                log += string.Format("  Y={0}: R={1} G={2} B={3}\n", y, c.R, c.G, c.B);
            }
        }
        return log;
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies WindowsBase, UIAutomationClient, UIAutomationTypes, System.Drawing
$imagePath = "C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363\bug_scrollbar_fixed_initial.png"
[ScrollPatternInspector]::Inspect($imagePath)
