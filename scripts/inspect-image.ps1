Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile('C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363\bug_scrollbar_fixed_initial.png')
Write-Host "Width: $($bmp.Width), Height: $($bmp.Height)"
for ($y = 100; $y -lt $bmp.Height; $y += 100) {
    for ($x = 400; $x -lt $bmp.Width; $x += 200) {
        $c = $bmp.GetPixel($x, $y)
        Write-Host "($x, $y): R=$($c.R) G=$($c.G) B=$($c.B)"
    }
}
$bmp.Dispose()
