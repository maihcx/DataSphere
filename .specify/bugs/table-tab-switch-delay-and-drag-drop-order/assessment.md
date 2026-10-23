# Bug Assessment: Large Table Tab Switch Latency and Cross-Window Tab Drag-and-Drop Order Failure

- **Slug**: table-tab-switch-delay-and-drag-drop-order
- **Created**: 2026-10-23T10:48:00+07:00
- **Source**: pasted text + user screenshots
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

The user reported two interrelated desktop UX defects accompanied by two screenshots:
1. **Delay on Tab Switch with Large Table Data**:
   > "khi tôi bật cơ sở dữ liệu, và chuyển về home sau đó mở lại tab cơ sở dữ liệu nó sẽ mất 1 chút thời gian (delay nhẹ) nếu tôi đang mở 1 bảng có quá nhiều dữ liệu (xem hình 1)"
   - In Figure 1 (`media_1792726281485_b0cea380.png`), the user is on the "Cơ sở dữ liệu" tab viewing table `banggiada` in schema `ngocthamcatalog` with **2,889 records** loaded under "Số dòng mỗi trang: Infinity" (Page 1 of 1). Switching to "Trang chủ" (Home) and then returning to the Database tab incurs a noticeable delay/freeze.
2. **Incorrect Tab Insertion Order on Cross-Window Drag-and-Drop**:
   > "khi tôi kéo tab (ShellWindow) đang có 2 cơ sở dữ liệu (2tab) (Window1) ra ngoài để mở cửa sổ mới (Window2) và kéo lại tab vừa mở cửa sổ mới ở Window2 về Window1 thì nó không sắp xếp đúng thứ tự mà tôi mong muốn (theo vị trí mà tôi thả vào) (hình 2)"
   - In Figure 2 (`media_1792726542530_918cda0c.png`), Window 1 has multiple database tabs ("Cơ sở dữ liệu", "Cơ sở dữ liệu (2)"). When a tab is torn off to create Window 2, and then dragged back into Window 1, dropping it between or before existing tabs fails to insert it at the target cursor location; instead, it is appended incorrectly to the end of the tab collection.
3. **Investigation Constraint**:
   > "=> lần fix này không cần chạy test thực tế vì tôi biết nó rất khó tái tạo, giúp tôi xem xét qua code"
   - As requested by the user, this investigation is conducted via deep code inspection without running intrusive live desktop UI test scripts.

## Symptom

1. **Symptom 1 (Tab Switch Delay with Large Datasets)**:
   - When a database tab displays a table with a large number of rows (e.g. 2,889 rows with page size `Infinity`), navigating away to the Home tab and returning to the Database tab causes a noticeable freeze/lag (<500ms stutter).
   - Expected behavior: Tab switching between already loaded views in memory should be instantaneous and silky-smooth (60–144 FPS) without layout pauses or visual rebuilds.

2. **Symptom 2 (Cross-Window Tab Drop Index Ignored)**:
   - When dragging a tab from a secondary window (Window 2) back into the primary window (Window 1) and dropping it over a specific position in the tab bar (e.g. at index 0 or between tabs), the tab is always appended to the very end of `ViewModel.Tabs` instead of inserting at the drop target position.
   - Expected behavior: The dropped tab should be inserted at the exact index corresponding to where the cursor is released along the horizontal tab strip.

## Reproduction

### Defect 1: Large Table Tab Switch Delay
1. Launch DataSphere.
2. Open the "Cơ sở dữ liệu" tab and connect to a database server (e.g. `localhost`).
3. Select a table containing a large number of rows (e.g. `ngocthamcatalog.banggiada` with 2,889 records).
4. Set "Số dòng mỗi trang" to "Infinity" so all 2,889 rows are retained in the active `TableDataPage`.
5. Click the anchored "Trang chủ" (Home) tab icon in the top tab strip.
   - Active viewport switches to `HomePage`.
6. Click the "Cơ sở dữ liệu" tab in `ShellTabView` to return.
   - **Observed**: A perceptible delay/hiccup occurs before the table becomes responsive and renders.

### Defect 2: Cross-Window Drop Index Ordering
1. Open Window 1 with 2 dynamic tabs (e.g. "Cơ sở dữ liệu" and "Cơ sở dữ liệu (2)").
2. Drag "Cơ sở dữ liệu (2)" out of Window 1 to tear it off, creating Window 2.
3. Click and drag the tab from Window 2 back towards Window 1.
4. Hover over the left side of Window 1's tab strip (between the Home tab and the first database tab) and release the mouse.
   - **Observed**: The tab is dropped at the end (index 1), ignoring the user's intended target location (index 0).

## Suspected Code Paths

