# Bug Assessment: Schema Tree Loading Ring Never Ends and Node Fails to Auto-Expand Post Load

- **Slug**: table-tree-loading-ring-and-expand
- **Created**: 2026-10-20T15:55:00+07:00
- **Source**: Pasted text + user screenshot (`media_1792486269689_a6ad564b.png`)
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

> "xem hình 1, tôi thấy trạng thái loading của nó không bao giờ kết thúc, và khi tải xong nó cũng không mở mà tôi lại phải nhấn vào 1 lần nữa để mở tree của tables"

## Symptom

1. **ProgressRing Never Ends / Stuck Spinning**: When expanding the `Các bảng` (Tables) category node, the blue spinning `ProgressRing` in the chevron slot remains visible and active indefinitely (visible across both `chat` and `download_service` nodes in the uploaded user screenshot), never restoring the standard expanded down-arrow chevron (`ˇ`).
2. **Failure to Open on First Click / Requires Second Click**: When the user clicks `Các bảng` to expand it, upon `LoadTablesAsync` completing, the tree does not actually reveal the tables; the user is forced to click on the node a second time to open the tree of tables.

## Reproduction & User Evidence

1. Connect to MySQL server (`localhost`).
2. Expand database `chat`.
3. Click the expand chevron or text of `Các bảng`.
4. Observe:
   - When loading completes, `Các bảng` remains visually collapsed.
   - The user must click `Các bảng` a second time to expand and reveal `chatrooms` and `chat_user_table`.
   - The `ProgressRing` continues spinning next to `Các bảng` forever and does not disappear.

### User Evidence Artifact
- **User Uploaded Screenshot**:
  ![User Evidence: Loading Ring Never Ends and Double Click Required](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/bug_loading_ring_never_ends.png)

## Suspected Code Paths

- [`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs:268-309`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs#L268-L309) (`SetChevronLoading`):
  - Line 268: `var ring = chevronGrid.FindName("ChevronLoadingRing") as ProgressRing;`
    In WinUI 3 XAML, elements created programmatically in code-behind via `new ProgressRing()` and added via `chevronGrid.Children.Add(ring)` are **NOT** registered in the XAML Namescope unless `RegisterName` is called. Therefore, `chevronGrid.FindName(...)` **always returns null**.
  - Lines 299-303: Because `ring` is `null`, `ring.IsActive = false;` and `ring.Visibility = Visibility.Collapsed;` are **never executed**. The `ProgressRing` remains active and visible in the visual tree forever.
  - Furthermore, every subsequent expansion creates and adds another `ProgressRing` to `chevronGrid.Children` without ever cleaning up the previous ones.
- [`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs:231-248`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs#L231-L248) (`SchemaTree_Expanding`):
  - `SchemaTree_Expanding` is an `async void` handler. When `args.Node.HasUnrealizedChildren = false;` is set and `await ViewModel.LoadTablesAsync(...)` is called, execution yields back to WinUI 3's dispatcher.
  - WinUI 3 finishes the synchronous expansion pass while `args.Node.Children` has 0 items. WinUI 3 therefore evaluates the node as empty and does not render expanded children.
  - When the async `await` returns and populates `args.Node.Children.Add(tableNode)`, `args.Node.IsExpanded = true;` was never re-applied. As a result, the node remains visually collapsed, forcing the user to click a second time.
- [`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs:347-350`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs#L347-L350) (`SchemaTree_ItemInvoked`):
  - Inverting `node.IsExpanded = !node.IsExpanded;` unconditionally on click conflicts with `Expanding` while async realization is in progress, causing double-toggle race conditions.

## Root Cause Hypothesis

**Confidence: High**

1. **`FindName` Failure on Unregistered Dynamic Visuals**: Calling `chevronGrid.FindName("ChevronLoadingRing")` fails to find dynamically injected controls. When `isLoading` becomes `false`, `ring` evaluates to `null`, meaning the cleanup code is skipped entirely. The `ProgressRing` is never deactivated, collapsed, or removed.
2. **Missing Post-Await Node Expansion**: In WinUI 3 `TreeView`, lazy loading with `HasUnrealizedChildren` and an asynchronous `await` completes the initial synchronous layout pass while `Children` is empty. Adding items after `await` does not automatically propagate visual expansion unless `args.Node.IsExpanded = true;` is explicitly assigned after children are added.
3. **ItemInvoked vs Expanding Collision**: Toggling `node.IsExpanded = !node.IsExpanded` indiscriminately in `ItemInvoked` collides with the chevron's internal expand trigger, collapsing the item right as it finishes realizing.

## Proposed Remediation

### Preferred Approach:
1. **Robust ProgressRing Lifecycle via Visual Children Query & Complete Removal**:
   - In `SetChevronLoading`, do not rely on `FindName`. Instead, directly query `chevronGrid.Children.OfType<ProgressRing>().ToList()`.
   - When `isLoading == true`:
     - Set `expandedGlyph.Opacity = 0;`.
     - Find or instantiate the `ProgressRing`, ensuring `IsActive = true` and `Visibility = Visibility.Visible`.
   - When `isLoading == false`:
     - Stop all `ProgressRing` instances (`IsActive = false`, `Visibility = Visibility.Collapsed`).
     - Remove them completely from `chevronGrid.Children` (`chevronGrid.Children.Remove(ring)`).
     - Restore `expandedGlyph.Opacity = 1;` so the downward chevron (`ˇ`) cleanly replaces the spinner.
2. **Explicit Post-Realization Expansion**:
   - In `SchemaTree_Expanding` for `TableCategoryContext`:
     - After populating `args.Node.Children` with `tableNode` items, explicitly set `args.Node.IsExpanded = true;`.
     - This guarantees that as soon as the tables are retrieved from the database, the node opens immediately on the first click without requiring any second click.
3. **ItemInvoked State Guard**:
   - In `SchemaTree_ItemInvoked`, only toggle expansion if the node is not currently loading (`!dtn.IsLoading`), preventing race conditions.

### Files Likely to Change:
- [`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs)
- [`scratch/VerifyDatabaseView/Program.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/scratch/VerifyDatabaseView/Program.cs)

### Tests to Add or Update:
- Update `VerifyDatabaseView` with tests verifying:
  - `SetChevronLoading` cleans up and removes `ProgressRing` instances from `chevronGrid.Children`.
  - `SchemaTree_Expanding` sets `args.Node.IsExpanded = true;` post-realization.
- Real desktop verification verifying single-click expansion and complete removal of the `ProgressRing` after load.

## Risks & Considerations

- Thread safety: `SetChevronLoading` and `args.Node.IsExpanded = true` must run on the UI thread (which is guaranteed inside `SchemaTree_Expanding`).
- Container recycling: Removing `ProgressRing` from `chevronGrid.Children` when loading stops ensures zero memory leaks or ghost controls when `TreeViewItem` containers are reused.

## Open Questions

- None. Both symptoms are clearly grounded in the code and demonstrated in the user's uploaded screenshot.
