# Research & Architecture Decisions: Fluent Tab Selection Pill, Sliding Background & Directional Page Motion

**Feature Branch**: `018-tab-motion-and-indicator`  
**Date**: 2026-10-23  
**Status**: Completed  

---

## 1. WinUI 3 Compositor ShapeVisual for Rounded Pill Indicator & Background Capsule

### Problem Statement
In previous iterations, `SlidingTabIndicatorBehavior` used a simple `SpriteVisual`, which only supports sharp rectangular geometry. This resulted in a crude, full-width underline indicator that lacked corner rounding and stretched across the entire width of the tab header. Furthermore, the tab selection background snapped immediately when selecting a new tab rather than moving fluidly between tabs.

### Technical Investigation
WinUI 3 (`Microsoft.UI.Composition`) provides `ShapeVisual` combined with `CompositionRoundedRectangleGeometry`:
1. `Compositor.CreateShapeVisual()`: Creates a visual surface hosting vector shapes.
2. `Compositor.CreateRoundedRectangleGeometry()`: Defines a rounded rectangle geometry with independent `Size` (`Vector2`) and `CornerRadius` (`Vector2`).
3. `Compositor.CreateSpriteShape(geometry)`: Binds the geometry with a `CompositionColorBrush` fill.
4. Adding `CompositionSpriteShape` to `ShapeVisual.Shapes`: Renders hardware-accelerated rounded pills off the UI thread without layout passes.

### Decisions & Implementation Approach
- **Accent Pill Indicator**:
  - Encapsulated in a dedicated `ShapeVisual` with `Size = new Vector2(20.0f, 3.0f)` and `CornerRadius = new Vector2(1.5f, 1.5f)`.
  - Positioned at `pillX = targetTab.X + (targetTab.Width - 20) / 2` and `pillY = targetTab.Y + targetTab.Height - 4`.
  - Animates `Offset` horizontally using `Vector3KeyFrameAnimation` over `TabMotionConfiguration.TabIndicatorDuration` (220ms–250ms) with Windows 11 Decelerate curve `(0.1, 0.9, 0.2, 1.0)`.
- **Sliding Background Capsule**:
  - Encapsulated in a dedicated background `ShapeVisual` with `CornerRadius = new Vector2(6.0f, 6.0f)` (matching `PillBorder.CornerRadius="6"` in `TabStyles.xaml`).
  - Size matches `(targetTab.Width, targetTab.Height - 4)`.
  - Offset matches `(targetTab.X, targetTab.Y + 2)`.
  - Animates both `Offset` and `Size` (when tabs differ in title length) using Decelerate easing.
  - Inserted behind tab header text via `containerVisual.Children.InsertAtBottom(...)` or before the indicator visual so text and icons render cleanly on top.
  - In `TabStyles.xaml`, `PillBorder.Background` in the `Selected` state is set to `Transparent` when sliding behavior is active, preventing color jumping and allowing the floating background capsule to glide seamlessly between tabs.

### Alternatives Considered
- *XAML Canvas Overlay with Border*: Rejected because managing XAML visual tree elements introduces layout passes, potential hit-test blocking, and cannot easily achieve off-thread compositor 60 FPS animation.
- *SpriteVisual with CompositionMaskBrush (image mask)*: Rejected as unnecessarily complex and resource-heavy compared to native `CompositionRoundedRectangleGeometry`.

---

## 2. Windows 11 System Accent Color Adherence

### Problem Statement
The previous indicator implementation hardcoded static blue values (`Color.FromArgb(255, 0, 95, 184)` for light theme and `Color.FromArgb(255, 96, 205, 255)` for dark theme). When users configured a custom Windows 11 accent color (e.g. Teal, Orange, Purple, Green), the indicator failed to adopt it.

### Technical Investigation
In Windows App SDK (WinUI 3):
1. `Application.Current.Resources["AccentFillColorDefaultBrush"]`: Provides the theme-adapted accent brush corresponding to the user's OS personalization settings.
2. `Application.Current.Resources["SystemAccentColor"]`: Provides the raw system accent color.
3. `Windows.UI.ViewManagement.UISettings.GetColorValue(UIColorType.Accent)`: Direct Win32 / UWP OS API to retrieve the current Windows personalization accent color.

