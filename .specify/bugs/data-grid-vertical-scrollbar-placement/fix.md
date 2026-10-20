# Bug Fix: Detached Data Grid Vertical Scrollbar Placement

- **Slug**: data-grid-vertical-scrollbar-placement
- **Fixed**: 2026-10-20T16:21:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Refactored the two-tier database table viewport layout in `DataViewControl.xaml` and `DataViewControl.xaml.cs`. Removed the outer horizontal `ScrollViewer` that artificially stretched the inner `ListView` beyond the window boundaries. The `ListView` is now bounded by the viewport width with both vertical and horizontal scrollbars pinned to the visible window edges. Column headers are housed in a sticky `HeaderScrollViewer` at `Grid.Row="0"` and synchronized in real-time with the `ListView`'s internal horizontal scroll offset via `ViewChanged`.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml` | modified | Removed outer `ScrollViewer` wrapper; placed `HeaderScrollViewer` in Row 0 and bounded `ListView` with `ScrollViewer.VerticalScrollBarVisibility="Auto"` and `ScrollViewer.HorizontalScrollBarVisibility="Auto"` in Row 1. Added clean `ListView.ItemContainerStyle` with zero margins and identical cell alignment padding. |
| `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs` | modified | Added `_listScrollViewer` detection and two-way horizontal scroll synchronization via `ViewChanged` event handlers. Implemented recursive `FindVisualChild<T>` helper and clean detachment on unload/dispose. Added 100% US English XML documentation comments. |

## Diff Highlights

```xml
<!-- Column Headers in Sticky Synchronized ScrollViewer -->
<ScrollViewer
    x:Name="HeaderScrollViewer"
    Grid.Row="0"
    HorizontalScrollBarVisibility="Hidden"
    HorizontalScrollMode="Enabled"
    VerticalScrollBarVisibility="Disabled"
    VerticalScrollMode="Disabled">
    <Border MinWidth="{x:Bind ViewModel.DataPage.TotalTableWidth, Mode=OneWay}" Padding="8,8,24,8">
        ...
    </Border>
</ScrollViewer>

<!-- Virtualized Data Rows List Pinned to Viewport Boundaries -->
<ListView
    x:Name="DataRowsListView"
    Grid.Row="1"
    ItemsSource="{x:Bind ViewModel.DataPage.Rows, Mode=OneWay}"
    ScrollViewer.VerticalScrollBarVisibility="Auto"
    ScrollViewer.VerticalScrollMode="Enabled"
    ScrollViewer.HorizontalScrollBarVisibility="Auto"
    ScrollViewer.HorizontalScrollMode="Enabled">
```

```csharp
private void OnListViewChanged(object? sender, ScrollViewerViewChangedEventArgs e)
{
    if (_isSyncingScroll || _listScrollViewer == null || HeaderScrollViewer == null) return;
    try
    {
        _isSyncingScroll = true;
        HeaderScrollViewer.ChangeView(_listScrollViewer.HorizontalOffset, null, null, true);
    }
    finally
    {
        _isSyncingScroll = false;
    }
}
```

## Tests Added or Updated

- `scripts/verify-scrollbar-fix.ps1` — Real desktop automation verifying table expansion, data load (2055+ text elements for `ngocthamcatalog.admin`), viewport bounds, and live UI DirectComposition capture.

## Local Verification

- Build Command: `dotnet build DataSphere\DataSphere.csproj -c Debug` → **0 Warning(s), 0 Error(s)**.
- Real Desktop Execution: Tested on Windows desktop station (`WinSta0\default`) opening database `ngocthamcatalog`, expanding `Các bảng`, and opening table `admin` (399 rows, 20 columns).
- User Confirmation: User verified and confirmed that the vertical scrollbar is now active and functioning properly in the WinUI 3 desktop viewport.

## Deviations from Assessment

None. The preferred remediation from `assessment.md` was implemented verbatim.

## Follow-ups

- Proceed to verification and test report via `/speckit-bug-test slug=data-grid-vertical-scrollbar-placement`.
