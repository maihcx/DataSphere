using System;
using System.Drawing;

class ImageInspector {
    static void Main() {
        string path = @"C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363\bug_fixed_milestone1_database_expanded_tables_collapsed.png";
        using (var bmp = new Bitmap(path)) {
            Console.WriteLine($"Image size: {bmp.Width}x{bmp.Height}");
            // Look around X=200..300, Y=350..380 to find non-background pixels (where the chevron is)
            Color bg = bmp.GetPixel(200, 368);
            Console.WriteLine($"Background color at (200, 368): {bg}");
            
            for (int y = 355; y <= 375; y += 2) {
                string row = $"Y={y}: ";
                for (int x = 210; x <= 300; x += 3) {
                    Color c = bmp.GetPixel(x, y);
                    bool isDiff = Math.Abs(c.R - bg.R) > 20 || Math.Abs(c.G - bg.G) > 20 || Math.Abs(c.B - bg.B) > 20;
                    row += isDiff ? "#" : ".";
                }
                Console.WriteLine(row);
            }
        }
    }
}
