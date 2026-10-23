$path = "DataSphere\Controls\SlidingTabIndicatorBehavior.cs"
$bytes = [System.IO.File]::ReadAllBytes($path)
$text = [System.Text.Encoding]::UTF8.GetString($bytes)
Write-Host "File length: $($text.Length)"
$idx = $text.LastIndexOf("catch")
Write-Host "Last catch index: $idx"
if ($idx -ge 0) {
    $snippet = $text.Substring($idx, [Math]::Min(100, $text.Length - $idx))
    Write-Host "Snippet bytes:"
    [System.Text.Encoding]::UTF8.GetBytes($snippet) | ForEach-Object { "$_ " } | Out-String | Write-Host
}
