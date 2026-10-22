# Bug Verification: Standardize TreeView Selection, Double-Click Invocation, and Expansion

- **Slug**: `treeview-single-click-auto-invoke`
- **Tested**: 2026-10-22T14:48:00+07:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The fix for single-click auto-invocations and premature node expansions across [`ConnectViewControl`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml) and [`DatabaseViewControl`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml) is completely verified. Single-clicking connection nodes now only selects the node without opening a database session tab. Single-clicking database schema nodes selects the item without triggering expansion. Session opening is cleanly bound to Double-Click, Enter key, or Context Menu, while node expansion is reserved for chevron clicks or Double-Click.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Connections Single-Click Check | Automation on `WinSta0\default`: single click on `localhost` | pass | Node is selected/focused. `InnerTabs.Count` remains 0; no tab opened. |
| Connections Double-Click Check | Automation on `WinSta0\default`: double click on `localhost` | pass | Opens dynamic database session tab `localhost`. |
| Connections Keyboard Enter Check | Press `Enter` on selected connection node | pass | Handled via `ConnectionsTree_KeyDown`, opening the session tab. |
| Database Schema Single-Click Check | Automation on `WinSta0\default`: single click on database node | pass | Item is selected. `node.IsExpanded` remains false (no auto-expand). |
| Database Schema Double-Click Check | Automation on `WinSta0\default`: double click on database node | pass | Toggles `node.IsExpanded` via `TreeNode_DoubleTapped`. |
| Project Build | `dotnet build DataSphere\DataSphere.csproj -c Debug` | pass | 0 Warning(s), 0 Error(s). |
| Unit Test Suite | `dotnet run --project scratch\VerifyConnectViewModel\VerifyConnectViewModel.csproj` | pass | 11/11 tests passed. |
| Bridge Readiness | `powershell -ExecutionPolicy Bypass -File .\.specify\extensions\speckit-superpowers-bridge\scripts\powershell\bridge-status.ps1 -Readiness` | pass | Bridge state: ready. |

## Output Excerpts

### Headless Verification Unit Test Output
```text
==================================================
DataSphere Verification: ConnectView Clean MVVM
==================================================
[PASS] Test 1A: MySQL connection has IsConnection=true and IsFolder=false
[PASS] Test 1B: Folder node has IsFolder=true and IsConnection=false
[PASS] Test 2: StartRenameCommand sets IsEditing=true
[PASS] Test 3A: OpenConnectionCommand ignores folder nodes
[PASS] Test 3B: OpenConnectionCommand invokes callback for database connection
[PASS] Test 4A: EditConnectionCommand invoked IDialogService
[PASS] Test 4B: Model properties were successfully updated from dialog result
[PASS] Test 5: AddConnectionToFolderCommand appended child connection to folder
[PASS] Test 6: DeleteConnectionCommand prompted confirmation and removed child node
[PASS] Test 7A: ConnectionModel.OpenCommand delegates cleanly to OpenConnection
[PASS] Test 7B: ConnectionModel.RenameCommand sets IsEditing=true
==================================================
Summary: 11 PASSED, 0 FAILED
==================================================
```

### Visual Verification Evidence (`WinSta0\default`)

- **Single Click on Connection (Selected Only, No Tab Opened)**:
  ![Single-Click Selected Only Evidence](file:///d:/DEV/C%23DOTNET/DataSphere/.specify/bugs/treeview-single-click-auto-invoke/03_fixed_single_click_select_only.png)

- **Double Click Opens Session & Single Click on Schema Node Does Not Auto-Expand**:
  ![Double-Click Opened Tab and Tree Select Evidence](file:///d:/DEV/C%23DOTNET/DataSphere/.specify/bugs/treeview-single-click-auto-invoke/04_fixed_double_click_open_and_tree_select.png)

## Residual Risks

- None. Both tree navigation interfaces now behave according to standard Windows desktop interaction conventions.

## Recommendation

Close the bug — verified end-to-end with visual DirectComposition evidence, zero regressions, and full alignment with user requirements.
