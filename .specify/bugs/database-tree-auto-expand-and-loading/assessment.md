# Bug Assessment: Database Schema Tree Auto-Expand and Chevron Loading State

- **Slug**: database-tree-auto-expand-and-loading
- **Created**: 2026-10-20T15:35:00+07:00
- **Source**: Pasted text
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

> "khi tôi mở tree database, nó ngay lập tức mở table, giúp tôi chỉnh sửa hành vi đó, mở database không mở luôn cả table
> khi mở table tôi muốn dấu mủi tên nhảy xuống phải chuyển về trạng thái loading và khi loading xong nó phải hiển thị nhảy xuống"

## Symptom

1. **Unwanted Auto-Expansion**: Expanding a database catalog node (e.g., `chat`) in `SchemaTree` immediately auto-expands the nested `Các bảng` (`Tables`) category node and realizes all database tables in one shot, rather than keeping the table category collapsed.
2. **Missing Chevron Loading State**: Expanding the table category node (`Các bảng` / `Tables`) immediately flips or retains the chevron glyph without displaying any visual loading feedback (such as a spinning `ProgressRing` or loading state) while asynchronously querying tables from MySQL (`LoadTablesAsync`), only rendering the expanded down-arrow once the request resolves.

**Expected Behavior**:
- Expanding a database node must only reveal its category nodes (`Các bảng`, `Views`, `Thủ tục lưu trữ`, `Hàm`), leaving the `Các bảng` category in a **collapsed** state (`IsExpanded = false`) with an unrealized right-pointing chevron (`>`).
- When the user explicitly clicks the chevron to expand `Các bảng` (`Tables`), the chevron must transition into an active **loading state** (WinUI 3 spinning `ProgressRing`) while `LoadTablesAsync` is in-flight. Once table realization completes, the loading indicator must transition to the standard expanded downward-pointing chevron (`ˇ`) displaying the realized table list.

## Reproduction & Diagnostic Evidence

1. Launch DataSphere on real desktop (`WinSta0\default`).
2. Connect to an active MySQL server (e.g., `localhost`).
3. Under the server connection root, locate the `chat` database tree item.
4. Click the expand chevron for `chat`.
5. Observe: `chat` expands and simultaneously auto-expands `Các bảng`, populating all tables (`admin`, `chat_user_table`, `chatrooms`) without user interaction on the table node.

