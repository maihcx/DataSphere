Add-Type -AssemblyName System.Drawing

$p1 = "D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule\diag_step1_db_page.png"
$img1 = [System.Drawing.Bitmap]::FromFile($p1)

Write-Host "--- diag_step1_db_page.png (when Connection tab is selected initially) ---"
for ($x = 20; $x -le 280; $x += 15) {
    $p = $img1.GetPixel($x, 75)
    Write-Host ("X={0:D3}: RGB({1},{2},{3})" -f $x, $p.R, $p.G, $p.B)
}

$img1.Dispose()
