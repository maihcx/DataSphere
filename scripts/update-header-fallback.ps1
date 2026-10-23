$p = "DataSphere\Controls\SlidingTabIndicatorBehavior.cs"
$lines = [System.IO.File]::ReadAllLines($p)
$targetIdx = -1

for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i].Contains("if (headerTab != null && IsValidOnScreenTabItem(tabView, headerTab, null))")) {
        $targetIdx = $i
        break
    }
}

if ($targetIdx -ge 0) {
    # $targetIdx is "if (headerTab != null && IsValidOnScreenTabItem(tabView, headerTab, null))"
    # $targetIdx + 1 is "{"
    # $targetIdx + 2 is "return headerTab;"
    # $targetIdx + 3 is "}"
    # $targetIdx + 4 is "}" (end of if (tabView.TabStripHeader is DependencyObject headerRoot))
    $insertLines = @(
        "                TabViewItem? firstHeaderTab = FindFirstTabViewItemInTree(headerRoot);",
        "                if (firstHeaderTab != null && IsValidOnScreenTabItem(tabView, firstHeaderTab, null))",
        "                {",
        "                    firstHeaderTab.IsSelected = true;",
        "                    return firstHeaderTab;",
        "                }"
    )
    $newLines = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -le $targetIdx + 3; $i++) {
        $newLines.Add($lines[$i])
    }
    foreach ($line in $insertLines) {
        $newLines.Add($line)
    }
    for ($i = $targetIdx + 4; $i -lt $lines.Length; $i++) {
        $newLines.Add($lines[$i])
    }
    [System.IO.File]::WriteAllLines($p, $newLines, [System.Text.Encoding]::UTF8)
    Write-Host "Header fallback inserted successfully."
} else {
    Write-Host "Target not found."
}
