# Bug Fix: Shift + Mouse Wheel Horizontal Scrolling in VirtualTable

- **Slug**: shift-wheel-horizontal-scroll
- **Fixed**: 2026-10-21
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Implemented standard desktop Shift + Mouse Wheel horizontal scrolling in `VirtualTable`. By attaching `PointerWheelChanged` to `VirtualScrollHost` and `HeaderBorder`, mouse wheel events with the `Shift` modifier key are intercepted before bubbling to `TableScrollViewer`'s vertical engine, smoothly transitioning the viewport's `HorizontalOffset` via `ChangeView` and preventing unwanted vertical row scrolling. Normal mouse wheel rotation (without Shift) continues to drive native DirectComposition kinetic vertical scrolling without interruption.

## Changes

| File | Change | Notes |
|------|--------|-------|
| [`DataSphere/Controls/VirtualTable/VirtualTable.xaml`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml) | Modified | Added `Background="Transparent"` to `VirtualScrollHost` and `VirtualCanvas` to ensure complete hit-test interception across the entire viewport surface. |
| [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs) | Modified | Wired `PointerWheelChanged` on `VirtualScrollHost` and `HeaderBorder`. Updated `UpdateScrollExtent` to clamp host width/height to at least viewport dimensions. Implemented `OnViewportPointerWheelChanged` to check `VirtualKey.Shift`, calculate horizontal step offset, call `TableScrollViewer.ChangeView`, and set `e.Handled = true`. |

## Diff Highlights

### 1. PointerWheelChanged Registration (`VirtualTable.xaml.cs`)
```csharp
VirtualCanvas.PointerPressed += OnViewportPointerPressed;
VirtualCanvas.PointerMoved += OnViewportPointerMoved;
VirtualCanvas.PointerExited += OnViewportPointerExited;
VirtualScrollHost.PointerWheelChanged += OnViewportPointerWheelChanged;
HeaderBorder.PointerWheelChanged += OnViewportPointerWheelChanged;
```

### 2. Viewport-Wide Hit Testing Extent (`VirtualTable.xaml.cs`)
```csharp
double vpWidth = TableScrollViewer.ViewportWidth > 0 ? TableScrollViewer.ViewportWidth : TableScrollViewer.ActualWidth;
double vpHeight = TableScrollViewer.ViewportHeight > 0 ? TableScrollViewer.ViewportHeight : TableScrollViewer.ActualHeight;

double hostWidth = Math.Max(totalWidth, vpWidth);
double hostHeight = Math.Max(totalHeight, vpHeight);

VirtualScrollHost.Width = hostWidth;
VirtualScrollHost.Height = hostHeight;
VirtualCanvas.Width = hostWidth;
VirtualCanvas.Height = hostHeight;
EditorCanvas.Width = hostWidth;
EditorCanvas.Height = hostHeight;
```

### 3. Shift + Wheel Interception & Smooth Horizontal Translation (`VirtualTable.xaml.cs`)
```csharp
private void OnViewportPointerWheelChanged(object sender, PointerRoutedEventArgs e)
{
    var props = e.GetCurrentPoint(TableScrollViewer).Properties;
    if (props.IsHorizontalMouseWheel)
    {
        return;
    }

    bool isShift = (InputKeyboardSource.GetKeyStateForCurrentThread(VirtualKey.Shift) & CoreVirtualKeyStates.Down) == CoreVirtualKeyStates.Down;
    if (isShift)
    {
        int delta = props.MouseWheelDelta;
        if (delta != 0)
        {
            double vpWidth = TableScrollViewer.ViewportWidth > 0 ? TableScrollViewer.ViewportWidth : TableScrollViewer.ActualWidth;
            double maxScrollX = Math.Max(0, VirtualScrollHost.Width - vpWidth);
            if (maxScrollX > 0)
            {
                double step = (delta / 120.0) * 150.0;
                double targetX = Math.Clamp(TableScrollViewer.HorizontalOffset - step, 0, maxScrollX);
                TableScrollViewer.ChangeView(targetX, null, null, disableAnimation: false);
            }
            e.Handled = true;
        }
    }
}
```

## Local Verification

- **Compilation**: `dotnet build DataSphere\DataSphere.csproj -c Debug` ➔ **0 Error(s), 0 Warning(s)**.
- **Automated Verification Script**: Ran [`scripts/verify-shift-wheel-horizontal-scroll.ps1`](file:///d:/DEV/C%23DOTNET/DataSphere/scripts/verify-shift-wheel-horizontal-scroll.ps1) on `WinSta0\default`:
  - **Test 1**: Holding `Shift` + rotating wheel downwards shifted the view horizontally to the right (`HorizontalOffset > 0`), revealing columns `username`, `password`, `token`, `email`, with 0 vertical scroll. Snapshot: [`winui_shift_wheel_horizontal_scrolled.png`](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/winui_shift_wheel_horizontal_scrolled.png).
  - **Test 2**: Holding `Shift` + rotating wheel upwards shifted back left to position 0, cleanly returning `id`, `mid`, `fullname` to the left border. Snapshot: [`winui_shift_wheel_scrolled_back_left.png`](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/winui_shift_wheel_scrolled_back_left.png).
  - **Test 3**: Rotating wheel downwards without `Shift` scrolled rows vertically down to records 12–41, with 0 horizontal offset shift. Snapshot: [`winui_wheel_scrolled_vertical_only.png`](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/winui_wheel_scrolled_vertical_only.png).

## Deviations from Assessment

None. The implementation followed the assessment plan, adding hit-test coverage on `VirtualScrollHost` and `HeaderBorder` for optimal ergonomics.