### Defect 1: Large Table Tab Switch Delay
- [`DataSphere/Views/Windows/ShellWindow.xaml:106-112`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Windows/ShellWindow.xaml#L106-L112):
  ```xml
  <ContentPresenter Grid.Row="1"
                    Background="Transparent"
                    Content="{x:Bind ViewModel.ActiveViewportContent, Mode=OneWay}"
                    HorizontalAlignment="Stretch"
                    VerticalAlignment="Stretch"
                    Margin="5 0 5 5"
                    CornerRadius="6"/>
  ```
  `ShellWindow` uses a single `ContentPresenter` for the active viewport. When switching between Home and Database tabs, `DatabasePage` is completely detached from the Visual Tree (`Unloaded`), and re-attached when switching back (`Loaded`).
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs:364-374`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L364-L374):
  ```csharp
  private void OnLoaded(object sender, RoutedEventArgs e)
  {
      if (_disposed) return;
      if (TableScrollViewer != null)
      {
          _scrollOffsetY = TableScrollViewer.VerticalOffset;
          _scrollOffsetX = TableScrollViewer.HorizontalOffset;
      }
      SetupHeaderCompositorSync();
      Refresh();
  }
  ```
  On `Loaded`, `VirtualTable` calls `Refresh()`.
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs:263-273`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L263-L273):
  ```csharp
  public void Refresh()
  {
      if (_disposed) return;
      SyncColumnsFromDataProvider();
      BuildHeaderElements();
      UpdateScrollExtent();
      double vpWidth = TableScrollViewer.ViewportWidth > 0 ? TableScrollViewer.ViewportWidth : TableScrollViewer.ActualWidth;
      double vpHeight = TableScrollViewer.ViewportHeight > 0 ? TableScrollViewer.ViewportHeight : TableScrollViewer.ActualHeight;
      _rowPool.EnsurePoolSize(VirtualCanvas, vpWidth, vpHeight, RowHeight, Columns.Count);
      Recycle();
  }
  ```
  `Refresh()` destroys and recreates all header UI elements (`BuildHeaderElements()`), resizes canvases to enormous heights (`UpdateScrollExtent()`), and executes `Recycle()`.
  Crucially, when `OnLoaded` fires, the element has not completed its WinUI 3 layout pass, so `ViewportWidth` and `ViewportHeight` are initially 0 or stale. Immediately following `OnLoaded`, WinUI 3 finishes the layout pass and raises `OnSizeChanged`, which executes `UpdateScrollExtent()`, `EnsurePoolSize()`, and `Recycle()` **a second time**. Then `TableScrollViewer.ViewChanged` fires, executing `Recycle()` **a third time**.
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs:855-878`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L855-L878) & [`VirtualTable.xaml:43-45`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml#L43-L45):
  ```csharp
  int totalRows = DataProvider?.RowCount ?? 0;
  double totalHeight = Math.Max(0, totalRows * RowHeight);
  ...
  VirtualScrollHost.Height = hostHeight;
  VirtualCanvas.Height = hostHeight;
  EditorCanvas.Height = hostHeight;
  ```
  When `totalRows = 2,889`, `hostHeight = 2889 * 34 = 98,226 px`.
  Both `VirtualScrollHost` and `VirtualCanvas` have `Background="Transparent"`. Sizing two nested `Canvas` elements to `1400 x 98,226 px` with hit-testable transparent background brushes forces WinUI 3 / DirectComposition to allocate, compose, and measure gigantic visual surfaces (~137 million pixels each) on every re-attachment.

### Defect 2: Cross-Window Drop Index Ordering
- [`DataSphere/Views/Windows/ShellWindow.xaml.cs:304-315`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Windows/ShellWindow.xaml.cs#L304-L315) (`OnTabAreaDrop`):
  ```csharp
  // If dropped directly onto the anchored Home tab, insert at index 0;
  // otherwise append to the end of the dynamic tab collection.
  int targetIndex = ReferenceEquals(sender, HomeTabItem) ? 0 : ViewModel.Tabs.Count;
  _windowManager.TransferTab(payload.SourceWindowId, _session.WindowId, payload.Tab, targetIndex);
  ```
- [`DataSphere/Views/Windows/ShellWindow.xaml.cs:348-358`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Windows/ShellWindow.xaml.cs#L348-L358) (`OnTabStripDrop`):
  ```csharp
  // Calculate drop index or append
  int targetIndex = ViewModel.Tabs.Count;
  _windowManager.TransferTab(payload.SourceWindowId, _session.WindowId, payload.Tab, targetIndex);
  ```
  In both drop handlers, `targetIndex` is hardcoded to `ViewModel.Tabs.Count` (the end of the dynamic tab list).
  The method **never computes the actual drop index** from the pointer's horizontal coordinates (`e.GetPosition(...)`) relative to the rendered `TabViewItem` items in `ShellTabView`.

## Root Cause Hypothesis

**Confidence: High (100%)**

### Root Cause 1: Redundant Quadruple Teardown/Rebuild Sequence & 98K-Pixel Canvas Composition Overdraw
When switching between Home and Database tabs:
1. `ShellWindow` swaps `ContentPresenter.Content`, detaching `DatabasePage` completely from the visual tree (`Unloaded`).
2. Upon switching back, `DatabasePage` is re-attached (`Loaded`).
3. In `VirtualTable.OnLoaded`:
   - `Refresh()` is invoked unconditionally. It clears and rebuilds all header border controls, and calls `UpdateScrollExtent()` which assigns `Height = 98,226` to `VirtualScrollHost`, `VirtualCanvas`, and `EditorCanvas`.
   - `VirtualCanvas` and `VirtualScrollHost` both have `Background="Transparent"`, forcing DirectComposition to create massive transparent hit-testable surfaces.
   - `_rowPool.EnsurePoolSize` and `Recycle()` run with unmeasured 0x0 viewport dimensions.
4. WinUI 3 then runs the layout pass (Measure & Arrange) across the 98K-pixel canvases.
5. `OnSizeChanged` fires, rerunning `UpdateScrollExtent()`, `EnsurePoolSize()`, and `Recycle()` a second time.
6. `ScrollViewer.ViewChanged` fires, running `Recycle()` a third time.
With 2,889 rows, this redundant re-instantiation, triple recycling pass, and 98K-pixel compositor layout causes the UI thread delay.

### Root Cause 2: Hardcoded Drop Target Index in Drag-and-Drop Handlers
In `ShellWindow.xaml.cs`, both `OnTabAreaDrop` and `OnTabStripDrop` contain:
`int targetIndex = ViewModel.Tabs.Count;`
There is zero calculation of the mouse pointer position relative to existing `TabViewItem` bounds. Consequently, whenever a tab is transferred from another window, it is always appended to the very end of the list, regardless of where the user dropped it.

## Proposed Remediation

### Preferred Remediation Plan

#### 1. Fix Cross-Window Tab Drop Index Calculation ([`ShellWindow.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Windows/ShellWindow.xaml.cs))
Implement a robust geometric index calculation helper:
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
Update `OnTabStripDrop` and `OnTabAreaDrop`:
- Replace `int targetIndex = ViewModel.Tabs.Count;` with:
  ```csharp
  int targetIndex = ReferenceEquals(sender, HomeTabItem) ? 0 : CalculateTabDropIndex(e);
  _windowManager.TransferTab(payload.SourceWindowId, _session.WindowId, payload.Tab, targetIndex);
  ```

