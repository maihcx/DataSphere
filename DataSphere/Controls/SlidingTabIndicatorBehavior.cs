// --------------------------------------------------------------------------------------------------------------------
// <copyright file="SlidingTabIndicatorBehavior.cs" company="DataSphere">
//   Copyright (c) DataSphere. All rights reserved.
// </copyright>
// --------------------------------------------------------------------------------------------------------------------

namespace DataSphere.Controls
{
    using System;
    using System.Collections.Generic;
    using System.Numerics;
    using Microsoft.UI.Composition;
    using Microsoft.UI.Dispatching;
    using Microsoft.UI.Xaml;
    using Microsoft.UI.Xaml.Controls;
    using Microsoft.UI.Xaml.Hosting;
    using Microsoft.UI.Xaml.Input;
    using Microsoft.UI.Xaml.Media;
    using Windows.Foundation;
    using Windows.Foundation.Collections;
    using Windows.UI;
    using Windows.UI.ViewManagement;

    /// <summary>
    /// Attached behavior for <see cref="TabView"/> that renders an adaptive Windows 11 Fluent accent pill indicator
    /// matching the system accent color, and coordinates smooth hardware-accelerated sliding motion for both
    /// the selection indicator and the underlying tab background capsule across tab switches.
    /// </summary>
    public static class SlidingTabIndicatorBehavior
    {
        private static readonly UISettings _uiSettings = new();
        private static readonly List<WeakReference<TabView>> _activeTabViews = new();
        private static readonly TappedEventHandler _tappedHandler = OnTabViewTapped;

        /// <summary>
        /// Dependency property controlling whether the sliding tab indicator is active on a <see cref="TabView"/>.
        /// </summary>
        public static readonly DependencyProperty IsEnabledProperty =
            DependencyProperty.RegisterAttached(
                "IsEnabled",
                typeof(bool),
                typeof(SlidingTabIndicatorBehavior),
                new PropertyMetadata(false, OnIsEnabledChanged));

        /// <summary>
        /// Gets a value indicating whether the sliding tab indicator is enabled.
        /// </summary>
        /// <param name="obj">The dependency object (typically a <see cref="TabView"/>).</param>
        /// <returns><c>true</c> if enabled; otherwise, <c>false</c>.</returns>
        public static bool GetIsEnabled(DependencyObject obj)
        {
            return (bool)obj.GetValue(IsEnabledProperty);
        }

        /// <summary>
        /// Sets a value indicating whether the sliding tab indicator is enabled.
        /// </summary>
        /// <param name="obj">The dependency object (typically a <see cref="TabView"/>).</param>
        /// <param name="value"><c>true</c> to enable; otherwise, <c>false</c>.</param>
        public static void SetIsEnabled(DependencyObject obj, bool value)
        {
            obj.SetValue(IsEnabledProperty, value);
        }

        /// <summary>
        /// Dependency property referencing an optional background capsule element (e.g., a XAML <see cref="Border"/>
        /// hosted in a background layer behind the <see cref="TabView"/>) that glides smoothly under the selected tab.
        /// </summary>
        public static readonly DependencyProperty BackgroundCapsuleProperty =
            DependencyProperty.RegisterAttached(
                "BackgroundCapsule",
                typeof(FrameworkElement),
                typeof(SlidingTabIndicatorBehavior),
                new PropertyMetadata(null));

        /// <summary>
        /// Gets the optional background capsule element associated with the <see cref="TabView"/>.
        /// </summary>
        /// <param name="obj">The dependency object (typically a <see cref="TabView"/>).</param>
        /// <returns>The background capsule element, or <c>null</c> if none is configured.</returns>
        public static FrameworkElement? GetBackgroundCapsule(DependencyObject obj)
        {
            return (FrameworkElement?)obj.GetValue(BackgroundCapsuleProperty);
        }

        /// <summary>
        /// Sets the optional background capsule element associated with the <see cref="TabView"/>.
        /// </summary>
        /// <param name="obj">The dependency object (typically a <see cref="TabView"/>).</param>
        /// <param name="value">The background capsule element to animate behind tabs.</param>
        public static void SetBackgroundCapsule(DependencyObject obj, FrameworkElement? value)
        {
            obj.SetValue(BackgroundCapsuleProperty, value);
        }

