Add-Type -AssemblyName System.Drawing

$p0 = "D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule\diag_step3_win_0.png"
$p1 = "D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule\diag_step3_win_1.png"

$i0 = [System.Drawing.Bitmap]::FromFile($p0)
Write-Host ("Img0: {0}x{1}" -f $i0.Width, $i0.Height)

$i1 = [System.Drawing.Bitmap]::FromFile($p1)
Write-Host ("Img1: {0}x{1}" -f $i1.Width, $i1.Height)

$i0.Dispose()
$i1.Dispose()
