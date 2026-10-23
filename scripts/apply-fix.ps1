$ErrorActionPreference = "Stop"

# 1. Update DatabasePage.xaml
$dbXamlPath = "DataSphere\Views\Pages\DatabaseGroup\DatabasePage.xaml"
$dbXaml = [System.IO.File]::ReadAllText($dbXamlPath)

# Remove the wrapping Border around InnerTabView
$targetBorderStart = @"
            <Border Grid.Row="0"
                    CornerRadius="6"
                    Background="{ThemeResource CardBackgroundFillColorDefaultBrush}">
                <TabView x:Name="InnerTabView"
"@

$replacementTabView = @"
            <TabView Grid.Row="0"
                     x:Name="InnerTabView"
"@

if ($dbXaml.Contains($targetBorderStart)) {
    $dbXaml = $dbXaml.Replace($targetBorderStart, $replacementTabView)
    $dbXaml = $dbXaml.Replace("                </TabView>`r`n            </Border>", "            </TabView>")
    $dbXaml = $dbXaml.Replace("                </TabView>`n            </Border>", "            </TabView>")
    [System.IO.File]::WriteAllText($dbXamlPath, $dbXaml, [System.Text.Encoding]::UTF8)
    Write-Host "DatabasePage.xaml updated."
} else {
    Write-Host "DatabasePage.xaml targetBorderStart not found, checking if already updated..."
}

# 2. Update DatabasePage.xaml.cs
$dbCsPath = "DataSphere\Views\Pages\DatabaseGroup\DatabasePage.xaml.cs"
$dbCs = [System.IO.File]::ReadAllText($dbCsPath)

$targetSync = @"
            // Synchronize selection: deselect dynamic tabs when Connection tab is selected
            ViewModel.PropertyChanged += (s, e) =>
            {
                if (e.PropertyName == nameof(DatabaseViewModel.IsConnectionSelected) && ViewModel.IsConnectionSelected)
                {
                    InnerTabView.SelectedItem = null;
                }
            };
"@

$replacementSync = @"
            // Synchronize selection: deselect dynamic tabs when Connection tab is selected
            ViewModel.PropertyChanged += (s, e) =>
            {
                if (e.PropertyName == nameof(DatabaseViewModel.IsConnectionSelected) && ViewModel.IsConnectionSelected)
                {
                    InnerTabView.SelectedItem = null;
                    Controls.SlidingTabIndicatorBehavior.UpdatePosition(InnerTabView, animate: true);
                }
            };
"@

$targetTap = @"
        private void OnConnectionTabTapped(object sender, TappedRoutedEventArgs e)
        {
            ViewModel.SelectConnectionCommand.Execute(null);
            InnerTabView.SelectedItem = null;
        }
"@

$replacementTap = @"
        private void OnConnectionTabTapped(object sender, TappedRoutedEventArgs e)
        {
            ViewModel.SelectConnectionCommand.Execute(null);
            InnerTabView.SelectedItem = null;
            Controls.SlidingTabIndicatorBehavior.UpdatePosition(InnerTabView, animate: true);
        }
"@

if ($dbCs.Contains($targetSync)) {
    $dbCs = $dbCs.Replace($targetSync, $replacementSync)
}
if ($dbCs.Contains($targetTap)) {
    $dbCs = $dbCs.Replace($targetTap, $replacementTap)
}
[System.IO.File]::WriteAllText($dbCsPath, $dbCs, [System.Text.Encoding]::UTF8)
Write-Host "DatabasePage.xaml.cs updated."

# 3. Update ShellWindow.xaml.cs
$shellCsPath = "DataSphere\Views\Windows\ShellWindow.xaml.cs"
$shellCs = [System.IO.File]::ReadAllText($shellCsPath)

$targetHomeSync = @"
            // Deselect dynamic tabs in ShellTabView whenever Home is selected
            ViewModel.PropertyChanged += (s, e) =>
            {
                if (e.PropertyName == nameof(ShellViewModel.IsHomeSelected))
                {
                    if (ViewModel.IsHomeSelected)
                    {
                        ShellTabView.SelectedItem = null;
                    }
                }
            };
"@

$replacementHomeSync = @"
            // Deselect dynamic tabs in ShellTabView whenever Home is selected
            ViewModel.PropertyChanged += (s, e) =>
            {
                if (e.PropertyName == nameof(ShellViewModel.IsHomeSelected))
                {
                    if (ViewModel.IsHomeSelected)
                    {
                        ShellTabView.SelectedItem = null;
                        Controls.SlidingTabIndicatorBehavior.UpdatePosition(ShellTabView, animate: true);
                    }
                }
            };
"@

$targetHomeTap = @"
        private void OnHomeTabTapped(object sender, TappedRoutedEventArgs e)
        {
            ViewModel.SelectHomeCommand.Execute(null);
            ShellTabView.SelectedItem = null;
        }
"@

$replacementHomeTap = @"
        private void OnHomeTabTapped(object sender, TappedRoutedEventArgs e)
        {
            ViewModel.SelectHomeCommand.Execute(null);
            ShellTabView.SelectedItem = null;
            Controls.SlidingTabIndicatorBehavior.UpdatePosition(ShellTabView, animate: true);
        }
"@

if ($shellCs.Contains($targetHomeSync)) {
    $shellCs = $shellCs.Replace($targetHomeSync, $replacementHomeSync)
}
if ($shellCs.Contains($targetHomeTap)) {
    $shellCs = $shellCs.Replace($targetHomeTap, $replacementHomeTap)
}
[System.IO.File]::WriteAllText($shellCsPath, $shellCs, [System.Text.Encoding]::UTF8)
Write-Host "ShellWindow.xaml.cs updated."
