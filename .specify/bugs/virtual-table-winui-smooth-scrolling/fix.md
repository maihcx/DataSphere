# Bug Fix: Native WinUI 3 DirectComposition Hardware Smooth Scrolling

- **Slug**: virtual-table-winui-smooth-scrolling
- **Fixed**: 2026-10-21
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Replaced the custom `DispatcherTimer`-based software scroll animation in `VirtualTable` with canonical WinUI 3 architecture: native `ScrollViewer` backed by the Windows DirectComposition compositor thread (`InteractionTracker`). This eliminates all UI thread timer overhead, resolves mouse wheel stutter/jitter, restores native Windows 11 kinetic inertia and deceleration curves, and provides authentic Fluent Design 2 auto-hiding scrollbars.

## Changes

| File | Change | Notes |
|------|--------|-------|
| [`DataSphere/Controls/VirtualTable/VirtualTable.xaml`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml) | Modified | Replaced manual `ScrollBar` controls and `ViewportBorder` with a native `ScrollViewer` (`TableScrollViewer`) hosting `VirtualScrollHost`, `VirtualCanvas`, and `EditorCanvas`. |
| [`DataSphere/Controls/VirtualTable/VirtualTableRowPool.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTableRowPool.cs) | Modified | Shifted row positioning from viewport-relative to absolute data coordinates (`y = dataIndex * rowHeight`, `cellX = _columnOffsets[c]`). Increased pooled row buffer to `visibleCount + 6` and column buffer to `+ 8` for silky smooth kinetic scrolling. |
| [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs) | Modified | Removed `DispatcherTimer`, manual `_targetScroll` state, and custom mouse wheel interception. Wired `TableScrollViewer.ViewChanged` to sync header translation (`HeaderCanvas.RenderTransform.X = -_scrollOffsetX`) and recycle rows. Simplified cell editor overlay and pointer hit-testing to absolute data coordinates. |

## Diff Highlights

### 1. Native Fluent `ScrollViewer` (`VirtualTable.xaml`)
```xml
<ScrollViewer x:Name="TableScrollViewer"
              Grid.Row="1"
              HorizontalScrollBarVisibility="Auto"
              VerticalScrollBarVisibility="Auto"
              HorizontalScrollMode="Enabled"
              VerticalScrollMode="Enabled"
              ZoomMode="Disabled"
              Background="Transparent"
              BorderThickness="0">
    <Grid x:Name="VirtualScrollHost"
          HorizontalAlignment="Left"
          VerticalAlignment="Top"
          Background="Transparent">
        <Canvas x:Name="VirtualCanvas"
                HorizontalAlignment="Stretch"
                VerticalAlignment="Stretch"
                Background="Transparent"
                PointerPressed="OnViewportPointerPressed"
                PointerMoved="OnViewportPointerMoved"
                PointerExited="OnViewportPointerExited" />
        <Canvas x:Name="EditorCanvas"
                HorizontalAlignment="Stretch"
                VerticalAlignment="Stretch"
                IsHitTestVisible="True">
            <TextBox x:Name="CellEditorOverlay" ... />
        </Canvas>
    </Grid>
</ScrollViewer>
```

### 2. Viewport Extent Sizing & Event-Driven Row Recycling (`VirtualTable.xaml.cs`)
```csharp
private void UpdateScrollExtent()
{
    int totalRows = DataProvider?.RowCount ?? 0;
    double totalHeight = Math.Max(0, totalRows * RowHeight);

    double totalWidth = 0.0;
    foreach (var col in Columns) totalWidth += col.Width;

    VirtualScrollHost.Width = totalWidth;
    VirtualScrollHost.Height = totalHeight;
    VirtualCanvas.Width = totalWidth;
    VirtualCanvas.Height = totalHeight;
    EditorCanvas.Width = totalWidth;
    EditorCanvas.Height = totalHeight;

    double vpWidth = TableScrollViewer.ViewportWidth > 0 ? TableScrollViewer.ViewportWidth : TableScrollViewer.ActualWidth;
    double vpHeight = TableScrollViewer.ViewportHeight > 0 ? TableScrollViewer.ViewportHeight : TableScrollViewer.ActualHeight;

    _rowPool.EnsurePoolSize(VirtualCanvas, vpWidth, vpHeight, RowHeight, Columns.Count);
}

private void OnScrollViewerViewChanged(object? sender, ScrollViewerViewChangedEventArgs e)
{
    _scrollOffsetY = TableScrollViewer.VerticalOffset;
    _scrollOffsetX = TableScrollViewer.HorizontalOffset;

    UpdateHeaderScrollTransform();
    Recycle();
}
```

### 3. Absolute Data Coordinate Placement in Row Pool (`VirtualTableRowPool.cs`)
```csharp
row.DataRowIndex = dataIndex;

double y = dataIndex * rowHeight;
Canvas.SetTop(row.VisualBorder, y);
Canvas.SetLeft(row.VisualBorder, 0);
row.VisualBorder.Width = runningLeft;

// Place cells at absolute column offsets
for (int c = firstVisibleCol; c <= lastVisibleCol; c++)
{
    string text = dataProvider.GetCellText(dataIndex, c);
    bool isCellSelected = row.IsSelected && (selectedColumnIndex == -1 || selectedColumnIndex == c);
    double cellX = _columnOffsets[c];
    row.UpdateCell(slot, text, columns[c].Width, cellX, isCellSelected);
    slot++;
}
```

## Local Verification

- **Compilation**: `dotnet build DataSphere\DataSphere.csproj -c Debug` ➔ **0 Error(s), 0 Warning(s)**.
- **Automated Verification Script**: Executed `scripts/verify-winui-smooth-scroll.ps1` on `WinSta0\default`:
  - Connected to live MySQL instance, expanded `ngocthamcatalog` database, and opened `admin` table.
  - Dispatched 6 rapid mouse wheel downward events. Verified zero UI thread lag, native kinetic deceleration, and smooth row updates.
  - Snapshot saved: [`winui_smooth_scrolled_rows.png`](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/winui_smooth_scrolled_rows.png).
  - Executed column splitter drag resize to verify column headers, visual rows, and splitters respond smoothly.
  - Snapshot saved: [`winui_column_resized.png`](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/winui_column_resized.png).

## Deviations from Assessment

None. The implementation followed the recommended canonical WinUI 3 architecture outlined in the assessment report.
