$p1 = "DataSphere\Views\Pages\DatabaseGroup\DatabasePage.xaml.cs"
$c1 = [System.IO.File]::ReadAllText($p1)

$idx = $c1.IndexOf("private void OnConnectionTabTapped(object sender, TappedRoutedEventArgs e)")
if ($idx -ge 0) {
    $braceIdx = $c1.IndexOf("{", $idx)
    $inject = "`r`n            try { System.IO.File.AppendAllText(@`"C:\Users\huynh\.gemini\antigravity\brain\bed6b624-6a96-45dd-963c-7b8ea009ac6a\debug.log`", `"[OnConnectionTabTapped fired!]`r`n`"); } catch { }"
    $c1 = $c1.Substring(0, $braceIdx + 1) + $inject + $c1.Substring($braceIdx + 1)
    [System.IO.File]::WriteAllText($p1, $c1)
    Write-Host "Updated DatabasePage.xaml.cs"
} else {
    Write-Host "OnConnectionTabTapped not found"
}

$p2 = "DataSphere\ViewModels\Pages\DatabaseGroup\DatabaseViewModel.cs"
$c2 = [System.IO.File]::ReadAllText($p2)
$idx2 = $c2.IndexOf("public void SelectConnection()")
if ($idx2 -ge 0) {
    $braceIdx2 = $c2.IndexOf("{", $idx2)
    $inject2 = "`r`n            try { System.IO.File.AppendAllText(@`"C:\Users\huynh\.gemini\antigravity\brain\bed6b624-6a96-45dd-963c-7b8ea009ac6a\debug.log`", `"[SelectConnectionCommand executed!]`r`n`"); } catch { }"
    $c2 = $c2.Substring(0, $braceIdx2 + 1) + $inject2 + $c2.Substring($braceIdx2 + 1)
    [System.IO.File]::WriteAllText($p2, $c2)
    Write-Host "Updated DatabaseViewModel.cs"
} else {
    Write-Host "SelectConnection not found"
}
