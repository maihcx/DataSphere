# Component & Control Contracts: Fluent Tab Selection Pill, Sliding Background & Directional Page Motion

**Feature Branch**: `018-tab-motion-and-indicator`  
**Date**: 2026-10-23  
**Status**: Completed  

---

## 1. `TabMotionConfiguration` Public Contract

```csharp
namespace DataSphere.Controls
{
    /// <summary>
    /// Centralized motion configuration and timing definitions for Windows 11 Fluent Design tab and viewport transitions.
    /// Provides consistent easing curves, durations, geometry metrics, and system accessibility detection.
    /// </summary>
    public static class TabMotionConfiguration
    {
        /// <summary>
        /// Standard duration for tab viewport entrance transitions (300 milliseconds).
        /// Tuned for comfortable, noticeable spatial continuity across view transitions.
        /// </summary>
        public static readonly TimeSpan ContentTransitionDuration = TimeSpan.FromMilliseconds(300);

        /// <summary>
        /// Standard duration for tab header selection indicator and background capsule sliding transitions (250 milliseconds).
        /// </summary>
        public static readonly TimeSpan TabIndicatorDuration = TimeSpan.FromMilliseconds(250);

        /// <summary>
        /// The horizontal translation distance in pixels for directional entrance motion (±32 pixels along the X-axis).
        /// </summary>
        public const float EntranceOffsetX = 32.0f;

        /// <summary>
        /// Fixed width in pixels for the compact accent selection pill indicator (20 pixels).
        /// </summary>
        public const float IndicatorWidth = 20.0f;

        /// <summary>
        /// Fixed height in pixels for the compact accent selection pill indicator (3 pixels).
        /// </summary>
        public const float IndicatorHeight = 3.0f;

        /// <summary>
        /// Corner radius in pixels for the compact accent selection pill indicator (1.5 pixels, fully rounded).
        /// </summary>
        public const float IndicatorCornerRadius = 1.5f;

        /// <summary>
        /// Corner radius in pixels for the sliding background capsule (6.0 pixels, matching TabViewItem capsule geometry).
        /// </summary>
        public const float BackgroundCornerRadius = 6.0f;

        /// <summary>
        /// First control point for the Windows 11 Fluent Decelerate cubic-bezier curve (0.1, 0.9).
        /// </summary>
        public static readonly Vector2 DecelerateControlPoint1 = new(0.1f, 0.9f);

        /// <summary>
        /// Second control point for the Windows 11 Fluent Decelerate cubic-bezier curve (0.2, 1.0).
        /// </summary>
        public static readonly Vector2 DecelerateControlPoint2 = new(0.2f, 1.0f);

        /// <summary>
        /// Gets a value indicating whether motion and animation effects are enabled at the operating system level.
        /// Respects the Windows Settings > Accessibility > Visual Effects > Animation effects configuration.
        /// </summary>
        public static bool AreAnimationsEnabled { get; }
    }
}
```

---

## 2. `SlidingTabIndicatorBehavior` Attached Behavior Contract

```csharp
namespace DataSphere.Controls
{
    /// <summary>
    /// An attached behavior for <see cref="TabView"/> that creates a smooth, hardware-accelerated
    /// WinUI 3 Compositor sliding selection indicator pill and sliding background capsule between active tabs.
    /// Adheres dynamically to the Windows 11 system accent color and Fluent Design motion guidelines.
    /// </summary>
    public static class SlidingTabIndicatorBehavior
    {
        public static readonly DependencyProperty IsEnabledProperty;

        public static bool GetIsEnabled(DependencyObject obj);
        public static void SetIsEnabled(DependencyObject obj, bool value);
    }
}
```

### XAML Usage Contract:
```xaml
<TabView x:Name="AppTabView"
         controls:SlidingTabIndicatorBehavior.IsEnabled="True"
         SelectedIndex="{x:Bind ViewModel.SelectedTabIndex, Mode=TwoWay}"
         TabItemsSource="{x:Bind ViewModel.Tabs, Mode=OneWay}" />
```

---

## 3. `CachedContentControl` Viewport Host Contract

```csharp
namespace DataSphere.Controls
{
    /// <summary>
    /// A high-performance, MVVM-compliant viewport host control that retains rendered visual elements in memory
    /// and switches active content via visibility toggling combined with direction-aware horizontal WinUI 3 Compositor entrance transitions.
    /// </summary>
    public partial class CachedContentControl : Grid
    {
        public static readonly DependencyProperty ContentProperty;
        public static readonly DependencyProperty IsTransitionEnabledProperty;
        public static readonly DependencyProperty SelectedIndexProperty;

        /// <summary>
        /// Gets or sets the active content to display within the cached viewport.
        /// </summary>
        public object? Content { get; set; }

        /// <summary>
        /// Gets or sets a value indicating whether hardware-accelerated entrance transitions are enabled.
        /// </summary>
        public bool IsTransitionEnabled { get; set; }

        /// <summary>
        /// Gets or sets the current navigation index of the active tab, used to determine horizontal slide direction (+X vs -X).
        /// </summary>
        public int SelectedIndex { get; set; }

        public void Remove(UIElement element);
        public void Clear();
    }
}
```

### XAML Usage Contract:
```xaml
<controls:CachedContentControl Grid.Row="1"
                                IsTransitionEnabled="True"
                                Background="Transparent"
                                SelectedIndex="{x:Bind ViewModel.SelectedTabIndex, Mode=OneWay}"
                                Content="{x:Bind ViewModel.ActiveViewportContent, Mode=OneWay}" />
```
