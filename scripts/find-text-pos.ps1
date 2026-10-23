Add-Type -AssemblyName System.Drawing

$img = [System.Drawing.Bitmap]::FromFile("D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule\diag_step3_win_1.png")
Write-Host "New window size: $($img.Width)x$($img.Height)"

# In diag_step3_win_0.png, where are the non-black pixels?
# Let's search Y: 40 to 150 for text pixels (white/light gray)
for ($y = 40; $y -lt 150; $y += 5) {
    $line = ""
    for ($x = 0; $x -lt 400; $x += 10) {
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
