$p = "DataSphere\Controls\SlidingTabIndicatorBehavior.cs"
$text = [System.IO.File]::ReadAllText($p)

# In UpdateVisualsPosition, add logging right after selectedTab is resolved
$targetSearch = "TabViewItem? selectedTab = FindActiveTabViewItem(tabView);"
$loggingCode = @"
            TabViewItem? selectedTab = FindActiveTabViewItem(tabView);
            try
            {
                string log = $"[UpdatePos] TabView={tabView.Name}, Retry={retryCount}, SelItem={tabView.SelectedItem}, SelTab={(selectedTab != null ? selectedTab.Header : "null")}\n";
                System.IO.File.AppendAllText(@"C:\Users\huynh\.gemini\antigravity\brain\bed6b624-6a96-45dd-963c-7b8ea009ac6a\behavior.log", log);
            }
            catch { }
"@

if ($text.Contains($targetSearch) -and -not $text.Contains("behavior.log")) {
    $text = $text.Replace($targetSearch, $loggingCode)
}

# In catch (Exception ex) of UpdateVisualsPosition, log exception
$targetCatch = @"
            catch
            {
                indicator.IsVisible = false;
            }
"@

$replacementCatch = @"
            catch (Exception ex)
            {
                try
                {
                    System.IO.File.AppendAllText(@"C:\Users\huynh\.gemini\antigravity\brain\bed6b624-6a96-45dd-963c-7b8ea009ac6a\behavior.log", $"[EXCEPTION in UpdateVisualsPosition] {ex}\n");
                }
                catch { }
                indicator.IsVisible = false;
            }
"@

if ($text.Contains($targetCatch)) {
    $text = $text.Replace($targetCatch, $replacementCatch)
}

[System.IO.File]::WriteAllText($p, $text, [System.Text.Encoding]::UTF8)
Write-Host "Behavior logging added."
