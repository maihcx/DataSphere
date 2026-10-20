Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile("C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363\bug_scrollbar_fixed_initial.png")
Write-Host "Width=$($bmp.Width), Height=$($bmp.Height)"

# Find dark pixels or colored pixels in the right half of the image (X > 300)
$darkCount = 0
for ($y = 50; $y -lt $bmp.Height - 50; $y += 5) {
    for ($x = 300; $x -lt $bmp.Width; $x += 5) {
        $c = $bmp.GetPixel($x, $y)
        # Text/border is typically darker (e.g. brightness < 0.8)
        if ($c.R -lt 150 -or $c.G -lt 150 -or $c.B -lt 150) {
            $darkCount++
            if ($darkCount -le 25) {
                Write-Host "Dark pixel at ($x, $y): R=$($c.R), G=$($c.G), B=$($c.B)"
            }
        }
    }
}
Write-Host "Total dark pixels sampled in right area: $darkCount"
$bmp.Dispose()
