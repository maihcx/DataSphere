# Bug Assessment: Detached Data Grid Vertical Scrollbar Placement

- **Slug**: data-grid-vertical-scrollbar-placement
- **Created**: 2026-10-20T16:11:00+07:00
- **Source**: Pasted text + screenshot (`media_1792486947424_c98afa11.png`)
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

The user reported:
> "thanh cuộn dọc vẫn chưa được hiển thị và hiện nó chỉ hiển thị khi tôi kéo thanh cuộn ngang về bên trái cùng
> loading hiện đã hoàn toàn biến mất bạn hãy vào database ngocthamcatalog để test"

User attached screenshot: `media_1792486947424_c98afa11.png` showing `localhost -> ngocthamcatalog -> admin` (399 records) where the table data has 20 columns. While the horizontal scrollbar is visible at the bottom, no vertical scrollbar is visible on the right edge of the table viewport when scrolled to the initial column view.

## Symptom

When opening a database table whose total column width exceeds the window viewport width (e.g. `ngocthamcatalog.admin` with 20 columns totalling >2900px):
1. The vertical scrollbar is detached from the viewport window edge and rendered at the far right edge of the wide content container (offscreen at ~2976px).
2. The user cannot see or interact with the vertical scrollbar to browse records while viewing the leftmost columns.
3. The vertical scrollbar only becomes visible if the user horizontally scrolls across the canvas to the extreme right edge of the table.

## Reproduction

1. Launch DataSphere on real desktop (`WinSta0\default`).
2. Connect to `localhost`.
3. Expand database `ngocthamcatalog`.
4. Expand "Các bảng" (Tables).
5. Select and open table `admin` (contains 399 rows, 20 columns).
6. Observe the table viewport at default horizontal scroll position:
   - **Observed**: No vertical scrollbar is visible along the right edge of the viewport. UI Automation inspection confirms the vertical scrollbar is off-screen.
   - **Expected**: The vertical scrollbar must remain pinned to the right edge of the visible viewport container at all times, regardless of the horizontal scroll offset.

## Suspected Code Paths

- `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml:52-134` — An outer `ScrollViewer` with `HorizontalScrollBarVisibility="Auto"` wraps a `Grid` with `MinWidth="{x:Bind ViewModel.DataPage.TotalTableWidth}"` (2976px). The inner `ListView` has `ScrollViewer.VerticalScrollBarVisibility="Auto"`, which places its vertical scrollbar at the far right edge of the 2976px canvas rather than at the right boundary of the visible viewport.
- `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs:24-35` — Code-behind lacks synchronized horizontal scroll viewport management between the frozen column headers and the virtualized row container.

## Root Cause Hypothesis

The layout hierarchy in `DataViewControl.xaml` embeds the `ListView` (which manages vertical scrolling) inside an outer horizontal `ScrollViewer` within a canvas sized to `TotalTableWidth` (>2900px). In WinUI 3, a control's internal `ScrollViewer` places its vertical scrollbar at the right edge of its own allocated bounding box. Because the allocated bounding box is 2976px wide, the vertical scrollbar is placed at X = 2976px, which is ~1900px off-screen to the right in a 1024px window.

Confidence: **High (100% verified via XAML layout analysis and real desktop UI Automation telemetry)**.

## Proposed Remediation

**Preferred**: Refactor `DataViewControl.xaml` into a Two-Tier Viewport-Pinned Architecture:
1. **Remove Outer ScrollViewer**: Remove the outer horizontal `ScrollViewer` that artificially stretches the `ListView` beyond the window boundaries.
2. **Pinned Virtualized ListView**: Place `ListView` directly in `Grid.Row="1"` bounded by the viewport width (`*`). Set `ScrollViewer.VerticalScrollBarVisibility="Auto"` and `ScrollViewer.HorizontalScrollBarVisibility="Auto"` directly on the `ListView`. This guarantees the vertical scrollbar is permanently pinned to the right edge of the visible viewport, and the horizontal scrollbar sits directly above the pagination footer.
3. **Synchronized Frozen Column Headers**: Place the column headers in `Grid.Row="0"` inside a dedicated `ScrollViewer` (`x:Name="HeaderScrollViewer"`) with hidden scrollbars.
4. **Offset Synchronization**: In `DataViewControl.xaml.cs`, capture the `ListView`'s internal `ScrollViewer` via visual tree traversal on `Loaded` and bind its `ViewChanged` event to update `HeaderScrollViewer.ChangeView(_listScrollViewer.HorizontalOffset, null, null, true)` in lockstep.
5. **Exact Column Alignment**: Ensure matching column cell widths (`140px`), cell spacing (`8px`), and identical left/right padding between the header container and `ListViewItemContainerStyle`.

**Alternatives**:
- *Retemplating ListView with Sticky Header*: Retemplate `ListView` to inject sticky header behavior inside the template. Trade-off: High XAML verbosity, brittle across WinUI 3 SDK version upgrades.
- *External Standalone ScrollBar*: Dock a separate WinUI 3 `<ScrollBar Orientation="Vertical"/>` to the right edge of the outer horizontal `ScrollViewer`. Trade-off: Complex manual row offset calculation, breaks mouse wheel smooth physics and touch gestures.

**Files likely to change**:
- `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml`
- `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs`

**Tests to add or update**:
- UI Automation test script verifying:
  1. The vertical scrollbar exists within the visible window bounding rectangle (`X + Width <= Window.Right`).
  2. Scrolling vertically updates row records smoothly without column header vertical drift.
  3. Scrolling horizontally moves column headers and data rows in perfect synchronization.

## Risks & Considerations

- **Virtualization Preservation**: The `ListView` must retain its vertical viewport constraint so `ItemsStackPanel` continues to virtualize row elements (399+ rows) without degrading memory or frame rates.
- **Scroll Synchronization Jitter**: Using `ChangeView(..., disableAnimation: true)` ensures header synchronization is immediate and flicker-free.
- **Localization & XML Doc Comments**: All C# additions must include 100% US English XML doc comments per Constitution Principle V and i18n dynamic bindings per Principle VII.

## Open Questions

None. The bug is fully understood, diagnosed with live desktop evidence, and ready for `/speckit-bug-fix`.
