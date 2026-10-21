# Bug Fix: Column Header Scroll De-sync and Initial Table Loading Latency

- **Slug**: header-scroll-sync-and-initial-table-latency
- **Fixed**: 2026-10-21
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Resolved the column header horizontal scroll de-sync by binding `HeaderCanvas.RenderTransform` to a `TranslateTransform` driven by `-_scrollOffsetX`, and eliminated the first-click table loading latency by detaching `Columns.CollectionChanged` notifications during schema population in `SyncColumnsFromDataProvider()`, reducing visual tree allocations from 135 redundant rebuild loops down to 1 single pass.

## Changes

| File | Change | Notes |
|------|--------|-------|
| [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs) | Modified | Replaced `Canvas.SetLeft(HeaderCanvas, ...)` with `UpdateHeaderScrollTransform()` using `TranslateTransform.X = -_scrollOffsetX`; clamped scroll positions in `UpdateScrollBars()`; suppressed `Columns.CollectionChanged` during `SyncColumnsFromDataProvider()`. |

## Diff Highlights

### 1. Synchronized Header Translation via TranslateTransform
```csharp
/// <summary>
/// Updates the horizontal translation transform of the column header canvas to synchronize with the viewport scroll position.
/// </summary>
private void UpdateHeaderScrollTransform()
{
    if (HeaderCanvas.RenderTransform is not TranslateTransform tt)
    {
        HeaderCanvas.RenderTransform = new TranslateTransform { X = -_scrollOffsetX };
    }
    else
    {
        tt.X = -_scrollOffsetX;
    }
}
```

### 2. Elimination of $O(N^2)$ First-Click Visual Tree Rebuild Loop
```csharp
if (!match)
{
    Columns.CollectionChanged -= OnColumnsCollectionChanged;
    try
    {
        Columns.Clear();
        foreach (var col in providerCols)
        {
            Columns.Add(col);
        }
    }
    finally
    {
        Columns.CollectionChanged += OnColumnsCollectionChanged;
    }
}
```

## Tests Added or Updated

- [`scripts/verify-header-scroll-and-latency.ps1`](file:///d:/DEV/C%23DOTNET/DataSphere/scripts/verify-header-scroll-and-latency.ps1): Automated desktop test script executing on `WinSta0\default` to verify sub-second table click latency and capture horizontal scroll synchronization.

## Local Verification

- **Compilation**: `dotnet build DataSphere\DataSphere.csproj -c Debug` → **0 Warning(s), 0 Error(s)**.
- **Initial Table Click Latency**: Reduced from **3,385 ms** down to **~381 ms** net click latency (over 8.8x faster initial render on 134-column table `banggiada`).
- **Header Synchronization**: Horizontal dragging of the scrollbar thumb translates column headers concurrently with data columns. Verified via DirectComposition capture to [`fixed_header_scroll_synced.png`](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/fixed_header_scroll_synced.png).

## Deviations from Assessment

None. The implementation followed the preferred remediation exactly.

## Follow-ups

- Proceed to validation and verification reporting via `/speckit-bug-test slug=header-scroll-sync-and-initial-table-latency`.
