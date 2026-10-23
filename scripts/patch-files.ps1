$ErrorActionPreference = "Stop"

# 1. Update ShellWindow.xaml.cs
$shellCsPath = "DataSphere\Views\Windows\ShellWindow.xaml.cs"
$shellLines = [System.IO.File]::ReadAllLines($shellCsPath)

for ($i = 0; $i -lt $shellLines.Length; $i++) {
    if ($shellLines[$i].Trim() -eq "if (ViewModel.IsHomeSelected)") {
        if ($shellLines[$i + 1].Trim() -eq "{") {
            if ($shellLines[$i + 2].Trim() -eq "ShellTabView.SelectedItem = null;") {
                $indent = "                        "
                $shellLines[$i + 2] = $indent + "ShellTabView.SelectedItem = null;`r`n" + $indent + "SlidingTabIndicatorBehavior.UpdatePosition(ShellTabView, animate: true);"
            }
        }
    }
    if ($shellLines[$i].Trim() -eq "private void OnHomeTabTapped(object sender, TappedRoutedEventArgs e)") {
        for ($j = $i; $j -lt $i + 10; $j++) {
            if ($shellLines[$j].Trim() -eq "ShellTabView.SelectedItem = null;") {
                $indent = "            "
                $shellLines[$j] = $indent + "ShellTabView.SelectedItem = null;`r`n" + $indent + "SlidingTabIndicatorBehavior.UpdatePosition(ShellTabView, animate: true);"
                break
            }
        }
    }
}
[System.IO.File]::WriteAllText($shellCsPath, ($shellLines -join "`r`n") + "`r`n", [System.Text.Encoding]::UTF8)
Write-Host "ShellWindow.xaml.cs patched."

# 2. Update SlidingTabIndicatorBehavior.cs
$behPath = "DataSphere\Controls\SlidingTabIndicatorBehavior.cs"
$behText = [System.IO.File]::ReadAllText($behPath)

# 2a. Add UpdatePosition method after SetIsIndicatorVisible
$updatePosMethod = @"
        /// <summary>
        /// Explicitly triggers a position update and layout recalculation for the sliding tab indicator.
        /// Useful when anchored header tabs (such as Home or Connection) change selection outside of TabItemsSource.
        /// </summary>
        /// <param name="tabView">The host <see cref="TabView"/> control.</param>
        /// <param name="animate"><c>true</c> to animate transition; otherwise <c>false</c>.</param>
        public static void UpdatePosition(TabView tabView, bool animate = true)
        {
            if (tabView != null && tabView.IsLoaded)
            {
                ScheduleTransitionSettleUpdates(tabView);
            }
        }
"@

if (-not $behText.Contains("public static void UpdatePosition")) {
    $targetMethod = "public static void SetIsIndicatorVisible(DependencyObject obj, bool value)"
    $idx = $behText.IndexOf($targetMethod)
    if ($idx -ge 0) {
        $closeBraceIdx = $behText.IndexOf("}", $idx)
        if ($closeBraceIdx -ge 0) {
            $insertPos = $closeBraceIdx + 1
            $behText = $behText.Substring(0, $insertPos) + "`r`n`r`n" + $updatePosMethod + $behText.Substring($insertPos)
            Write-Host "Added UpdatePosition method."
        }
    }
}

# 2b. Replace InitializeVisuals and RemoveVisuals
$oldInitAndRemoveStart = "        private static void InitializeVisuals(TabView tabView)"
$oldInitAndRemoveEnd = "        private static void UpdateVisualsBrush(TabView tabView)"
$idxInit = $behText.IndexOf($oldInitAndRemoveStart)
$idxBrush = $behText.IndexOf($oldInitAndRemoveEnd)

