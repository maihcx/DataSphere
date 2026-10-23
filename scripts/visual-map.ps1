Add-Type -AssemblyName System.Drawing

$img = [System.Drawing.Bitmap]::FromFile("D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule\diag_step4_after_clicking_connection_in_new_win.png")
Write-Host "New window size: $($img.Width)x$($img.Height)"

# Let's crop the tab strip area of the new window
# Top row is titlebar tabs (Y: 0 to 60)
# Second row is inner tabs (Y: 50 to 120)
# Let's check non-dark pixels in Y: 50 to 110, X: 0 to 600
for ($y = 55; $y -lt 110; $y += 3) {
    $line = ""
    for ($x = 0; $x -lt 400; $x += 5) {
        $p = $img.GetPixel($x, $y)
        # Check text color (white/gray text has R > 150, G > 150, B > 150)
        if ($p.R -gt 150 -and $p.G -gt 150 -and $p.B -gt 150) {
            $line += "T"
        } elseif ($p.R -ge 35 -and $p.R -le 45 -and $p.G -ge 20 -and $p.G -le 32) {
            $line += "C" # Capsule
        } else {
            $line += "."
        }
    }
    Write-Host ("Y={0:D3}: {1}" -f $y, $line)
}

$img.Dispose()
