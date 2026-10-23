Add-Type -AssemblyName System.Drawing

$path = "D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule\verified_step4_connection_selected.png"
$img = [System.Drawing.Bitmap]::FromFile($path)
Write-Host ("Image size: {0}x{1}" -f $img.Width, $img.Height)

Write-Host "--- Scanning row Y=75 across X=20 to 300 in verified_step4_connection_selected.png ---"
for ($x = 20; $x -le 280; $x += 15) {
    $p = $img.GetPixel($x, 75)
    Write-Host ("X={0:D3}: RGB({1},{2},{3})" -f $x, $p.R, $p.G, $p.B)
}

Write-Host "--- Scanning row Y=80 across X=20 to 300 in verified_step4_connection_selected.png ---"
for ($x = 20; $x -le 280; $x += 15) {
    $p = $img.GetPixel($x, 80)
    Write-Host ("X={0:D3}: RGB({1},{2},{3})" -f $x, $p.R, $p.G, $p.B)
}

$img.Dispose()