$newInitAndRemove = @"
        private static void InitializeVisuals(TabView tabView)
        {
            try
            {
                ContainerVisual containerVisual = (ContainerVisual)ElementCompositionPreview.GetElementVisual(tabView);
                Compositor compositor = containerVisual.Compositor;

                ShapeVisual? existingIndicator = GetIndicatorVisual(tabView);
                if (existingIndicator != null)
                {
                    // Check if existing indicator belongs to the same compositor (same window)
                    if (existingIndicator.Compositor == compositor)
                    {
                        UpdateVisualsPosition(tabView, animate: false);
                        return;
                    }

                    // Stale indicator from a previous window/compositor; clean it up
                    RemoveVisuals(tabView);
                }

                // Sliding Accent Pill Indicator Visual (Dynamic width with rounded ends)
                CompositionRoundedRectangleGeometry pillGeometry = compositor.CreateRoundedRectangleGeometry();
                pillGeometry.CornerRadius = new Vector2(TabMotionConfiguration.IndicatorCornerRadius, TabMotionConfiguration.IndicatorCornerRadius);
                pillGeometry.Size = new Vector2(TabMotionConfiguration.IndicatorWidth, TabMotionConfiguration.IndicatorHeight);

                CompositionSpriteShape pillShape = compositor.CreateSpriteShape(pillGeometry);
                pillShape.FillBrush = compositor.CreateColorBrush(GetAccentColor(tabView));

                ShapeVisual indicatorVisual = compositor.CreateShapeVisual();
                indicatorVisual.Shapes.Add(pillShape);
                indicatorVisual.Size = new Vector2(TabMotionConfiguration.IndicatorWidth, TabMotionConfiguration.IndicatorHeight);

                containerVisual.Children.InsertAtTop(indicatorVisual);

                SetIndicatorVisual(tabView, indicatorVisual);
                SetIndicatorShape(tabView, pillShape);
                SetIndicatorGeometry(tabView, pillGeometry);

                FrameworkElement? bgCapsule = GetBackgroundCapsule(tabView);
                if (bgCapsule != null)
                {
                    ElementCompositionPreview.SetIsTranslationEnabled(bgCapsule, true);
                }

                UpdateVisualsPosition(tabView, animate: false);
            }
            catch
            {
                // Graceful fallback if composition visual is not available.
            }
        }

        private static void RemoveVisuals(TabView tabView)
        {
            try
            {
                ShapeVisual? indicator = GetIndicatorVisual(tabView);
                if (indicator != null)
                {
                    try
                    {
                        ContainerVisual containerVisual = (ContainerVisual)ElementCompositionPreview.GetElementVisual(tabView);
                        containerVisual.Children.Remove(indicator);
                    }
                    catch
                    {
                    }

                    indicator.Dispose();
                }

                GetIndicatorShape(tabView)?.Dispose();
                GetIndicatorGeometry(tabView)?.Dispose();
            }
            catch
            {
            }
            finally
            {
                SetIndicatorVisual(tabView, null);
                SetIndicatorShape(tabView, null);
                SetIndicatorGeometry(tabView, null);
                tabView.SetValue(LastTargetPositionProperty, new Point(-1, -1));
                tabView.SetValue(LastTargetWidthProperty, -1.0);
            }
        }

"@

if ($idxInit -ge 0 -and $idxBrush -gt $idxInit) {
    $behText = $behText.Substring(0, $idxInit) + $newInitAndRemove + $behText.Substring($idxBrush)
    Write-Host "Replaced InitializeVisuals and RemoveVisuals."
}

