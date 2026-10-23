using System;
using System.Numerics;
using Microsoft.UI.Composition;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Hosting;

namespace DataSphere.Controls
{
    /// <summary>
    /// A high-performance, MVVM-compliant viewport host control that retains rendered visual elements in memory
    /// and switches active content via visibility toggling combined with direction-aware horizontal WinUI 3 Compositor entrance transitions.
    /// Eliminates layout thrashing, DirectComposition surface churn, and UI freeze during tab switching.
    /// </summary>
    public partial class CachedContentControl : Grid
    {
        /// <summary>
        /// Identifies the <see cref="Content"/> dependency property.
        /// </summary>
        public static readonly DependencyProperty ContentProperty =
            DependencyProperty.Register(
                nameof(Content),
                typeof(object),
                typeof(CachedContentControl),
                new PropertyMetadata(null, OnContentChanged));

        /// <summary>
        /// Identifies the <see cref="IsTransitionEnabled"/> dependency property.
        /// </summary>
        public static readonly DependencyProperty IsTransitionEnabledProperty =
            DependencyProperty.Register(
                nameof(IsTransitionEnabled),
                typeof(bool),
                typeof(CachedContentControl),
                new PropertyMetadata(true));

        /// <summary>
        /// Identifies the <see cref="SelectedIndex"/> dependency property.
        /// </summary>
        public static readonly DependencyProperty SelectedIndexProperty =
            DependencyProperty.Register(
                nameof(SelectedIndex),
                typeof(int),
                typeof(CachedContentControl),
                new PropertyMetadata(-1, OnSelectedIndexChanged));

        /// <summary>
        /// Gets or sets the active content to display within the cached viewport.
        /// When bound to a ViewModel property, automatically activates the corresponding visual element
        /// and collapses all other cached views without detaching them from the visual tree.
        /// </summary>
        public object? Content
        {
            get => GetValue(ContentProperty);
            set => SetValue(ContentProperty, value);
        }

        /// <summary>
        /// Gets or sets a value indicating whether hardware-accelerated WinUI Compositor entrance animations are enabled.
        /// Default is <c>true</c>. Automatically bypassed when animations are disabled in Windows settings.
        /// </summary>
        public bool IsTransitionEnabled
        {
            get => (bool)GetValue(IsTransitionEnabledProperty);
            set => SetValue(IsTransitionEnabledProperty, value);
        }

        /// <summary>
        /// Gets or sets the current navigation index of the active tab.
        /// Used to determine the horizontal slide direction (+X for forward navigation, -X for backward navigation).
        /// </summary>
        public int SelectedIndex
        {
            get => (int)GetValue(SelectedIndexProperty);
            set => SetValue(SelectedIndexProperty, value);
        }

        private int _slideDirection = 1;
        private int _lastSelectedIndex = -1;

        /// <summary>
        /// Initializes a new instance of the <see cref="CachedContentControl"/> class.
        /// </summary>
        public CachedContentControl()
        {
            Background = null;
        }