### Real Desktop Diagnostic Evidence
- **Diagnostic Execution Script**: [`scripts/reproduce-auto-expand.ps1`](file:///d:/DEV/C%23DOTNET/DataSphere/scripts/reproduce-auto-expand.ps1)
- **DirectComposition Snapshot**:
  ![Diagnostic Evidence: Auto-Expand Bug](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/bug_auto_expand_reproduction.png)

## Suspected Code Paths

- [`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs:176-188`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs#L176-L188):
  - Line 177 explicitly executes `tablesCatNode.IsExpanded = true;`, forcing immediate expansion of the table category node as soon as the parent database node expands.
  - Line 172 calls `await ViewModel.LoadTablesAsync(db);` eagerly during database node expansion rather than deferring to table category node expansion.
  - `SchemaTree_Expanding` lacks handling for expanding category nodes (e.g., `TableCategoryContext`), where loading feedback and realization should occur.
- [`DataSphere/Models/Database/DatabaseTreeNode.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Models/Database/DatabaseTreeNode.cs):
  - `DatabaseTreeNode` does not implement `ObservableObject` and lacks an `IsLoading` property to signal node-level async loading states.
- [`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml:59-82`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml#L59-L82):
  - `SchemaTree` does not define an `ItemContainerStyle` for `TreeViewItem` to accommodate a dynamic `ProgressRing` replacing or overlaying the chevron down glyph (`ExpandedGlyph`) when `IsLoading` is active.

## Root Cause Hypothesis

**Confidence: High**

1. In `DatabaseViewControl.xaml.cs` line 177, `tablesCatNode.IsExpanded = true;` was hardcoded during tree construction, which instructs WinUI 3's `TreeView` to expand the child node automatically upon insertion.
2. `ViewModel.LoadTablesAsync(db)` was executed inside the database node's `SchemaTree_Expanding` handler instead of delegating lazy loading to the `tablesCatNode` itself via `HasUnrealizedChildren = true;`.
3. WinUI 3 `TreeViewItem`'s default template renders a static `ExpandedGlyph` (`\uE70D`) and `CollapsedGlyph` (`\uE76C`), with no native loading state. When `HasUnrealizedChildren` is realized asynchronously, `TreeViewItem` does not toggle glyphs without an explicit loading indicator bound to the node's loading state.

## Proposed Remediation

### Preferred Approach:
1. **Deferred Lazy Loading & Collapsed Default**:
   - In `DatabaseViewControl.xaml.cs`, modify `SchemaTree_Expanding` for `DatabaseInfo db`:
     - Create `tablesCatNode` with `tablesCatNode.IsExpanded = false;`.
     - Assign `tablesCatNode.HasUnrealizedChildren = true;` and a dedicated context `TableCategoryContext(db)`.
     - Do not call `LoadTablesAsync` inside the database node handler. Database expansion is now instantaneous (<1ms).
   - Add handling in `SchemaTree_Expanding` for `TableCategoryContext`:
     - Mark the node's `DatabaseTreeNode.IsLoading = true;`.
     - Await `ViewModel.LoadTablesAsync(context.Database);`.
     - Populate `tablesCatNode.Children` with `tableNode` items.
     - Set `tablesCatNode.HasUnrealizedChildren = false;`.
     - Reset `DatabaseTreeNode.IsLoading = false;`.
2. **Dynamic Chevron Loading Transition**:
   - Update `DatabaseTreeNode` to inherit from `ObservableObject` and expose `[ObservableProperty] private bool _isLoading;`.
   - In `DatabaseViewControl.xaml`, define an `ItemContainerStyle` targeting `TreeViewItem` where the `ExpandCollapseChevron` section features:
     - The standard `CollapsedGlyph` (visible when collapsed).
     - The standard `ExpandedGlyph` (visible when expanded AND `IsLoading == false`).
     - A compact WinUI 3 `ProgressRing` (`Width="12" Height="12" IsActive="{Binding ...}"`) centered in the chevron slot (visible when `IsLoading == true`).
   - Alternatively/Complimentarily, in `DatabaseViewControl.xaml.cs`, when `Expanding` triggers on `tablesCatNode`, toggle `treeViewItem.ExpandedGlyph` to empty or manage the `ProgressRing` visibility so the down-arrow morphs smoothly into a spinner and reverts to `\uE70D` upon completion.

### Files Likely to Change:
- [`DataSphere/Models/Database/DatabaseTreeNode.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Models/Database/DatabaseTreeNode.cs)
- [`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml)
- [`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs)

### Tests to Add or Update:
- Update UI Automation verification script ([`scripts/verify-real-end-to-end.ps1`](file:///d:/DEV/C%23DOTNET/DataSphere/scripts/verify-real-end-to-end.ps1)) to:
  1. Verify expanding database `chat` leaves `Các bảng` collapsed (`HasUnrealizedChildren = true`, table nodes not visible).
  2. Click `Các bảng` chevron, capture in-flight loading state on the chevron slot.
  3. Verify post-load state displays expanded downward chevron (`ˇ`) and realizes table nodes.

## Risks & Considerations

- **Virtualization & Container Recycling**: Using `ItemContainerStyle` with compiled bindings or proper `DataContext` resolution must handle container recycling cleanly to prevent binding errors or memory leaks.
- **Thread Safety**: Property notification for `IsLoading` must remain bound to the UI dispatcher thread.
- **Zero-AutomationId Invariant**: All automated verifications must rely strictly on geometric and control-type hierarchy, maintaining zero test pollution in production XAML.

## Open Questions

- None. Both requirements are well-defined and validated against the live application behavior.