# 2c. Update UpdateVisualsPosition
# Fix hasSelection and remove debug.log
$oldUpdatePosStart = "        private static void UpdateVisualsPosition(TabView tabView, bool animate, int retryCount = 0)"
$idxUpdate = $behText.IndexOf($oldUpdatePosStart)
if ($idxUpdate -ge 0) {
    # Let's replace the entire UpdateVisualsPosition method cleanly
    $newUpdateVisualsPosition = @"
        private static void UpdateVisualsPosition(TabView tabView, bool animate, int retryCount = 0)
        {
            ShapeVisual? indicator = GetIndicatorVisual(tabView);
            CompositionRoundedRectangleGeometry? pillGeometry = GetIndicatorGeometry(tabView);
            if (indicator == null || pillGeometry == null)
            {
                return;
            }

            TabViewItem? selectedTab = FindActiveTabViewItem(tabView);
            if (selectedTab == null || !selectedTab.IsLoaded || selectedTab.ActualWidth <= 4.0f)
            {
                indicator.IsVisible = false;

                // Defer position calculation to next frame when container is generated and measured (capped to prevent infinite loop)
                bool hasHeaderTab = tabView.TabStripHeader is DependencyObject;
                bool hasSelection = tabView.SelectedItem != null || tabView.SelectedIndex >= 0 || hasHeaderTab;
                if (hasSelection && retryCount < 10)
                {
                    DispatcherQueuePriority priority = retryCount < 2 ? DispatcherQueuePriority.Normal : DispatcherQueuePriority.Low;
                    tabView.DispatcherQueue?.TryEnqueue(priority, () =>
                    {
                        if (tabView.IsLoaded)
                        {
                            UpdateVisualsPosition(tabView, animate, retryCount + 1);
                        }
                    });
                }
                else if (!hasSelection)
                {
                    FrameworkElement? bgCapsule = GetBackgroundCapsule(tabView);
                    if (bgCapsule != null)
                    {
                        bgCapsule.Opacity = 0.0;
                    }

                    tabView.SetValue(LastTargetPositionProperty, new Point(-1, -1));
                    tabView.SetValue(LastTargetWidthProperty, -1.0);
                }

                return;
            }

            try
            {
                GeneralTransform transform = selectedTab.TransformToVisual(tabView);
                Point position = transform.TransformPoint(new Point(0, 0));

                // Dimensions and target coordinates for adaptive accent indicator pill:
                // Spans across the tab width, inset by 8px on left and right so it avoids the rounded corner curvature
                float pillInset = TabMotionConfiguration.IndicatorHorizontalInset;
                float targetPillWidth = Math.Max(12.0f, ((float)selectedTab.ActualWidth - (pillInset * 2.0f)) * 0.8f);
                float targetPillHeight = TabMotionConfiguration.IndicatorHeight;
                float basePillX = (float)position.X + pillInset;
                float widthDifference = ((float)selectedTab.ActualWidth - (pillInset * 2.0f)) - targetPillWidth;
                float targetPillX = basePillX + (widthDifference / 2.0f);
                float targetPillY = (float)(position.Y + selectedTab.ActualHeight - 5.0f);

                // Dimensions and target coordinates for optional background capsule
                FrameworkElement? bgCapsule = GetBackgroundCapsule(tabView);
                float targetBgX = (float)position.X;
                float targetBgY = (float)position.Y;
                float targetBgWidth = Math.Max(0, (float)selectedTab.ActualWidth + 1.0f);
                float targetBgHeight = Math.Max(0, (float)selectedTab.ActualHeight);

                Point lastTargetPos = (Point)tabView.GetValue(LastTargetPositionProperty);
                double lastTargetWidth = (double)tabView.GetValue(LastTargetWidthProperty);

                bool positionChanged = Math.Abs(lastTargetPos.X - targetBgX) >= 1.0 ||
                                       Math.Abs(lastTargetPos.Y - targetBgY) >= 1.0 ||
                                       Math.Abs(lastTargetWidth - targetBgWidth) >= 1.0;

                bool isIndicatorVisible = GetIsIndicatorVisible(tabView);
                indicator.IsVisible = isIndicatorVisible;

                if (animate && TabMotionConfiguration.AreAnimationsEnabled)
                {
                    if (positionChanged || (bgCapsule != null && bgCapsule.Opacity < 0.5))
                    {
                        tabView.SetValue(LastTargetPositionProperty, new Point(targetBgX, targetBgY));
                        tabView.SetValue(LastTargetWidthProperty, (double)targetBgWidth);

                        Compositor compositor = indicator.Compositor;
                        CompositionEasingFunction easing = compositor.CreateCubicBezierEasingFunction(
                            TabMotionConfiguration.DecelerateControlPoint1,
                            TabMotionConfiguration.DecelerateControlPoint2);

                        // 1. Animate Accent Pill Position & Width (only if enabled via flag)
                        if (isIndicatorVisible)
                        {
                            Vector3KeyFrameAnimation pillOffsetAnimation = compositor.CreateVector3KeyFrameAnimation();
                            pillOffsetAnimation.InsertKeyFrame(1.0f, new Vector3(targetPillX, targetPillY, 0), easing);
                            pillOffsetAnimation.Duration = TabMotionConfiguration.TabIndicatorDuration;
                            indicator.StartAnimation("Offset", pillOffsetAnimation);

                            Vector2KeyFrameAnimation pillSizeAnimation = compositor.CreateVector2KeyFrameAnimation();
                            pillSizeAnimation.InsertKeyFrame(1.0f, new Vector2(targetPillWidth, targetPillHeight), easing);
                            pillSizeAnimation.Duration = TabMotionConfiguration.TabIndicatorDuration;
                            indicator.StartAnimation("Size", pillSizeAnimation);
                            pillGeometry.StartAnimation("Size", pillSizeAnimation);
                        }
                        else
                        {
                            indicator.Offset = new Vector3(targetPillX, targetPillY, 0);
                            indicator.Size = new Vector2(targetPillWidth, targetPillHeight);
                            pillGeometry.Size = new Vector2(targetPillWidth, targetPillHeight);
                        }

                        // 2. Animate Background Capsule if present
                        if (bgCapsule != null)
                        {
                            ElementCompositionPreview.SetIsTranslationEnabled(bgCapsule, true);
                            bgCapsule.Opacity = 1.0;
                            Visual capsuleVisual = ElementCompositionPreview.GetElementVisual(bgCapsule);

                            Vector3KeyFrameAnimation bgTranslationAnimation = capsuleVisual.Compositor.CreateVector3KeyFrameAnimation();
                            CompositionEasingFunction capsuleEasing = capsuleVisual.Compositor.CreateCubicBezierEasingFunction(
                                TabMotionConfiguration.DecelerateControlPoint1,
                                TabMotionConfiguration.DecelerateControlPoint2);
                            bgTranslationAnimation.InsertKeyFrame(1.0f, new Vector3(targetBgX, targetBgY, 0), capsuleEasing);
                            bgTranslationAnimation.Duration = TabMotionConfiguration.TabIndicatorDuration;
                            capsuleVisual.StartAnimation("Translation", bgTranslationAnimation);

                            bgCapsule.Width = targetBgWidth;
                            bgCapsule.Height = targetBgHeight;
                        }
                    }
                }
                else
                {
                    tabView.SetValue(LastTargetPositionProperty, new Point(targetBgX, targetBgY));
                    tabView.SetValue(LastTargetWidthProperty, (double)targetBgWidth);

                    indicator.Offset = new Vector3(targetPillX, targetPillY, 0);
                    indicator.Size = new Vector2(targetPillWidth, targetPillHeight);
                    pillGeometry.Size = new Vector2(targetPillWidth, targetPillHeight);

                    if (bgCapsule != null)
                    {
                        ElementCompositionPreview.SetIsTranslationEnabled(bgCapsule, true);
                        bgCapsule.Opacity = 1.0;
                        Visual capsuleVisual = ElementCompositionPreview.GetElementVisual(bgCapsule);
                        capsuleVisual.Properties.InsertVector3("Translation", new Vector3(targetBgX, targetBgY, 0));
                        bgCapsule.Width = targetBgWidth;
                        bgCapsule.Height = targetBgHeight;
                    }
                }
            }
            catch
            {
                indicator.IsVisible = false;
            }
        }
    }
}
"@

    $behText = $behText.Substring(0, $idxUpdate) + $newUpdateVisualsPosition
    Write-Host "Replaced UpdateVisualsPosition."
}

[System.IO.File]::WriteAllText($behPath, $behText, [System.Text.Encoding]::UTF8)
Write-Host "SlidingTabIndicatorBehavior.cs patched."
