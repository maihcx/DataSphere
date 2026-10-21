$files = @(
    'DataSphere\Controls\VirtualTable\VirtualTableRowPool.cs',
    'DataSphere\Controls\VirtualTable\VirtualTable.xaml.cs'
)
foreach ($f in $files) {
    $c = [System.IO.File]::ReadAllText($f)
    $c = $c -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($f, $c, [System.Text.Encoding]::UTF8)
}
Write-Host 'Converted to LF.'
