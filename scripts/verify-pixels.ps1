Add-Type -AssemblyName System.Drawing
$dir = 'd:\DEV\WinUI\DataSphere\.specify\bugs\tab-selection-background-not-updated-on-close'
$bmp = [System.Drawing.Bitmap]::FromFile("$dir\step4_after_closing_database_tab.png")

Write-Host "Checking Step 4 image pixels across tab header row (Y=20):"
for ($x = 20; $x -le 400; $x += 20) {
    $c = $bmp.GetPixel($x, 20)
    Write-Host ("X={0}: ({1},{2},{3})" -f $x, $c.R, $c.G, $c.B)
}

$bmp.Dispose()