        private static void OnSelectedIndexChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is CachedContentControl control && e.NewValue is int newIdx)
            {
                int oldIdx = (e.OldValue is int prev && prev >= 0) ? prev : control._lastSelectedIndex;
                if (oldIdx >= 0 && newIdx >= 0 && oldIdx != newIdx)
                {
                    control._slideDirection = newIdx > oldIdx ? 1 : -1;
                }
                control._lastSelectedIndex = newIdx;
            }
        }

        private static void OnContentChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is CachedContentControl control)
            {
                control.UpdateActiveContent(e.NewValue);
            }
        }

        /// <summary>
        /// Activates the visual element corresponding to the active content while collapsing all other cached views.
        /// Dispatches a smooth, direction-aware horizontal WinUI 3 Compositor entrance transition on the newly active element.
        /// </summary>
        /// <param name="newContent">The newly selected content object.</param>
        private void UpdateActiveContent(object? newContent)
        {
            if (newContent is UIElement element)
            {
                if (!Children.Contains(element))
                {
                    Children.Add(element);
                }

                foreach (UIElement child in Children)
                {
                    if (ReferenceEquals(child, element))
                    {
                        child.Visibility = Visibility.Visible;
                    }
                    else
                    {
                        child.Visibility = Visibility.Collapsed;
                    }
                }

                if (IsTransitionEnabled && TabMotionConfiguration.AreAnimationsEnabled)
                {
                    // Pre-emptively prepare compositor opacity to eliminate any single-frame opacity flashes
                    // prior to the entrance transition being scheduled.
                    PrepareElementForTransition(element);

                    void RunTransition()
                    {
                        if (element.Visibility == Visibility.Visible && IsTransitionEnabled && TabMotionConfiguration.AreAnimationsEnabled)
                        {
                            // Direction is strictly determined by navigation progression:
                            // Forward navigation (low to high index): incoming view enters from the right (+32px -> 0px)
                            // Backward navigation (high to low index): incoming view enters from the left (-32px -> 0px)
                            float offsetX = _slideDirection >= 0
                                ? TabMotionConfiguration.EntranceOffsetX
                                : -TabMotionConfiguration.EntranceOffsetX;

                            if (element is FrameworkElement fe && !fe.IsLoaded)
                            {
                                RoutedEventHandler? loadedHandler = null;
                                loadedHandler = (s, e) =>
                                {
                                    fe.Loaded -= loadedHandler;
                                    if (fe.Visibility == Visibility.Visible && IsTransitionEnabled && TabMotionConfiguration.AreAnimationsEnabled)
                                    {
                                        float dynamicOffset = _slideDirection >= 0
                                            ? TabMotionConfiguration.EntranceOffsetX
                                            : -TabMotionConfiguration.EntranceOffsetX;
                                        PlayEntranceTransition(fe, dynamicOffset);
                                    }
                                };
                                fe.Loaded += loadedHandler;
                            }
                            else
                            {
                                PlayEntranceTransition(element, offsetX);
                            }
                        }
                    }

                    // Defer animation execution to DispatcherQueue so that any concurrent property changes
                    // (specifically SelectedIndex) in the same dispatch cycle are guaranteed to have updated _slideDirection.
                    if (DispatcherQueue != null)
                    {
                        DispatcherQueue.TryEnqueue(Microsoft.UI.Dispatching.DispatcherQueuePriority.Normal, RunTransition);
                    }
                    else
                    {
                        RunTransition();
                    }
                }
                else
                {
                    ResetVisualState(element);
                }
            }
            else
            {
                foreach (UIElement child in Children)
                {
                    child.Visibility = Visibility.Collapsed;
                }
            }
        }

        /// <summary>
        /// Pre-emptively initializes the visual element's compositor properties to a transparent state
        /// prior to triggering the queued entrance animation, eliminating any single-frame opacity flashes.
        /// </summary>
        /// <param name="element">The visual element to prepare.</param>
        private static void PrepareElementForTransition(UIElement element)
        {
            try
            {
                Visual visual = ElementCompositionPreview.GetElementVisual(element);
                visual.Opacity = 0.0f;
            }
            catch
            {
                // Fall back gracefully if compositor visual access is not available yet.
            }
        }

        /// <summary>
        /// Executes an off-thread WinUI 3 Compositor entrance animation on the active visual element.
        /// Performs a 300ms fade-in and horizontal slide using Windows 11 Decelerate easing.
        /// </summary>
        /// <param name="element">The visual element to animate.</param>
        /// <param name="offsetX">The initial horizontal translation offset.</param>
        private static void PlayEntranceTransition(UIElement element, float offsetX)
        {
            try
            {
                Visual visual = ElementCompositionPreview.GetElementVisual(element);
                Compositor compositor = visual.Compositor;

                ElementCompositionPreview.SetIsTranslationEnabled(element, true);

                CompositionEasingFunction easing = compositor.CreateCubicBezierEasingFunction(
                    TabMotionConfiguration.DecelerateControlPoint1,
                    TabMotionConfiguration.DecelerateControlPoint2);

                // 1. Opacity Transition (0.0 -> 1.0)
                ScalarKeyFrameAnimation opacityAnimation = compositor.CreateScalarKeyFrameAnimation();
                opacityAnimation.InsertKeyFrame(0.0f, 0.0f);
                opacityAnimation.InsertKeyFrame(1.0f, 1.0f, easing);
                opacityAnimation.Duration = TabMotionConfiguration.ContentTransitionDuration;

                // 2. Horizontal Directional Slide (offsetX -> 0px)
                Vector3KeyFrameAnimation translationAnimation = compositor.CreateVector3KeyFrameAnimation();
                translationAnimation.InsertKeyFrame(0.0f, new Vector3(offsetX, 0, 0));
                translationAnimation.InsertKeyFrame(1.0f, Vector3.Zero, easing);
                translationAnimation.Duration = TabMotionConfiguration.ContentTransitionDuration;

                visual.StartAnimation("Opacity", opacityAnimation);
                visual.StartAnimation("Translation", translationAnimation);
            }
            catch
            {
                // Fall back gracefully if compositor visual access is unavailable.
                element.Opacity = 1.0;
                try
                {
                    Visual visual = ElementCompositionPreview.GetElementVisual(element);
                    visual.Opacity = 1.0f;
                }
                catch
                {
                }
            }
        }

        /// <summary>
        /// Resets the visual element's compositor properties to default visible state without animations.
        /// </summary>
        /// <param name="element">The visual element to reset.</param>
        private static void ResetVisualState(UIElement element)
        {
            try
            {
                Visual visual = ElementCompositionPreview.GetElementVisual(element);
                visual.Opacity = 1.0f;
                ElementCompositionPreview.SetIsTranslationEnabled(element, true);
                visual.Properties.InsertVector3("Translation", Vector3.Zero);
            }
            catch
            {
                element.Opacity = 1.0;
            }
        }

        /// <summary>
        /// Removes a specific visual element from the cache (e.g. when an associated tab session is closed).
        /// </summary>
        /// <param name="element">The visual element to remove.</param>
        public void Remove(UIElement element)
        {
            if (element != null && Children.Contains(element))
            {
                Children.Remove(element);
            }
        }

        /// <summary>
        /// Clears all cached visual elements from the viewport host.
        /// </summary>
        public void Clear()
        {
            Children.Clear();
        }
    }
}
