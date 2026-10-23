Add-Type -AssemblyName System.Drawing

$src = "D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule\verified_step4_connection_selected.png"
$dst = "D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule\crop_verified_tabs.png"

$img = [System.Drawing.Bitmap]::FromFile($src)
$rect = New-Object System.Drawing.Rectangle(0, 0, 500, 150)
$cropped = $img.Clone($rect, $img.PixelFormat)
$cropped.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)

$cropped.Dispose()
$img.Dispose()
Write-Host "Cropped tabs saved to $dst"
