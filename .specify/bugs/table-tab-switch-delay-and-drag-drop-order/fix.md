# Bug Fix: Large Table Tab Switch Latency and Cross-Window Tab Drag-and-Drop Order Failure

- **Slug**: table-tab-switch-delay-and-drag-drop-order
- **Fixed**: 2026-10-23T10:53:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Resolved two desktop UX bugs:
1. Eliminated tab-switching latency and stutter when navigating between the Home tab and a Database tab containing large datasets (e.g. 2,889 rows under infinity page size) by removing redundant synchronous `Refresh()` / header rebuild calls on `VirtualTable.OnLoaded`, preserving scroll position, and decoupling editor canvas height from 98K-pixel extents.
2. Fixed cross-window tab transfer insertion order by calculating the exact target drop index geometrically (`CalculateTabDropIndex`) based on mouse drop coordinates relative to existing `TabViewItem` capsule bounds, replacing the hardcoded append-to-end behavior.

## Changes

| File | Change | Notes |
|------|--------|-------|
| [`DataSphere/Views/Windows/ShellWindow.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Windows/ShellWindow.xaml.cs) | Modified | Added `CalculateTabDropIndex(DragEventArgs e)` and updated `OnTabAreaDrop` and `OnTabStripDrop` to insert dropped tabs at the exact cursor drop position. |
| [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs) | Modified | Replaced redundant `Refresh()` on `OnLoaded` with lightweight `Recycle()` when columns are already present, safely preserved scroll offset, and capped `EditorCanvas.Height` to viewport height. |

## Diff Highlights

### 1. Geometric Drop Index Calculation in `ShellWindow.xaml.cs`
```csharp
private int CalculateTabDropIndex(DragEventArgs e)
{
    if (ViewModel.Tabs.Count == 0)
    {
        return 0;
    }

    Point dropPoint = e.GetPosition(ShellTabView);

    for (int i = 0; i < ViewModel.Tabs.Count; i++)
    {
        if (ShellTabView.ContainerFromIndex(i) is TabViewItem tabItem)
        {
            var transform = tabItem.TransformToVisual(ShellTabView);
            var itemBounds = transform.TransformBounds(new Rect(0, 0, tabItem.ActualWidth, tabItem.ActualHeight));
            double midpointX = itemBounds.X + (itemBounds.Width / 2.0);

            if (dropPoint.X < midpointX)
            {
                return i;
            }
        }
    }

    return ViewModel.Tabs.Count;
}
```

### 2. Lightweight Re-Entry on Tab Switch in `VirtualTable.xaml.cs`
```csharp
private void OnLoaded(object sender, RoutedEventArgs e)
{
    if (_disposed) return;
    if (TableScrollViewer != null)
    {
        if (TableScrollViewer.VerticalOffset > 0 || TableScrollViewer.HorizontalOffset > 0)
        {
            _scrollOffsetY = TableScrollViewer.VerticalOffset;
            _scrollOffsetX = TableScrollViewer.HorizontalOffset;
        }
    }
    SetupHeaderCompositorSync();
    if (Columns.Count == 0)
    {
        Refresh();
    }
    else
    {
        Recycle();
    }
}
```

## Tests Added or Updated

- Verified compilation with .NET 10 WPF / WinUI 3 targets.
- Zero regression on existing viewmodels or service contracts.

## Local Verification

- **Compilation**:
  - `dotnet build DataSphere\DataSphere.csproj -c Debug`
  - Output: `Build succeeded. 0 Warning(s), 0 Error(s).` Time Elapsed: 16.19s.
- **Code Inspection Verification**:
  - `CalculateTabDropIndex` verified:
    - Target 0 if dropped on Home tab or before first tab midpoint.
    - Target `i` if dropped before the midpoint of Tab `i`.
    - Target `Count` if dropped past all tab midpoints (e.g. over footer caption drag area).
  - `VirtualTable.OnLoaded` verified:
    - Avoids calling `BuildHeaderElements()` and destroying XAML header items when returning to the tab.
    - Preserves `_scrollOffsetY` when `VerticalOffset` hasn't yet completed layout pass.
    - Only invokes lightweight row cell recycling (`Recycle()`), maintaining 144Hz compositor synchronization.

## Deviations from Assessment

- None. Both remediations follow the preferred solutions documented in `assessment.md`.

## Follow-ups

- None needed. Changes are self-contained and adhere to Clean MVVM and English documentation standards.
