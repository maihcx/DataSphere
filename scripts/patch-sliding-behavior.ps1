$ErrorActionPreference = "Stop"

$behPath = "DataSphere\Controls\SlidingTabIndicatorBehavior.cs"
$text = [System.IO.File]::ReadAllText($behPath)

# Add FindFirstTabViewItemInTree before FindSelectedTabViewItemInTree
$findFirstMethod = @"
        /// <summary>
        /// Recursively searches the visual tree for the first <see cref="TabViewItem"/> container.
        /// </summary>
        /// <param name="root">The root visual element to start searching from.</param>
        /// <returns>The first <see cref="TabViewItem"/> encountered, or <c>null</c> if none found.</returns>
        private static TabViewItem? FindFirstTabViewItemInTree(DependencyObject root)
        {
            if (root is TabViewItem item)
            {
                return item;
            }

            int count = VisualTreeHelper.GetChildrenCount(root);
            for (int i = 0; i < count; i++)
            {
                DependencyObject child = VisualTreeHelper.GetChild(root, i);
                TabViewItem? result = FindFirstTabViewItemInTree(child);
                if (result != null)
                {
                    return result;
                }
            }

            return null;
        }

"@

$findSelectedDecl = "        private static TabViewItem? FindSelectedTabViewItemInTree(DependencyObject root)"
if (-not $text.Contains("private static TabViewItem? FindFirstTabViewItemInTree")) {
    $idx = $text.IndexOf($findSelectedDecl)
    if ($idx -ge 0) {
        $text = $text.Substring(0, $idx) + $findFirstMethod + $text.Substring($idx)
        Write-Host "Added FindFirstTabViewItemInTree."
    }
}

# Update FindActiveTabViewItem header fallback
$oldHeaderFallback = @"
            // Fallback when SelectedItem is null: search TabStripHeader for anchored header tab (Home or Connection)
            if (tabView.TabStripHeader is DependencyObject headerRoot)
            {
                TabViewItem? headerTab = FindSelectedTabViewItemInTree(headerRoot);
                if (headerTab != null && IsValidOnScreenTabItem(tabView, headerTab, null))
                {
                    return headerTab;
                }
            }
"@

$newHeaderFallback = @"
            // Fallback when SelectedItem is null: search TabStripHeader for anchored header tab (Home or Connection)
            if (tabView.TabStripHeader is DependencyObject headerRoot)
            {
                TabViewItem? headerTab = FindSelectedTabViewItemInTree(headerRoot);
                if (headerTab != null && IsValidOnScreenTabItem(tabView, headerTab, null))
                {
                    return headerTab;
                }

                TabViewItem? firstHeaderTab = FindFirstTabViewItemInTree(headerRoot);
                if (firstHeaderTab != null && IsValidOnScreenTabItem(tabView, firstHeaderTab, null))
                {
                    firstHeaderTab.IsSelected = true;
                    return firstHeaderTab;
                }
            }
"@

if ($text.Contains($oldHeaderFallback)) {
    $text = $text.Replace($oldHeaderFallback, $newHeaderFallback)
    Write-Host "Updated header fallback in FindActiveTabViewItem."
}

[System.IO.File]::WriteAllText($behPath, $text, [System.Text.Encoding]::UTF8)
Write-Host "SlidingTabIndicatorBehavior.cs patched."
