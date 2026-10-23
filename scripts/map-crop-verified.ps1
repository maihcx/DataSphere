Add-Type -AssemblyName System.Drawing

$img = [System.Drawing.Bitmap]::FromFile("D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule\crop_verified_tabs.png")
Write-Host ("Size: {0}x{1}" -f $img.Width, $img.Height)

for ($y = 60; $y -le 105; $y += 3) {
    $line = ""
    for ($x = 0; $x -lt 350; $x += 5) {
        $p = $img.GetPixel($x, $y)
        if ($p.R -gt 150 -and $p.G -gt 150 -and $p.B -gt 150) {
            $line += "T" # Text
        } elseif (($p.R -ge 34 -and $p.R -le 55) -and ($p.G -ge 10 -and $p.G -le 55) -and ($p.B -ge 10 -and $p.B -le 55) -and ($p.R -gt 36 -or $p.G -gt 36)) {
            $line += "C" # Capsule
        } else {
            $line += "."
        }
    }
    Write-Host ("Y={0:D3}: {1}" -f $y, $line)
}

$img.Dispose()
