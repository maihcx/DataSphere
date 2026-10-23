Add-Type -AssemblyName System.Drawing

function FindCapsuleInImage($path) {
    if (!(Test-Path $path)) { return }
    $img = [System.Drawing.Bitmap]::FromFile($path)
    Write-Host "--- Scanning $path ($($img.Width)x$($img.Height)) ---"

    # Search for the capsule fill/border in Y range 40..160
    # In dark theme, CardBackgroundFillColorDefaultBrush is typically RGB(39, 25-26, 68-70) or similar,
    # or let's look for pixels with R around 35-45, G around 20-30, B around 60-75
    $minX = 9999; $maxX = -1; $minY = 9999; $maxY = -1
    $foundCount = 0

    for ($y = 40; $y -lt [Math]::Min(200, $img.Height); $y++) {
        for ($x = 0; $x -lt [Math]::Min(600, $img.Width); $x++) {
            $p = $img.GetPixel($x, $y)
            # Capsule color check
            if ($p.R -ge 35 -and $p.R -le 45 -and $p.G -ge 20 -and $p.G -le 32 -and $p.B -ge 60 -and $p.B -le 75) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
                $foundCount++
            }
        }
    }

    if ($foundCount -gt 50) {
        Write-Host "Found Capsule: X=$minX..$maxX (Width=$($maxX - $minX)), Y=$minY..$maxY (Height=$($maxY - $minY)), Count=$foundCount"
    } else {
        Write-Host "Capsule not found with primary color filter (foundCount=$foundCount)"
    }
    $img.Dispose()
}

FindCapsuleInImage "D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule\diag_step1_db_page.png"
FindCapsuleInImage "D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule\diag_step2_connection_opened.png"
FindCapsuleInImage "D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule\diag_step3_win_0.png"
FindCapsuleInImage "D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule\diag_step4_after_clicking_connection_in_new_win.png"
