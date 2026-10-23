# Component Contract: Viewport & Tab Transition Controls

**Feature**: Tab Switching Transition Animations (ShellWindow & DatabasePage)  
**Branch**: `017-tab-transition-animations`  
**Date**: 2026-10-23  

---

## 1. `CachedContentControl` Contract

```csharp
namespace DataSphere.Controls;

public partial class CachedContentControl : Microsoft.UI.Xaml.Controls.Grid
{
    /// <summary>
    /// Identifies the Content dependency property.
    /// </summary>
    public static readonly DependencyProperty ContentProperty;

    /// <summary>
    /// Identifies the IsTransitionEnabled dependency property.
    /// </summary>
    public static readonly DependencyProperty IsTransitionEnabledProperty;

    /// <summary>
    /// Gets or sets the active content to display.
    /// </summary>
    public object? Content { get; set; }

    /// <summary>
    /// Gets or sets whether compositor entrance transitions are enabled. Default is true.
    /// </summary>
    public bool IsTransitionEnabled { get; set; }

    /// <summary>
    /// Removes a specific visual element from the cache.
    /// </summary>
    public void Remove(UIElement element);

    /// <summary>
    /// Clears all cached visual elements.
    /// </summary>
    public void Clear();
}
```

---

## 2. `SlidingTabIndicatorBehavior` Contract

```csharp
namespace DataSphere.Controls;

public static class SlidingTabIndicatorBehavior
{
    /// <summary>
    /// Attached property to enable smooth sliding indicator on a TabView.
    /// </summary>
    public static readonly DependencyProperty IsEnabledProperty;

    /// <summary>
    /// Gets the IsEnabled attached property value.
    /// </summary>
    public static bool GetIsEnabled(DependencyObject obj);

    /// <summary>
    /// Sets the IsEnabled attached property value.
    /// </summary>
    public static void SetIsEnabled(DependencyObject obj, bool value);
}
```

---

## 3. XAML Consumption Contract

### In `ShellWindow.xaml`:
```xml
<!-- TabView with sliding indicator -->
<TabView x:Name="ShellTabView"
         controls:SlidingTabIndicatorBehavior.IsEnabled="True"
         ... />

<!-- Cached viewport with compositor entrance animation -->
<controls:CachedContentControl Grid.Row="1"
                               Content="{x:Bind ViewModel.ActiveViewportContent, Mode=OneWay}"
                               IsTransitionEnabled="True"
                               Margin="5 0 5 5"
                               CornerRadius="6" />
```

### In `DatabasePage.xaml`:
```xml
<!-- Inner TabView with sliding indicator -->
<TabView x:Name="InnerTabView"
         controls:SlidingTabIndicatorBehavior.IsEnabled="True"
         ... />

<!-- Cached inner viewport with compositor entrance animation -->
<controls:CachedContentControl Grid.Row="1"
                               Content="{x:Bind ViewModel.ActiveInnerContent, Mode=OneWay}"
                               IsTransitionEnabled="True" />
```
