Add-Type -AssemblyName System.Drawing
$fullPath = Resolve-Path ".specify\bugs\inner-tab-tearoff-stale-capsule\diag_step4_after_clicking_connection_in_new_win.png"
$img = [System.Drawing.Bitmap]::FromFile($fullPath)
$rect = New-Object System.Drawing.Rectangle(0, 0, [Math]::Min(1200, $img.Width), 250)
$crop = $img.Clone($rect, $img.PixelFormat)
$outPath = Join-Path (Split-Path $fullPath) "diag_step4_cropped_tabs.png"
$crop.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$img.Dispose()
$crop.Dispose()
Write-Host "Cropped saved to $outPath"

$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\bed6b624-6a96-45dd-963c-7b8ea009ac6a"
Copy-Item $outPath -Destination $artifactDir -Force
Write-Host "Copied to artifact dir"
