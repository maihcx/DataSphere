Add-Type -AssemblyName System.Drawing

$img = [System.Drawing.Bitmap]::FromFile("D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule\diag_step3_win_0.png")
Write-Host ("Image size: {0}x{1}" -f $img.Width, $img.Height)

# Scan horizontal and vertical slices to find bright white or gray text pixels
for ($y = 0; $y -lt 150; $y += 5) {
    $line = ""
    for ($x = 0; $x -lt 600; $x += 10) {
        $p = $img.GetPixel($x, $y)
        if ($p.R -gt 150 -and $p.G -gt 150 -and $p.B -gt 150) {
            $line += "T"
        } else {
            $line += "."
        }
    }
    if ($line.Contains("T")) {
        Write-Host ("Y={0:D3}: {1}" -f $y, $line)
    }
}
$img.Dispose()
