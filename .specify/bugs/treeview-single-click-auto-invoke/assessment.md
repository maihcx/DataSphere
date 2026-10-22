# Bug Assessment: TreeView Single-Click Auto-Invoking Session and Expanding Nodes

- **Slug**: `treeview-single-click-auto-invoke`
- **Created**: 2026-10-22T14:38:00+07:00
- **Source**: "ở các treeview như localhost ở tab kết nối (hình 1), các treeview con ở tab database (hình 2) tôi không thích nhấn chuột vào TreeViewItem để mở ngay lập tức item, hiện tại ở tab kết nối tôi nhấn chuột là nó mở ngay lập tức database đó ra (tôi không muốn vậy), ở bên quản lý csdl cũng vậy luôn (tôi cũng không muốn hành vi đó, hiện tại vừa nhấn vào TreeViewItem là nó mở tree ra luôn)"
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

The user reported two intrusive single-click behaviors across the application's tree navigation views:
1. **Connections Explorer (`ConnectViewControl`)**: Single-clicking a connection tree item (e.g. `localhost`) immediately opens a database session workspace tab, preventing the user from simply selecting or focusing the item.
2. **Database Schema Explorer (`DatabaseViewControl`)**: Single-clicking a database or category node body immediately toggles its expansion state (`node.IsExpanded = !node.IsExpanded`), rather than reserving expansion for the chevron chevron arrow or double-click.

### User Uploaded Evidence