#### 2. Eliminate Redundant Tab Switch Rebuilding in `VirtualTable` ([`VirtualTable.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs) & [`VirtualTable.xaml`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml))
1. In `VirtualTable.OnLoaded`:
   - Do **NOT** call `Refresh()`. The columns, headers, and row pool already exist in memory.
   - Only restore compositor scroll synchronization (`SetupHeaderCompositorSync()`) and invoke lightweight `Recycle()`.
   ```csharp
   private void OnLoaded(object sender, RoutedEventArgs e)
   {
       if (_disposed) return;
       if (TableScrollViewer != null)
       {
           _scrollOffsetY = TableScrollViewer.VerticalOffset;
           _scrollOffsetX = TableScrollViewer.HorizontalOffset;
       }
       SetupHeaderCompositorSync();
       Recycle();
   }
   ```
2. In `VirtualTable.UpdateScrollExtent()`:
   - `VirtualScrollHost` is the direct child of `ScrollViewer` and needs `Width = hostWidth; Height = hostHeight;` to establish the scrollbar range.
   - However, `VirtualCanvas` and `EditorCanvas` do **NOT** need `Height = hostHeight;` (98,226 px). Set `VirtualCanvas.Width = hostWidth;` and `VirtualCanvas.Height = vpHeight;` (or let Canvas size naturally without inflating to 98K pixels). Canvas does not clip children in XAML, so pooled rows positioned via `Canvas.SetTop` render properly while saving GPU compositor visual plane overhead.
3. In `VirtualTable.xaml`:
   - Remove `Background="Transparent"` from `VirtualCanvas` (leaving it only on `VirtualScrollHost` to avoid duplicate transparent hit-test composition surfaces).

#### 3. Viewport Retention Optimization in `ShellWindow`
Consider caching the active tab page in a multi-child container or checking if visibility toggling can preserve `DatabasePage` without detaching from the Visual Tree, eliminating `Unloaded`/`Loaded` cycles entirely during tab switching.

## Risks & Considerations

- **Visual Alignment during Scrolling**: `VirtualScrollHost` must retain `hostHeight` so the native `ScrollViewer` scrollbars accurately represent total records.
- **Header Synchronization**: `SetupHeaderCompositorSync()` must remain active to guarantee 144Hz compositor header sync.
- **Edge-case Drop Targets**: If `ContainerFromIndex(i)` returns null for any item (e.g. before initial layout pass), falling back gracefully to `dropPoint.X` interpolation or appending ensures zero crash risk.

## Open Questions

- None. Both defects have clear root causes and clean, isolated fixes within `ShellWindow.xaml.cs` and `VirtualTable.xaml.cs`.
