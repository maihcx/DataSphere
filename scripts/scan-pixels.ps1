Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile('C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363\bug_fixed_milestone1_database_expanded_tables_collapsed.png')
$bg = $bmp.GetPixel(200, 368)
Write-Host "Background color: $bg"
355..375 | ForEach-Object {
    $y = $_
    $row = "Y=$y : "
    210..310 | ForEach-Object {
        $x = $_
        if ($x % 3 -eq 0) {
            $c = $bmp.GetPixel($x, $y)
            if ([Math]::Abs($c.R - $bg.R) -gt 25) { $row += "#" } else { $row += "." }
        }
    }
    Write-Host $row
}
$bmp.Dispose()
