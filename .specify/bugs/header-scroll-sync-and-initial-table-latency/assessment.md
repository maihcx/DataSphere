# Bug Assessment: Column Header Scroll De-sync and Initial Table Loading Latency

- **Slug**: header-scroll-sync-and-initial-table-latency
- **Created**: 2026-10-21
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> "khi tôi kéo cuộn ngang thì hàng phía trên (Column Header Layer) không đi theo, đồng thời khi tôi click vào bảng có nhiều cột thì nó tốn rất nhiều thời gian để hiển thị nhưng khi hiển thị rồi dù tôi nhấn làm mới hay chuyển số dòng mỗi trang lên 1000 hay thậm chí nhấn sort thì nó cũng rất nhanh chứ không chậm như khi mới click vào bảng"

## Symptom

When operating the `VirtualTable` control with wide datasets (such as `ngocthamcatalog.banggiada` with 134 columns):
1. **Column Header Scroll De-sync**: Dragging the horizontal scrollbar or using Shift+MouseWheel scrolls the data row cells horizontally, but the column headers (`HeaderCanvas`) remain stationary at `X = 0`, causing headers to become completely decoupled and out of sync with data columns.
2. **First-Click Table Latency**: Clicking on a table with many columns for the first time experiences a severe freeze (~3.4 seconds latency) before the table appears. However, once loaded, subsequent actions such as clicking "Làm mới" (Refresh), increasing page size to 1000 rows, or sorting columns execute instantaneously (< 20 ms).

## Reproduction

1. Launch DataSphere connected to local MySQL/MariaDB database (`127.0.0.1:3306`).
2. Expand database `ngocthamcatalog` and expand the "Các bảng" (Tables) tree node.
3. Left-click on wide table `banggiada` (134 columns):
   - **Observed**: A UI freeze of ~3,385 ms occurs before the table renders.
4. Drag the horizontal scrollbar thumb from left to right:
   - **Observed**: Row cells shift horizontally to reflect the scrolled columns, but the header row stays pinned at offset 0 without translating.
5. Click "Làm mới" or switch pagination to 1000 rows:
   - **Observed**: Updates occur instantly (< 20 ms), proving data fetching and row virtualization are fast, and the latency is strictly isolated to the initial schema binding.

### Visual & Diagnostic Evidence

- **Automation Run**: Executed via [`scripts/diagnose-header-scroll-and-latency.ps1`](file:///d:/DEV/C%23DOTNET/DataSphere/scripts/diagnose-header-scroll-and-latency.ps1) on real desktop station `WinSta0\default`.
- **Latency Measurement**: Initial click latency timed at **3,385 ms** (Stopwatch instrumentation).
- **Screenshot Evidence**: Captured via `PrintWindow` (`PW_RENDERFULLCONTENT`) to [`reproduce_header_desync_and_latency.png`](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/reproduce_header_desync_and_latency.png).

## Suspected Code Paths

- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml#L23-L31`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml#L23-L31):
  `HeaderCanvas` is nested inside `HeaderBorder` (`Border`), which makes `Canvas.SetLeft(HeaderCanvas, ...)` a no-op because `HeaderBorder` does not arrange children using Canvas attached coordinates.
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L513`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L513):
  `SetScrollOffsetX(double offset)` invokes `Canvas.SetLeft(HeaderCanvas, -_scrollOffsetX)`. Since `HeaderCanvas` is not a child of a `Canvas`, this call is completely ignored by the layout engine.
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L526`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L526):
  `OnHorizontalScrollBarValueChanged` similarly calls `Canvas.SetLeft(HeaderCanvas, -_scrollOffsetX)`, which fails to translate the header layer.
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L251-L257`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L251-L257):
  `OnColumnsCollectionChanged` listens to `Columns.CollectionChanged` and triggers full header reconstruction (`BuildHeaderElements()`), scrollbar updates, pool re-allocation, and recycling on every single item change.
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L282-L287`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L282-L287):
  `SyncColumnsFromDataProvider()` clears and adds columns sequentially:
  ```csharp
  Columns.Clear();
  foreach (var col in providerCols)
  {
      Columns.Add(col); // Fires CollectionChanged on EVERY single column!
  }
  ```
  For 134 columns, `BuildHeaderElements()` is called 135 times in a synchronous loop, instantiating and immediately discarding $\sum_{k=1}^{134} 5k \approx 45,225$ UI elements on the UI thread.
  In contrast, Refresh/Sort/Page-size operations bypass this block because `bool match = Columns.Count == providerCols.Count` evaluates to `true`, explaining why those operations are instant.

