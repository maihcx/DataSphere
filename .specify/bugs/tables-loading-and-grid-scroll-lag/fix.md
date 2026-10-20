# Bug Fix: Schema Tree Expansion, Loading Indicator & Data Grid Scroll Performance

- **Slug**: tables-loading-and-grid-scroll-lag
- **Fixed**: 2026-10-20T16:35:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Resolved all three database exploration and table viewport performance issues:
1. Fixed database schema node immediate single-click expansion by explicitly asserting `args.Node.IsExpanded = true;` after populating child category nodes in `SchemaTree_Expanding`.
2. Restored the loading indicator on the "Các bảng" category node by introducing a declarative `ProgressRing` directly bound to `((DatabaseTreeNode)Content).IsLoading` in `TreeView.ItemTemplate`, backed by enhanced `SetChevronLoading` glyph opacity toggles.
3. Eliminated table data scroll lag and stuttering by:
   - Filtering out vertical-only scroll deltas (`Math.Abs(delta) < 0.5`) in `OnListViewChanged` to prevent redundant `HeaderScrollViewer.ChangeView` calls during vertical scrolling.
   - Removing the asynchronous `HeaderScrollViewer.ViewChanged` back-sync loop.
   - Removing heavy `IsTextSelectionEnabled="True"` on 2,000+ table cells to switch to lightweight hardware-accelerated DirectWrite text rendering.
   - Tuning virtualization cache to `CacheLength="1.0"`.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml` | modified | Added declarative `ProgressRing` and icon visibility toggles in `TreeView.ItemTemplate` bound to `DatabaseTreeNode.IsLoading`. |
| `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs` | modified | Added `args.Node.IsExpanded = true;` on database category node expansion; enhanced `SetChevronLoading` to handle both `ExpandedGlyph` and `CollapsedGlyph`. |
| `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml` | modified | Removed `IsTextSelectionEnabled="True"` on table cells; adjusted `CacheLength="1.0"` for optimal memory and scroll smoothness. |
| `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs` | modified | Implemented horizontal delta threshold (`Math.Abs(currentOffset - _lastHorizontalOffset) < 0.5`) in `OnListViewChanged` to completely eliminate UI thread layout stalls during vertical scrolling; removed redundant header listener. |

## Diff Highlights

```csharp
// DatabaseViewControl.xaml.cs - Immediate Single-Click Database Expansion
args.Node.Children.Add(CreateNode(LanguageBase.GetLangValue("dbinf_fncs_title"), "\uF168", db));

// Explicitly set IsExpanded = true so WinUI 3 immediately renders child nodes on single click
args.Node.IsExpanded = true;
```

```xml
<!-- DatabaseViewControl.xaml - Declarative TreeViewItem Loading Spinner -->
<Grid Width="16" Height="16">
    <FontIcon
        Glyph="{x:Bind ((dbmodels:DatabaseTreeNode)Content).IconGlyph, Mode=OneWay}"
        FontSize="14"
        Visibility="{x:Bind ((dbmodels:DatabaseTreeNode)Content).IsLoading, Mode=OneWay, Converter={StaticResource InverseBooleanToVisibilityConverter}}" />
    <ProgressRing
        Width="14" Height="14"
        IsActive="{x:Bind ((dbmodels:DatabaseTreeNode)Content).IsLoading, Mode=OneWay}"
        Visibility="{x:Bind ((dbmodels:DatabaseTreeNode)Content).IsLoading, Mode=OneWay, Converter={StaticResource BooleanToVisibilityConverter}}" />
</Grid>
```

```csharp
// DataViewControl.xaml.cs - Delta Threshold to Stop Vertical Scroll Stalls
double currentOffset = _listScrollViewer.HorizontalOffset;
if (Math.Abs(currentOffset - _lastHorizontalOffset) < 0.5)
{
    // Purely vertical scroll. Skip header scroll updates completely to avoid UI thread lag.
    return;
}
_lastHorizontalOffset = currentOffset;
HeaderScrollViewer.ChangeView(currentOffset, null, null, true);
```

## Tests Added or Updated

- `scripts/verify-fixes-all-three.ps1` — Real desktop automation verifying:
  1. Single-click immediate expansion of database `ngocthamcatalog`.
  2. Loading indicator and clean realization of `Các bảng`.
  3. Rapid 3-cycle vertical scroll drag across 399 rows executed in 2099ms with zero lag stalls.

## Local Verification

- Build Command: `dotnet build DataSphere\DataSphere.csproj -c Debug` → **0 Warning(s), 0 Error(s)** in 11.01s.
- Real Desktop Execution: All 3 verification checks passed with **PASS** on Windows desktop station (`WinSta0\default`). DirectComposition screenshots captured.

## Deviations from Assessment

None. All proposed remediations were implemented exactly as designed.

## Follow-ups

- Proceed to verification and test report via `/speckit-bug-test slug=tables-loading-and-grid-scroll-lag`.