        /// <summary>
        /// Dependency property controlling whether the bottom accent indicator pill is rendered on a <see cref="TabView"/>.
        /// Defaults to <c>false</c> per user preference to keep tab selection visual clean while allowing background motion.
        /// </summary>
        public static readonly DependencyProperty IsIndicatorVisibleProperty =
            DependencyProperty.RegisterAttached(
                "IsIndicatorVisible",
                typeof(bool),
                typeof(SlidingTabIndicatorBehavior),
                new PropertyMetadata(TabMotionConfiguration.IsIndicatorVisible, OnIsIndicatorVisibleChanged));

        /// <summary>
        /// Gets a value indicating whether the bottom accent indicator pill is visible.
        /// </summary>
        /// <param name="obj">The dependency object (typically a <see cref="TabView"/>).</param>
        /// <returns><c>true</c> if visible; otherwise, <c>false</c>.</returns>
        public static bool GetIsIndicatorVisible(DependencyObject obj)
        {
            return (bool)obj.GetValue(IsIndicatorVisibleProperty);
        }

        /// <summary>
        /// Sets a value indicating whether the bottom accent indicator pill is visible.
        /// </summary>
        /// <param name="obj">The dependency object (typically a <see cref="TabView"/>).</param>
        /// <param name="value"><c>true</c> to show; otherwise, <c>false</c>.</param>
        public static void SetIsIndicatorVisible(DependencyObject obj, bool value)
        {
            obj.SetValue(IsIndicatorVisibleProperty, value);
        }

        private static void OnIsIndicatorVisibleChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is TabView tabView)
            {
                ShapeVisual? indicator = GetIndicatorVisual(tabView);
                if (indicator != null)
                {
                    indicator.IsVisible = (bool)e.NewValue;
                }
            }
        }

        private static readonly DependencyProperty IndicatorVisualProperty =
            DependencyProperty.RegisterAttached(
                "IndicatorVisual",
                typeof(ShapeVisual),
                typeof(SlidingTabIndicatorBehavior),
                new PropertyMetadata(null));

        private static readonly DependencyProperty IndicatorShapeProperty =
            DependencyProperty.RegisterAttached(
                "IndicatorShape",
                typeof(CompositionSpriteShape),
                typeof(SlidingTabIndicatorBehavior),
                new PropertyMetadata(null));

        private static readonly DependencyProperty IndicatorGeometryProperty =
            DependencyProperty.RegisterAttached(
                "IndicatorGeometry",
                typeof(CompositionRoundedRectangleGeometry),
                typeof(SlidingTabIndicatorBehavior),
                new PropertyMetadata(null));

        private static ShapeVisual? GetIndicatorVisual(TabView tabView)
        {
            return (ShapeVisual?)tabView.GetValue(IndicatorVisualProperty);
        }

        private static void SetIndicatorVisual(TabView tabView, ShapeVisual? value)
        {
            tabView.SetValue(IndicatorVisualProperty, value);
        }

        private static CompositionSpriteShape? GetIndicatorShape(TabView tabView)
        {
            return (CompositionSpriteShape?)tabView.GetValue(IndicatorShapeProperty);
        }

        private static void SetIndicatorShape(TabView tabView, CompositionSpriteShape? value)
        {
            tabView.SetValue(IndicatorShapeProperty, value);
        }

        private static CompositionRoundedRectangleGeometry? GetIndicatorGeometry(TabView tabView)
        {
            return (CompositionRoundedRectangleGeometry?)tabView.GetValue(IndicatorGeometryProperty);
        }

        private static void SetIndicatorGeometry(TabView tabView, CompositionRoundedRectangleGeometry? value)
        {
            tabView.SetValue(IndicatorGeometryProperty, value);
        }

        private static void OnIsEnabledChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is not TabView tabView)
            {
                return;
            }

            if ((bool)e.NewValue)
            {
                Attach(tabView);
            }
            else
            {
                Detach(tabView);
            }
        }

        private static void Attach(TabView tabView)
        {
            tabView.Loaded += OnTabViewLoaded;
            tabView.Unloaded += OnTabViewUnloaded;
            tabView.SelectionChanged += OnTabViewSelectionChanged;
            tabView.SizeChanged += OnTabViewSizeChanged;
            tabView.TabItemsChanged += OnTabItemsChanged;
            tabView.ActualThemeChanged += OnTabViewActualThemeChanged;
            tabView.AddHandler(UIElement.TappedEvent, _tappedHandler, true);

            lock (_activeTabViews)
            {
                _activeTabViews.Add(new WeakReference<TabView>(tabView));
                if (_activeTabViews.Count == 1)
                {
                    _uiSettings.ColorValuesChanged += OnSystemColorValuesChanged;
                }
            }

            if (tabView.IsLoaded)
            {
                InitializeVisuals(tabView);
            }
        }

        private static void Detach(TabView tabView)
        {
            tabView.Loaded -= OnTabViewLoaded;
            tabView.Unloaded -= OnTabViewUnloaded;
            tabView.SelectionChanged -= OnTabViewSelectionChanged;
            tabView.SizeChanged -= OnTabViewSizeChanged;
            tabView.TabItemsChanged -= OnTabItemsChanged;
            tabView.ActualThemeChanged -= OnTabViewActualThemeChanged;
            tabView.RemoveHandler(UIElement.TappedEvent, _tappedHandler);

            lock (_activeTabViews)
            {
                for (int i = _activeTabViews.Count - 1; i >= 0; i--)
                {
                    if (!_activeTabViews[i].TryGetTarget(out TabView? target) || target == tabView)
                    {
                        _activeTabViews.RemoveAt(i);
                    }
                }

                if (_activeTabViews.Count == 0)
                {
                    _uiSettings.ColorValuesChanged -= OnSystemColorValuesChanged;
                }
            }

            RemoveVisuals(tabView);
        }

        private static void OnTabViewLoaded(object sender, RoutedEventArgs e)
        {
            if (sender is TabView tabView)
            {
                InitializeVisuals(tabView);
            }
        }

        private static void OnTabViewUnloaded(object sender, RoutedEventArgs e)
        {
            if (sender is TabView tabView)
            {
                RemoveVisuals(tabView);
            }
        }

        private static void OnTabViewSelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (sender is TabView tabView)
            {
                UpdateVisualsPosition(tabView, animate: true);
            }
        }

        private static void OnTabViewTapped(object sender, TappedRoutedEventArgs e)
        {
            if (sender is TabView tabView)
            {
                UpdateVisualsPosition(tabView, animate: true);
            }
        }

        private static void OnTabViewSizeChanged(object sender, SizeChangedEventArgs e)
        {
            if (sender is TabView tabView)
            {
                UpdateVisualsPosition(tabView, animate: false);
            }
        }

        private static void OnTabItemsChanged(TabView sender, IVectorChangedEventArgs args)
        {
            UpdateVisualsPosition(sender, animate: true);
        }

        private static void OnTabViewActualThemeChanged(FrameworkElement sender, object args)
        {
            if (sender is TabView tabView)
            {
                UpdateVisualsBrush(tabView);
            }
        }

        private static void OnSystemColorValuesChanged(UISettings sender, object args)
        {
            // ColorValuesChanged fires on a background worker thread; marshal back to UI thread for each active tab view.
            lock (_activeTabViews)
            {
                foreach (WeakReference<TabView> tabRef in _activeTabViews)
                {
                    if (tabRef.TryGetTarget(out TabView? tabView))
                    {
                        tabView.DispatcherQueue?.TryEnqueue(() =>
                        {
                            UpdateVisualsBrush(tabView);
                        });
                    }
                }
            }
        }

        private static void InitializeVisuals(TabView tabView)
        {
            if (GetIndicatorVisual(tabView) != null)
            {
                UpdateVisualsPosition(tabView, animate: false);
                return;
            }

            try
            {
                ContainerVisual containerVisual = (ContainerVisual)ElementCompositionPreview.GetElementVisual(tabView);
                Compositor compositor = containerVisual.Compositor;

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
                ContainerVisual containerVisual = (ContainerVisual)ElementCompositionPreview.GetElementVisual(tabView);

                ShapeVisual? indicator = GetIndicatorVisual(tabView);
                if (indicator != null)
                {
                    containerVisual.Children.Remove(indicator);
                    indicator.Dispose();
                }

                GetIndicatorShape(tabView)?.Dispose();
                GetIndicatorGeometry(tabView)?.Dispose();

                SetIndicatorVisual(tabView, null);
                SetIndicatorShape(tabView, null);
                SetIndicatorGeometry(tabView, null);
            }
            catch
            {
            }
        }

        private static void UpdateVisualsBrush(TabView tabView)
        {
            CompositionSpriteShape? pillShape = GetIndicatorShape(tabView);
            if (pillShape != null)
            {
                pillShape.FillBrush = pillShape.Compositor.CreateColorBrush(GetAccentColor(tabView));
            }
        }

        private static Color GetAccentColor(FrameworkElement element)
        {
            // 1. Query Windows 11 system accent color with light/dark contrast variant
            try
            {
                if (element.ActualTheme == ElementTheme.Dark)
                {
                    return _uiSettings.GetColorValue(UIColorType.AccentLight2);
                }
                else
                {
                    return _uiSettings.GetColorValue(UIColorType.AccentDark1);
                }
            }
            catch
            {
                try
                {
                    return _uiSettings.GetColorValue(UIColorType.Accent);
                }
                catch
                {
                    // 2. Fallback to standard Windows 11 Fluent blue accents
                    return element.ActualTheme == ElementTheme.Dark
                        ? Color.FromArgb(255, 96, 205, 255)
                        : Color.FromArgb(255, 0, 95, 184);
                }
            }
        }

        private static TabViewItem? FindActiveTabViewItem(TabView tabView)
        {
            if (tabView.SelectedItem != null)
            {
                if (tabView.SelectedItem is TabViewItem directItem)
                {
                    return directItem;
                }

                if (tabView.ContainerFromItem(tabView.SelectedItem) is TabViewItem container)
                {
                    return container;
                }
            }

            if (tabView.SelectedIndex >= 0 && tabView.ContainerFromIndex(tabView.SelectedIndex) is TabViewItem indexContainer)
            {
                return indexContainer;
            }

            // Fallback: search entire TabView visual tree (handles TabStripHeader items and deferred containers)
            return FindSelectedTabViewItemInTree(tabView);
        }

        private static TabViewItem? FindSelectedTabViewItemInTree(DependencyObject root)
        {
            if (root is TabViewItem item && item.IsSelected)
            {
                return item;
            }

            int count = VisualTreeHelper.GetChildrenCount(root);
            for (int i = 0; i < count; i++)
            {
                DependencyObject child = VisualTreeHelper.GetChild(root, i);
                TabViewItem? result = FindSelectedTabViewItemInTree(child);
                if (result != null)
                {
                    return result;
                }
            }

            return null;
        }

        private static void UpdateVisualsPosition(TabView tabView, bool animate, int retryCount = 0)
        {
            ShapeVisual? indicator = GetIndicatorVisual(tabView);
            CompositionRoundedRectangleGeometry? pillGeometry = GetIndicatorGeometry(tabView);
            if (indicator == null || pillGeometry == null)
            {
                return;
            }

            TabViewItem? selectedTab = FindActiveTabViewItem(tabView);
            if (selectedTab == null || !selectedTab.IsLoaded || selectedTab.ActualWidth <= 0)
            {
                indicator.IsVisible = false;

                // Defer position calculation to next frame when container is generated and measured (capped to prevent infinite loop)
                bool hasSelection = tabView.SelectedItem != null || tabView.SelectedIndex >= 0 || selectedTab != null;
                if (hasSelection && retryCount < 4)
                {
                    tabView.DispatcherQueue?.TryEnqueue(DispatcherQueuePriority.Low, () =>
                    {
                        if (tabView.IsLoaded)
                        {
                            UpdateVisualsPosition(tabView, animate, retryCount + 1);
                        }
                    });
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
                float targetBgX = (float)position.X + 2.0f;
                float targetBgY = (float)position.Y + 2.0f;
                float targetBgWidth = Math.Max(0, (float)selectedTab.ActualWidth - 4.0f);
                float targetBgHeight = Math.Max(0, (float)selectedTab.ActualHeight - 4.0f);

                bool isIndicatorVisible = GetIsIndicatorVisible(tabView);
                indicator.IsVisible = isIndicatorVisible;

                if (animate && TabMotionConfiguration.AreAnimationsEnabled)
                {
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

                        Vector3KeyFrameAnimation bgTranslationAnimation = compositor.CreateVector3KeyFrameAnimation();
                        bgTranslationAnimation.InsertKeyFrame(1.0f, new Vector3(targetBgX, targetBgY, 0), easing);
                        bgTranslationAnimation.Duration = TabMotionConfiguration.TabIndicatorDuration;
                        capsuleVisual.StartAnimation("Translation", bgTranslationAnimation);

                        bgCapsule.Width = targetBgWidth;
                        bgCapsule.Height = targetBgHeight;
                    }
                }
                else
                {
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
