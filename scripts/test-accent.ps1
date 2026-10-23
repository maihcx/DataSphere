$source = @"
using System;
using Windows.UI.ViewManagement;
using Windows.UI;

public class Diag {
    public static void Test() {
        try {
            UISettings s = new UISettings();
            Color c = s.GetColorValue(UIColorType.Accent);
            Console.WriteLine("Accent: " + c.A + "," + c.R + "," + c.G + "," + c.B);
        } catch (Exception ex) {
            Console.WriteLine("Error: " + ex.Message);
        }
    }
}
"@
Add-Type -TypeDefinition $source
[Diag]::Test()
