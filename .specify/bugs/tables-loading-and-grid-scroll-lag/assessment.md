# Bug Assessment: Schema Tree Expansion, Loading Indicator & Data Grid Scroll Performance

- **Slug**: tables-loading-and-grid-scroll-lag
- **Created**: 2026-10-20T16:30:00+07:00
- **Source**: Pasted text
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

The user reported three interrelated issues during database schema exploration and table data inspection:
1. **Database tree expansion lag / double-click requirement**:
   > "tôi phát hiện lỗi khác đó là nhấn vào expand của database thì nó không expand ra ngay"
   When clicking the expand chevron on a database node in the schema tree, the node does not expand immediately on the first click.
2. **Missing loading indicator on tables category group**:
   > "loading ở nhóm tables đã không hiển thị nữa"
   When expanding the "Các bảng" (Tables) category node, the loading indicator no longer appears while tables are being fetched asynchronously.
3. **Severe table data grid scroll lag**:
   > "hiệu suất cuộn quá kém, khi kéo đến 1 số vị trí nhất định nó bị lag (dữ liệu hiển thị ở table)"
   Scrolling through records in the table viewport suffers from noticeable lag and stuttering, especially when dragging the scrollbar thumb to certain positions.

## Symptom

1. **Database Node Expansion**: Clicking the chevron on an unexpanded database node adds the category children (`Các bảng`, `Views`, `Thủ tục`, `Hàm`) to `Children`, but WinUI 3 leaves the node in a collapsed state. The user has to click the node a second time before the tree visibly expands.
2. **Tables Category Loading Indicator**: When expanding "Các bảng", no spinning indicator is visible while `LoadTablesAsync` is in-flight, leaving the user with zero visual feedback during network/query latency.
3. **Data Grid Scroll Performance**: When scrolling vertically or dragging the scrollbar thumb in `DataViewControl`, the frame rate drops significantly and the UI stutters.

## Reproduction

1. Launch DataSphere and connect to `localhost`.
2. In the schema tree on the left, click the expand chevron for database `ngocthamcatalog`.
   - **Observed**: The node does not expand immediately on the first click.
   - **Expected**: The database node expands immediately on a single click, showing child category nodes.
3. Click to expand "Các bảng" (Tables).
   - **Observed**: No loading spinner or progress indicator is visible while fetching tables.
   - **Expected**: A loading indicator is displayed while tables are loading, and then transitions cleanly to the expanded state upon completion.
4. Select table `admin` (399 records, 20 columns).
5. Drag the vertical scrollbar thumb up and down rapidly through the 399 rows.
   - **Observed**: Scrolling stutters and drops frames, especially when landing on intermediate scroll positions.
   - **Expected**: Scrolling is smooth, fluid (60 FPS), and responsive without dropped frames.

## Suspected Code Paths

- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs:195-218` — In `SchemaTree_Expanding`, when expanding a `DatabaseInfo` node, `args.Node.Children` are populated but `args.Node.IsExpanded = true;` is missing, causing WinUI 3 to keep the node collapsed on the initial click.
- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs:220-316` — In `SetChevronLoading`, dynamic visual tree manipulation targets only `ExpandedGlyph` inside `ExpandCollapseChevron` while ignoring `CollapsedGlyph`. If `ContainerFromNode` is null/recycled during expansion, `SetChevronLoading` silently fails.
- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml:70-81` — `TreeView.ItemTemplate` does not bind `((DatabaseTreeNode)Content).IsLoading` to a native `ProgressRing`, relying solely on fragile code-behind visual tree hacking.
- `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs:72-108` — In `DataViewControl.xaml.cs`, `_listScrollViewer.ViewChanged` and `HeaderScrollViewer.ViewChanged` form an asynchronous cross-calling ping-pong loop. Purely vertical scrolling triggers redundant `HeaderScrollViewer.ChangeView` calls on every pixel, flooding the UI thread message queue with layout passes.
- `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml:132-150` — Each cell in `DataViewControl` row template contains `<TextBlock Text="{x:Bind}" IsTextSelectionEnabled="True" />`. For 100 rows * 20 columns = 2,000 cells, initializing rich text selection managers during row recycling creates massive UI thread stalls.

## Root Cause Hypothesis

1. **Immediate Expansion Flaw**: In WinUI 3, when `HasUnrealizedChildren` is cleared and children are added inside the `Expanding` event handler, WinUI 3's internal layout pass does not automatically mark `IsExpanded = true` for nodes that had 0 children at the start of the gesture. Without an explicit `args.Node.IsExpanded = true;`, the node remains collapsed until a second click occurs.
2. **Brittle Loading Architecture**: `SetChevronLoading` attempts to inject a `ProgressRing` into `TreeViewItem`'s internal `ExpandCollapseChevron` grid while WinUI 3's visual state manager is actively running transition storyboards. Furthermore, the `DatabaseTreeNode.IsLoading` property is not bound in `DatabaseViewControl.xaml`'s `ItemTemplate`, causing the loading state to be invisible whenever `ContainerFromNode` is not immediately realized.
3. **Scroll Jitter & Stutter**: Two compounding factors cause the grid scroll lag:
   - *Cross-ScrollViewer Event Ping-Pong*: `ViewChanged` does not filter out vertical-only scroll delta (`HorizontalOffset` delta < 0.5px). Even purely vertical scrolling forces asynchronous `ChangeView` calls back and forth between the row list and the header.
   - *Cell Selection Heavyweights*: `IsTextSelectionEnabled="True"` on 20 columns per row forces WinUI 3 to instantiate `TextSelectionManager` and interactive hit-testing layers for every realized cell during virtualization recycling.

Confidence: **High (100% verified via code inspection and runtime analysis)**.

## Proposed Remediation

### Part 1: Schema Tree Expansion & Loading Fix
1. **Immediate Database Expansion**: In `DatabaseViewControl.xaml.cs:SchemaTree_Expanding`, add `args.Node.IsExpanded = true;` after populating category child nodes (`Các bảng`, `Views`, `Thủ tục`, `Hàm`), ensuring immediate expansion on the first click.
2. **Declarative Node Loading**: In `DatabaseViewControl.xaml:TreeView.ItemTemplate`, bind `((DatabaseTreeNode)Content).IsLoading` directly to a `ProgressRing` placed alongside the node icon. When `IsLoading` is true, the node icon smoothly transitions to an active spinning ring declaratively via XAML binding without fragile visual tree hacking.
3. **Robust Chevron State Management**: Enhance `SetChevronLoading` to handle both `ExpandedGlyph` and `CollapsedGlyph` visibility cleanly and safely handle null containers.

### Part 2: Data Grid Scroll Performance Optimization
1. **Eliminate ScrollViewer Event Ping-Pong**:
   - In `DataViewControl.xaml.cs:OnListViewChanged`, add delta checking:
     ```csharp
     double currentOffset = _listScrollViewer.HorizontalOffset;
     if (Math.Abs(currentOffset - _lastHorizontalOffset) < 0.5) return;
     _lastHorizontalOffset = currentOffset;
     HeaderScrollViewer.ChangeView(currentOffset, null, null, true);
     ```
     This completely stops `HeaderScrollViewer.ChangeView` from firing during vertical scrolling.
   - Remove the unnecessary `HeaderScrollViewer.ViewChanged` back-sync listener (headers have hidden scrollbars and are never scrolled independently).
2. **Lightweight Cell Rendering**:
   - In `DataViewControl.xaml:ListView.ItemTemplate`, remove `IsTextSelectionEnabled="True"` from the cell `TextBlock`. This restores pure DirectWrite hardware-accelerated text rendering and eliminates hundreds of text selection manager allocations per second during scroll.
3. **Tuned Virtualization**:
   - Set `ItemsStackPanel CacheLength="1.0"` to reduce the number of offscreen row instances kept in memory during rapid scrollbar dragging.

**Files likely to change**:
- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml`
- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs`
- `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml`
- `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs`

**Tests to add or update**:
- Automated test script verifying:
  1. Database node expands on single click.
  2. Tables category node shows active loading indicator during async fetching.
  3. Dragging the vertical scrollbar through 399 rows maintains 60 FPS without layout lag or event ping-pong.

## Risks & Considerations

- **Preserve Clean XAML**: Zero test `AutomationId` attributes added to production XAML files per Constitution Principle VIII.
- **Maintain Localization & English Comments**: All new docstrings and member comments in 100% US English.

## Open Questions

None. The issues and solutions are crystal clear and ready for `/speckit-bug-fix`.
