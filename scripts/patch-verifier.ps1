$p = "scripts\reproduce-and-verify.ps1"
$text = [System.IO.File]::ReadAllText($p)

$targetClick = @"
                    int cx = (int)(r.X + r.Width / 2);
                    int cy = (int)(r.Y + r.Height / 2);
                    Console.WriteLine("Clicking Connection Tab at X=" + cx + " Y=" + cy);
                    PhysicalLeftClick(cx, cy);
"@

$replacementClick = @"
                    try {
                        var selPattern = (SelectionItemPattern)connTab.GetCurrentPattern(SelectionItemPattern.Pattern);
                        selPattern.Select();
                        Console.WriteLine("SelectionItemPattern.Select() succeeded");
                    } catch (Exception ex) {
                        Console.WriteLine("SelectionItemPattern failed: " + ex.Message);
                    }
                    int cx = (int)(r.X + r.Width / 2);
                    int cy = (int)(r.Y + r.Height / 2);
                    Console.WriteLine("Clicking Connection Tab at X=" + cx + " Y=" + cy);
                    PhysicalLeftClick(cx, cy);
"@

if ($text.Contains($targetClick)) {
    $text = $text.Replace($targetClick, $replacementClick)
}

[System.IO.File]::WriteAllText($p, $text, [System.Text.Encoding]::UTF8)
Write-Host "reproduce-and-verify.ps1 updated."
