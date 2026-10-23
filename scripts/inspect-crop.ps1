Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Bitmap]::FromFile("D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule\diag_step4_cropped_tabs.png")

Write-Host "Width: $($img.Width), Height: $($img.Height)"

# In Dark/Light theme, let's scan horizontal slices around Y=30 to Y=120
# Let's inspect rows around the shell tabs (row 0) and inner tabs (row 1)
for ($y = 40; $y -lt 120; $y += 5) {
    $line = ""
    for ($x = 20; $x -lt 500; $x += 10) {
        $p = $img.GetPixel($x, $y)
        if ($p.R -gt 50 -or $p.G -gt 50 -or $p.B -gt 50) {
            $line += "#"
        } else {
            $line += "."
        }
    }
    Write-Host ("Y={0:D3}: {1}" -f $y, $line)
}

$img.Dispose()
