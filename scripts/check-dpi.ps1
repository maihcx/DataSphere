Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Write-Host "Primary screen bounds: $([System.Windows.Forms.Screen]::PrimaryScreen.Bounds)"
Write-Host "Primary screen working area: $([System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea)"
$g = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
Write-Host "DpiX: $($g.DpiX), DpiY: $($g.DpiY)"
$scale = $g.DpiX / 96.0
Write-Host "Scale factor: $scale"
$g.Dispose()
