# Phase 0: Technical Research & Architectural Findings

**Feature**: Tab Switching Transition Animations (ShellWindow & DatabasePage)  
**Branch**: `017-tab-transition-animations`  
**Date**: 2026-10-23  

---

## 1. WinUI 3 Composition Architecture for Viewport Transitions

### 1.1 Compositor vs. XAML Storyboard
- **XAML Storyboards (`DoubleAnimation`)**: Run on the UI thread and can suffer from frame drops or stutter when the UI thread is processing data virtualization or large data payloads (e.g. `VirtualTable` with 2,800+ records).
- **WinUI 3 Compositor (`Microsoft.UI.Composition`)**: Executes directly on the DirectComposition render thread, independent of the UI thread. Visual animations continue rendering fluidly at 60 FPS even if the UI thread is momentarily occupied.

### 1.2 Accessing the Visual via `ElementCompositionPreview`
```csharp
using Microsoft.UI.Xaml.Hosting;
using Microsoft.UI.Composition;

// Retrieve the underlying compositor visual for a UIElement
Visual visual = ElementCompositionPreview.GetElementVisual(uiElement);
Compositor compositor = visual.Compositor;
```

### 1.3 Motion Specs (Windows 11 Fluent Design Decelerate Curve)
- **Duration**: 167 milliseconds (`TimeSpan.FromMilliseconds(167)`).
- **Opacity Animation**: `ScalarKeyFrameAnimation`
  - Keyframe 0.0: `0.0f`
  - Keyframe 1.0: `1.0f` (Easing: Decelerate Cubic-Bezier `(0.1f, 0.9f, 0.2f, 1.0f)`)
- **Vertical Translation Animation**:
  - In WinUI 3, `ElementCompositionPreview.SetIsTranslationEnabled(element, true)` enables the compositor `"Translation"` property, or `Visual.Offset` can be animated directly.
  - Using `Vector3KeyFrameAnimation` for translation:
    - Keyframe 0.0: `new Vector3(0, 12, 0)` (+12px along Y axis)
    - Keyframe 1.0: `Vector3.Zero` (0px)
    - Easing: Decelerate Cubic-Bezier `(0.1f, 0.9f, 0.2f, 1.0f)`

### 1.4 Accessibility & System Reduced Motion Check
```csharp
using Windows.UI.ViewManagement;

private static readonly UISettings _uiSettings = new();
public static bool AreAnimationsEnabled => _uiSettings.AnimationsEnabled;
```
When `AnimationsEnabled == false`, animations are completely bypassed and transitions execute instantly (<1ms).

---

## 2. Sliding Selection Pill Architecture for TabView

### 2.1 Clean MVVM Attached Behavior Pattern
To adhere strictly to Constitution Principle I (Zero Code-Behind UI Manipulation in `ShellWindow.xaml.cs` and `DatabasePage.xaml.cs`), the sliding tab indicator is encapsulated as a reusable attached behavior:
```xml
<TabView x:Name="ShellTabView"
         controls:SlidingTabIndicatorBehavior.IsEnabled="True" ... />
```
- **ViewModel Independence**: ViewModels do not reference any visual types or animation objects.
- **View Code-Behind Independence**: `ShellWindow.xaml.cs` and `DatabasePage.xaml.cs` contain zero code-behind logic for indicator animation.
- **Component Placement**: Implemented in `DataSphere.Controls.SlidingTabIndicatorBehavior` alongside `CachedContentControl`.

### 2.2 Mechanism of Sliding Indicator
1. When `TabView` is loaded, `SlidingTabIndicatorBehavior` identifies the tab items container (`TabListView` / `ItemsPresenter`).
2. A lightweight compositor visual (or indicator `Border`) is created and positioned behind the active tab items.
3. When `TabView.SelectionChanged` occurs:
   - The selected `TabViewItem`'s target horizontal position `X` and width `W` are computed relative to the tab strip.
   - The indicator's `Visual` translates horizontally via `Vector3KeyFrameAnimation` targeting `Offset.X` and adapts width targeting `Size.X`.
   - Easing: Matching Windows 11 Decelerate curve (167ms).

---

## 3. Risk Mitigation & Edge Cases

| Risk / Edge Case | Analysis | Mitigation |
|---|---|---|
| **Rapid Tab Switching (Click Spamming)** | User clicks 5 tabs in rapid succession (<500ms). Multiple animations could overlap or leave views half-transparent. | In `CachedContentControl`, activating a new tab immediately hides all other views (`Visibility = Collapsed`), resets/supersedes any running animation on the newly active view to target (1.0 opacity, 0 translation). |
| **Tab Closed While Transitioning** | User closes a tab while it is still animating in. | Target view is removed from `CachedContentControl` cache via `Remove(element)`. Animation targets are disposed safely. |
| **Large Datasets (`VirtualTable`)** | Switching to a tab with 10,000+ rows might trigger compositor lag if entire visual subtree is re-evaluated. | Because `CachedContentControl` retains existing visual tree elements without recreating them, only root container `Visual.Opacity` and `Visual.Translation` are animated by the GPU compositor. Zero layout thrashing occurs. |
| **Mica/System Backdrop Glitches** | Animating root elements with Mica backdrops can cause transparency clipping. | `CachedContentControl` has `Background = Transparent` and animates child content elements (`UserControl` / `ViewControl`), keeping window background and titlebar steady. |