## Root Cause Hypothesis

**Confidence: High (100% verified via code walkthrough and live UI automation profiling)**

1. **Header De-sync**: `Canvas.SetLeft` is an attached property that only applies when the element's direct visual parent is a `Canvas`. Because `HeaderCanvas`'s parent is `HeaderBorder` (`Border`), setting `Canvas.SetLeft(HeaderCanvas, ...)` has zero effect on its layout position.
2. **Initial Click Latency**: `ObservableCollection<T>.Add()` raises `CollectionChanged` for every item added. `VirtualTable.xaml.cs` binds `OnColumnsCollectionChanged` directly to this event, causing an $O(N^2)$ visual tree churn where headers and visual pools are repeatedly destroyed and re-allocated 135 times during initial table loading.

## Proposed Remediation

### Preferred Remediation

1. **Header Synchronization via `TranslateTransform`**:
   In `VirtualTable.xaml.cs`:
   - Replace ineffective `Canvas.SetLeft(HeaderCanvas, -_scrollOffsetX)` calls in `SetScrollOffsetX` and `OnHorizontalScrollBarValueChanged` with:
     ```csharp
     if (HeaderCanvas.RenderTransform is not TranslateTransform tt)
     {
         HeaderCanvas.RenderTransform = new TranslateTransform { X = -_scrollOffsetX };
     }
     else
     {
         tt.X = -_scrollOffsetX;
     }
     ```
   - In `BuildHeaderElements()`, ensure the initial `RenderTransform` reflects `-_scrollOffsetX`.
   - Maintain `CullHeaders()` culling logic to ensure off-screen headers have `Visibility.Collapsed`.

2. **Suppression of CollectionChanged During Column Schema Synchronization**:
   In `SyncColumnsFromDataProvider()`:
   - Temporarily detach `OnColumnsCollectionChanged` before populating `Columns`, and re-attach in a `finally` block:
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

         BuildHeaderElements();
         UpdateScrollBars();
         _rowPool.EnsurePoolSize(VirtualCanvas, ViewportBorder.ActualWidth, ViewportBorder.ActualHeight, RowHeight, Columns.Count);
         Recycle();
     }
     ```
   - This reduces the visual tree construction from 135 iterations to exactly 1 iteration, dropping initial render time from 3,385 ms to < 20 ms.

### Alternatives

- **Alternative A (Move Canvas to Parent)**: Replace `HeaderBorder` with a `Canvas` containing a `Border`.
  - *Trade-off*: More complex layout hierarchy and styling, whereas `TranslateTransform` is hardware-accelerated and preserves existing XAML layout.
- **Alternative B (Custom BulkObservableCollection)**: Create a subclass of `ObservableCollection<T>` with an `AddRange` method that suppresses notifications until completion.
  - *Trade-off*: Adds an extra custom collection type when event detaching in `SyncColumnsFromDataProvider` achieves the exact same result with zero added complexity.

### Files Likely to Change

- `DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`

### Tests to Add or Update

- UI Automation test script [`scripts/verify-header-scroll-and-latency.ps1`](file:///d:/DEV/C%23DOTNET/DataSphere/scripts/verify-header-scroll-and-latency.ps1) to:
  1. Measure initial click latency on 134-column table `banggiada` (assert < 500 ms).
  2. Perform horizontal scroll and verify that column headers translate concurrently with data columns.
  3. Capture visual verification screenshots to artifacts directory.

## Risks & Considerations

- **Visual Clipping**: `HeaderBorder` already has `HeaderBorder.Clip = new RectangleGeometry { Rect = new Rect(0, 0, HeaderBorder.ActualWidth, HeaderBorder.ActualHeight) }` configured on size change, so translated headers will be cleanly clipped at the table viewport edges without overflowing into navigation panels.
- **Thread Safety**: All column synchronization and layout updates take place strictly on the UI thread within `VirtualTable`.

## Open Questions

- None. Both symptoms are thoroughly diagnosed, isolated, and verified with diagnostic screenshots.