- **Figure 1 (Connections Tab)**:
  ![User Upload 1](file:///d:/DEV/C%23DOTNET/DataSphere/.specify/bugs/treeview-single-click-auto-invoke/user_image1_connections.png)

- **Figure 2 (Database Workspace Tab)**:
  ![User Upload 2](file:///d:/DEV/C%23DOTNET/DataSphere/.specify/bugs/treeview-single-click-auto-invoke/user_image2_database.png)

## Symptom

- In [`ConnectViewControl`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml), left-clicking a [`ConnectionModel`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Models/ConnectionModel.cs) node in `ConnectionsTree` immediately executes [`OpenConnectionCommand`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/ViewModels/Pages/DatabaseGroup/ConnectControlViewModel.cs#L127-L136) and switches workspace context to a new database tab, when the user only intended to select the item or prepare for a right-click.
- In [`DatabaseViewControl`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml), left-clicking a `DatabaseInfo` or `TableCategoryContext` node in `SchemaTree` immediately inverts `node.IsExpanded`, prematurely expanding the sub-tree on a single click.

Expected behavior:
- Single left-click should only **select** the item.
- Opening a connection session should require **Double-Click** (`DoubleTapped`), pressing Enter, or selecting "Mở kết nối" from the context menu.
- Expanding/collapsing a schema tree node should only occur when clicking the chevron expander arrow (`>`), or on **Double-Click** (`DoubleTapped`).

## Reproduction

1. Launch DataSphere.
2. Navigate to the Database Page (Connections Explorer tab).
3. Perform a single left-click on the `localhost` connection node.
   - **Observed**: A new database session tab for `localhost` opens immediately.
   - **Expected**: `localhost` is highlighted/selected; no tab opens unless double-clicked.
4. On the newly opened `localhost` database tab, locate the left schema explorer tree.
5. Perform a single left-click on any database item body (e.g., `chat`).
   - **Observed**: The database node immediately expands and fetches child categories.
   - **Expected**: The item is selected; expansion only toggles when clicking the chevron arrow or double-clicking.

### Diagnostic Evidence

- **Automated Live Reproduction Screenshot 1 — Single-Click Opened Connection Tab** (`WinSta0\default`):
  ![Single-Click Auto-Opened Tab](file:///d:/DEV/C%23DOTNET/DataSphere/.specify/bugs/treeview-single-click-auto-invoke/01_diagnostic_single_click_opened_tab.png)

- **Automated Live Reproduction Screenshot 2 — Single-Click Auto-Expanded Tree Node** (`WinSta0\default`):
  ![Single-Click Auto-Expanded Node](file:///d:/DEV/C%23DOTNET/DataSphere/.specify/bugs/treeview-single-click-auto-invoke/02_diagnostic_single_click_expanded_tree.png)

## Suspected Code Paths

- [`DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml:93`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml#L93) — `ItemInvoked="ConnectionsTree_ItemInvoked"` on `ConnectionsTree`.
- [`DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs:34-40`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs#L34-L40) — `ConnectionsTree_ItemInvoked`: Delegates `args.InvokedItem` directly to `ViewModel.OpenConnectionCommand.Execute(conn)` on single click.
- [`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml:64`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml#L64) — `ItemInvoked="SchemaTree_ItemInvoked"` on `SchemaTree`.
- [`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs:353-359`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs#L353-L359) — `SchemaTree_ItemInvoked`: Explicitly flips `node.IsExpanded = !node.IsExpanded` on single click for `DatabaseInfo` and `TableCategoryContext`.

## Root Cause Hypothesis

**Confidence: High (Confirmed by source code inspection and automated live reproduction)**

In WinUI 3, `TreeView.ItemInvoked` fires upon a **single click or tap** on any item in the tree.
1. In [`ConnectViewControl`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs), `ConnectionsTree_ItemInvoked` was wired to execute `OpenConnectionCommand`, causing single clicks to prematurely launch connection sessions instead of relying on `TreeViewItem_DoubleTapped` (which was already implemented).
2. In [`DatabaseViewControl`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs), `SchemaTree_ItemInvoked` explicitly contains procedural logic `node.IsExpanded = !node.IsExpanded`, which overrides the standard Windows tree UX by expanding/collapsing nodes upon single click instead of delegating expansion exclusively to the chevron arrow or double-click.

## Proposed Remediation

### Preferred: Standard Windows Double-Click / Chevron Expansion Model

1. **In [`ConnectViewControl.xaml`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml) & [`ConnectViewControl.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs)**:
   - Remove `ItemInvoked="ConnectionsTree_ItemInvoked"` from `ConnectionsTree` in XAML.
   - Remove `ConnectionsTree_ItemInvoked` from code-behind.
   - Rely exclusively on `DoubleTapped="TreeViewItem_DoubleTapped"` and Context Menu commands to establish connection sessions.
   - Single-clicking will now purely highlight/select the connection item without opening a tab.

2. **In [`DatabaseViewControl.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs)**:
   - In `SchemaTree_ItemInvoked`, remove the `node.IsExpanded = !node.IsExpanded` block for `DatabaseInfo` and `TableCategoryContext`.
   - Keep `ViewModel.SelectTable(tnc.Database, tnc.Table)` for `TableNodeContext` if table selection is desired, or optionally route table opening to double-click if preferred.
   - Add a `DoubleTapped` handler on the tree items in `DatabaseViewControl` so that double-clicking a database or category node toggles expansion (`node.IsExpanded = !node.IsExpanded`), while single-clicking leaves expansion solely to the native chevron toggle button.

## Files Likely to Change

- [`DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml) — Remove `ItemInvoked` attribute from `ConnectionsTree`.
- [`DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs) — Remove `ConnectionsTree_ItemInvoked` handler.
- [`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs) — Remove auto-expansion from `SchemaTree_ItemInvoked` and migrate expansion toggling to `DoubleTapped`.
- [`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml) — Hook `DoubleTapped` on tree items if needed.

## Tests to Add or Update

- UI Automation test on `WinSta0\default`:
  - Perform single click on `localhost` in `ConnectViewControl`: verify selected item is `localhost`, but NO new tab is opened (`InnerTabs.Count` remains 0).
  - Perform double click on `localhost`: verify new tab is opened (`InnerTabs.Count == 1`).
  - Perform single click on database node in `DatabaseViewControl`: verify node is selected, but `node.IsExpanded` remains false.
  - Perform double click on database node: verify node toggles `node.IsExpanded == true`.

## Risks & Considerations

- Keyboard Accessibility: Ensure pressing Enter on `ConnectionsTree` still opens the connection for accessibility users (can be handled in `KeyDown` event for `VirtualKey.Enter`).

## Open Questions

- None. The UX problem and exact resolution paths are clear and well-aligned with standard desktop UX conventions.
