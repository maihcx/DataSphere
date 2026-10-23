Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Bitmap]::FromFile("D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule\diag_step4_cropped_tabs.png")

# Let's inspect Y=75 (middle of inner tab bar) across X=20 to 500
Write-Host "Inner tab row Y=75:"
for ($x = 20; $x -lt 500; $x += 15) {
    $p = $img.GetPixel($x, 75)
    Write-Host ("X={0:D3}: RGB({1},{2},{3})" -f $x, $p.R, $p.G, $p.B)
}

$img.Dispose()
