Add-Type -AssemblyName System.Drawing
$b = [System.Drawing.Bitmap]::FromFile('C:\Users\huynh\.gemini\antigravity\brain\82efb6f9-3dcc-4e7e-ac8a-04c9e2fa180f\04_verified_dialog_dark_smoke.png')
$d = $b.GetPixel(640, 200)
$o = $b.GetPixel(200, 400)
Write-Host "Dialog Background: $($d.R), $($d.G), $($d.B)"
Write-Host "Smoke: $($o.R), $($o.G), $($o.B)"
$b.Dispose()
