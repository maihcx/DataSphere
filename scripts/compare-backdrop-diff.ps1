Add-Type -AssemblyName System.Drawing
$f1 = 'C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363\winui_backdrop_tabbed.png'
$f2 = 'C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363\winui_backdrop_acrylic.png'
$f3 = 'C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363\winui_backdrop_solid.png'

$b1 = [System.Drawing.Bitmap]::FromFile($f1)
$b2 = [System.Drawing.Bitmap]::FromFile($f2)
$b3 = [System.Drawing.Bitmap]::FromFile($f3)

function DiffBitmaps($a, $b, $name) {
    $diff = 0
    $total = [int]($a.Width * $a.Height)
    for ($x = 0; $x -lt $a.Width; $x += 4) {
        for ($y = 0; $y -lt $a.Height; $y += 4) {
            $c1 = $a.GetPixel($x, $y)
            $c2 = $b.GetPixel($x, $y)
            if ($c1.ToArgb() -ne $c2.ToArgb()) {
                $diff++
            }
        }
    }
    $sampledTotal = ($a.Width / 4) * ($a.Height / 4)
    $pct = [Math]::Round(($diff / $sampledTotal) * 100, 2)
    Write-Host "$name Diff: $diff / $sampledTotal sampled pixels ($pct %)"
}

DiffBitmaps $b1 $b2 "Tabbed vs Acrylic"
DiffBitmaps $b1 $b3 "Tabbed vs Solid"
DiffBitmaps $b2 $b3 "Acrylic vs Solid"

$b1.Dispose()
$b2.Dispose()
$b3.Dispose()