### Decisions & Implementation Approach
- Implement a hierarchical color resolution chain in `SlidingTabIndicatorBehavior.GetAccentColor`:
  1. Primary: Check `Application.Current.Resources["AccentFillColorDefaultBrush"]` as `SolidColorBrush`.
  2. Secondary: Check `Application.Current.Resources["SystemAccentColor"]` as `Color`.
  3. Tertiary: Call `new UISettings().GetColorValue(UIColorType.Accent)`.
  4. Fallback: Default to Fluent system blue if running in headless test harnesses.
- Listen to `ActualThemeChanged` on the `TabView` to update both the accent indicator brush and the background capsule brush immediately upon theme switching.

---

## 3. Direction-Aware Horizontal Page Content Sliding Transition

### Problem Statement
The previous viewport entrance animation in `CachedContentControl` used a vertical slide (+12px Y-translation) for 167ms. The user requested:
1. Horizontal sliding motion according to the tab order (direction-aware).
2. A slightly longer duration so the transition is comfortably perceptible and smooth.

### Technical Investigation
To achieve spatial continuity:
- When switching from Tab A to Tab B where `Index(B) > Index(A)` (forward navigation): the target content should slide in from the right (`+32px -> 0px`).
- When switching from Tab B to Tab A where `Index(A) < Index(B)` (backward navigation): the target content should slide in from the left (`-32px -> 0px`).
- In `CachedContentControl`, the control can automatically detect the relative position of the incoming view relative to the outgoing view:
  1. Explicitly: Through a `SelectedIndex` or `NavigationIndex` bindable dependency property bound to `ViewModel.SelectedTabIndex`.
  2. Implicitly: By tracking `_previousContent` and comparing child indices in the cached `Children` collection.
- Duration: Increased to **300ms** (Option B selected by user) with a translation distance of **±32px** along the X-axis (`EntranceOffsetX = 32.0f`).
- Opacity: Fades in simultaneously from `0.0 -> 1.0` over the same 300ms with Windows 11 Decelerate cubic-bezier curve `(0.1f, 0.9f, 0.2f, 1.0f)`.

### Decisions & Implementation Approach
- Update `TabMotionConfiguration.cs`:
  - `ContentTransitionDuration = TimeSpan.FromMilliseconds(300);`
  - `EntranceOffsetX = 32.0f;`
  - Replace `EntranceOffsetY = 12.0f;` with `EntranceOffsetX`.
  - Maintain `AreAnimationsEnabled` for instant accessibility cutoff.
- Update `CachedContentControl.cs`:
  - Add optional `NavigationIndex` / `SelectedIndex` dependency property (int, default -1).
  - Track `_lastSelectedIndex` to determine slide direction (`+EntranceOffsetX` vs. `-EntranceOffsetX`).
  - Configure `Vector3KeyFrameAnimation` on `Translation` along the X-axis:
    `translationAnimation.InsertKeyFrame(0.0f, new Vector3(offsetX, 0, 0));`
    `translationAnimation.InsertKeyFrame(1.0f, Vector3.Zero, easing);`

---

## 4. Clean MVVM & Code-Behind Invariant Verification

### Principle Compliance
- No visual tree manipulation or child swapping in `ShellWindow.xaml.cs` or `DatabasePage.xaml.cs`.
- All motion behavior remains 100% self-contained within:
  - `DataSphere/Controls/TabMotionConfiguration.cs`
  - `DataSphere/Controls/SlidingTabIndicatorBehavior.cs`
  - `DataSphere/Controls/CachedContentControl.cs`
- Existing XAML files consume features declaratively through attached properties (`controls:SlidingTabIndicatorBehavior.IsEnabled="True"`) and compiled bindings (`Content="{x:Bind ViewModel.ActiveViewportContent, Mode=OneWay}"`).
