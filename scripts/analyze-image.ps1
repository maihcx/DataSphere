Add-Type -AssemblyName System.Drawing

$img = [System.Drawing.Bitmap]::FromFile("C:\Users\huynh\.gemini\antigravity\brain\aca4648a-7af8-48c3-9b8a-ae269a772d90\datasphere_live_capture.png")
Write-Host "Image size: $($img.Width) x $($img.Height)"

$nonZero = 0
$samples = 0
$colors = @{}

for ($x = 0; $x -lt $img.Width; $x += 10) {
    for ($y = 0; $y -lt $img.Height; $y += 10) {
        $pixel = $img.GetPixel($x, $y)
        $samples++
        $key = "$($pixel.R),$($pixel.G),$($pixel.B)"
        if ($colors.ContainsKey($key)) {
            $colors[$key]++
        } else {
            $colors[$key] = 1
        }
        if ($pixel.R -ne 0 -or $pixel.G -ne 0 -or $pixel.B -ne 0) {
            $nonZero++
        }
    }
}
$img.Dispose()

Write-Host "Sampled $samples pixels. Non-black pixels: $nonZero"
Write-Host "Top colors:"
$colors.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5 | ForEach-Object {
    Write-Host "  RGB($($_.Key)): $($_.Value) pixels"
}
