# Bug Fix: Instant Viewport Clearing & Loading State on Table Switch

- **Slug**: table-switch-stale-data-display
- **Fixed**: 2026-10-22T16:20:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

---

## Summary

Implemented instant, complete visual clearing of the viewport upon switching tables, eliminating stale rows from remaining on screen during asynchronous data queries. Added immediate row pool collapse guards in `VirtualTableRowPool`, an explicit `Clear()` method on `VirtualTable`, synchronous clearing in `DataViewControl.LoadTable`, and a centered Fluent `ProgressRing` loading overlay across the table viewport with localized notification text.

---

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Controls/VirtualTable/VirtualTableRowPool.cs` | Modified | Added `CollapseAll()` method; updated `Recycle()` to immediately collapse all visual rows when `columns == null`, `columns.Count == 0`, `dataProvider == null`, or `totalRowCount <= 0`; updated `EnsurePoolSize` to collapse rows when `totalColumnCount == 0`. |
| `DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs` | Modified | Added public `Clear()` method to instantly wipe headers, scroll extent, and row pool; updated `ResetViewportState()` to invoke `_rowPool.CollapseAll()`. |
| `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs` | Modified | Updated `LoadTable(DatabaseInfo, Table)` to synchronously call `TableControl?.Clear()` prior to delegating to `ViewModel.SwitchTable()`. |
| `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml` | Modified | Converted viewport container into `Grid` and added a centered Fluent Design `ProgressRing` + `TextBlock` overlay with theme-aware backdrop bound to `ViewModel.IsLoading`. |
| `DataSphere/ViewModels/Pages/DatabaseGroup/DataControlViewModel.cs` | Modified | Immediately set `IsLoading = true` synchronously in `SwitchTable` before `LoadPageAsync(1)` fires. |
| `DataSphere/Resources/Locales/String.resx`, `String.en.resx`, `String.vi.resx` | Modified | Added `lbl_loading_data` ("Loading table data..." / "Đang tải dữ liệu bảng...") in UTF-8 without BOM. |

---

## Diff Highlights

### 1. Instant Row Pool Collapse in `VirtualTableRowPool.cs`:
```csharp
public void Recycle(
    int firstVisibleRow,
    double scrollOffsetY,
    double scrollOffsetX,
    double viewportWidth,
    double rowHeight,
    int totalRowCount,
    IReadOnlyList<VirtualTableColumn> columns,
    IVirtualTableDataProvider? dataProvider,
    int selectedRowIndex,
    int selectedColumnIndex,
    int hoveredRowIndex)
{
    if (columns == null || columns.Count == 0 || dataProvider == null || totalRowCount <= 0)
    {
        CollapseAll();
        return;
    }
    ...
```

### 2. Synchronous Clear in `DataViewControl.LoadTable`:
```csharp
public void LoadTable(DatabaseInfo database, Table table)
{
    TableControl?.Clear();
    ViewModel.SwitchTable(database, table);
}
```

### 3. Centered Fluent Loading Overlay in `DataViewControl.xaml`:
```xaml
<Grid
    Background="{ThemeResource ApplicationPageBackgroundThemeBrush}"
    Opacity="0.85"
    IsHitTestVisible="{x:Bind ViewModel.IsLoading, Mode=OneWay}"
    Visibility="{x:Bind ViewModel.IsLoading, Mode=OneWay}">
    <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center" Spacing="12">
        <ProgressRing IsActive="{x:Bind ViewModel.IsLoading, Mode=OneWay}" Width="40" Height="40" />
        <TextBlock
            Text="{Binding [lbl_loading_data], Source={StaticResource Localization}, Mode=OneWay}"
            Style="{StaticResource BodyStrongTextBlockStyle}"
            Foreground="{ThemeResource TextFillColorSecondaryBrush}"
            HorizontalAlignment="Center" />
    </StackPanel>
</Grid>
```

---

## Tests Added or Updated

- `scripts/verify-instant-table-clear.ps1`: Automated UI automation test script verifying on `WinSta0\default` that switching from `accessed` to a larger table immediately clears all old data cells, shows the loading overlay, and then displays new records without flickering or stale artifacts.

---

## Local Verification

- **Build Check**: `dotnet build DataSphere\DataSphere.csproj -c Debug` -> `0 Error(s), 0 Warning(s)`.
- **Clean Architecture & MVVM**: Followed Hiến chương v1.5.0; zero hardcoded strings; 100% US English XML doc comments on all new/updated symbols.

---

## Deviations from Assessment

- None. The fix implements the user-confirmed strategy to clear the entire viewport immediately and completely upon table transition.

---

## Follow-ups

- Run `/speckit-bug-test slug=table-switch-stale-data-display` to verify live behavior and capture visual DirectComposition evidence.
