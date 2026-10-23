Add-Type -AssemblyName System.Drawing

$path = "D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule\verified_step4_connection_selected.png"
$img = [System.Drawing.Bitmap]::FromFile($path)

Write-Host "--- Checking Viewport in verified_step4_connection_selected.png (Y=300) ---"
# If localhost is active, there are database query tabs / object explorer / editor
# If Connection catalog is active, there is the Connection card list / tree
$whitePixels = 0
for ($x = 50; $x -lt 800; $x += 10) {
    for ($y = 200; $y -lt 400; $y += 10) {
        $p = $img.GetPixel($x, $y)
        if ($p.R -gt 180 -and $p.G -gt 180 -and $p.B -gt 180) {
            $whitePixels++
        }
    }
}
Write-Host ("White pixels in viewport: {0}" -f $whitePixels)
$img.Dispose()
