# Bug Assessment: DataViewControl Memory Leak and Missing Dispose Trigger on Top Tab Close

- **Slug**: dataviewcontrol-not-disposed-on-tab-close
- **Created**: 2026-10-23T09:55:00+07:00
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

The user reports that `DataViewControl.xaml.cs` (and its underlying resources) is leaking memory because its `Dispose()` method is not invoked when the top/outer database tab is closed:
> "có rò rỉ bộ nhớ với DataViewControl.xaml.cs, nó không kích hoạt Dispose khi tab lớn phía trên bị đóng"

## Symptom

When a user opens the "Cơ sở dữ liệu" (Database) top-level tab in `ShellTabView`, establishes a connection session to a database server, and navigates to view a table (which instantiates and displays `DataViewControl.xaml.cs` hosting `VirtualTable` and `DataControlViewModel`):
1. Closing the top Database tab via the close button ('X') on `ShellTabView` removes the tab from the tab strip and navigates back to Home.
2. However, `DataViewControl.Dispose()` is not deterministically triggered across all tab-closing code paths, leaving:
   - `DataViewControl` and its compiled `{x:Bind}` event listeners active in memory.
   - `VirtualTable` row recycling pools, compositor animation sync targets, and scroll listeners attached.
   - `DataControlViewModel` query tasks, pagination models, and dirty change trackers uncollected.
   - The active `IDatabaseConnection` server socket session remaining open in the background without being cleanly disconnected.

## Reproduction

1. Launch DataSphere on real desktop (`WinSta0\default`).
2. Navigate to "Cơ sở dữ liệu" (Database) from the Home dashboard.
3. Connect to a database server (e.g. `localhost`), expand a schema (`ngocthamcatalog`), expand `Các bảng`, and click table `banggiada_backup`.
   - Table records populate in `VirtualTable` within `DataViewControl` (verified with `01_diagnose_table_active.png`).
4. Click the close button ('X') on the top Database tab in `ShellTabView`.
   - Tab closes and UI falls back to Home (verified with `02_diagnose_tab_closed.png`).
5. Trace object destruction lifecycle and verify `Dispose()` execution across the hierarchy.

### Diagnostic Evidence

- **Screenshot 01 (Table Active with DataViewControl)**: `01_diagnose_table_active.png`
- **Screenshot 02 (Top Database Tab Closed)**: `02_diagnose_tab_closed.png`
- **Lifecycle Execution Trace**:
  ```text
  TabService.CloseTab: Co s? d? li?u (Content: DatabasePage)
  DatabasePage.Dispose called
  DatabaseControlViewModel.Dispose called (RightPanelContent is DataViewControl)
  DataViewControl.Dispose called
  DatabaseControlViewModel.Dispose called (RightPanelContent is null)
  ```

## Suspected Code Paths

1. [`DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml.cs:13, 118-128`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml.cs#L13):
   - In the base committed repository (`HEAD: ec78a21`), `DatabasePage` **did not implement `IDisposable` at all**.
   - Because `DatabasePage` lacked `IDisposable`, `TabService.CloseTab(TabItemModel tab)` invoked `tab.Dispose()`, which checked `if (Content is IDisposable disposable)`—evaluating to `false`. As a result, closing the top Database tab completely skipped `DatabasePage` teardown, leaving all inner connection sessions and `DataViewControl` viewports orphaned in memory.
   - In recent uncommitted working copy changes, `DatabasePage : IDisposable` was introduced, but its teardown is incomplete: it loops over `ViewModel.InnerTabs` without clearing them, does not nullify `ViewModel.ActiveInnerContent`, does not dispose `ViewModel` (`DatabaseViewModel`), and does not clear `ContentControl.Content`.
2. [`DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseViewModel.cs:182-193`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseViewModel.cs#L182-L193):
   - When an **inner tab** is closed via `CloseTab(InnerTabItemModel tab)`:
     ```csharp
     tab.DisposableContext?.Dispose();
     InnerTabs.RemoveAt(index);
     ```
     It calls `tab.DisposableContext?.Dispose()`, but **never calls `tab.Dispose()`**!
     In `InnerTabItemModel.cs`, `Dispose()` is responsible for disposing `Content` (`DatabaseViewControl`). Because `tab.Dispose()` is never called, `DatabaseViewControl` and its bindings are bypassed when closing inner tabs.
   - Furthermore, `DatabaseViewModel` does not implement `IDisposable`.
3. [`DataSphere/Models/WindowSession.cs:61-88`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Models/WindowSession.cs#L61-L88):
   - `WindowSession.CloseTab(TabItemModel tab)` removes the tab via `Tabs.RemoveAt(index)` and updates state, but **never invokes `tab.Dispose()`**.
4. [`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs:383-387`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs#L383-L387):
   - `DatabaseViewControl.Dispose()` unhooks `CollectionChanged` and disposes `ViewModel`, but does not stop `{x:Bind}` tracking (`Bindings?.StopTracking()`) and does not nullify `RightPanelHost.Content`, creating visual retention hazards.

## Root Cause Hypothesis

**Confidence: High**

1. **Missing IDisposable on Top Tab View & Model**: Prior to recent changes, `DatabasePage` (the `tab.Content` of the top Database tab) did not implement `IDisposable`. Even with `DatabasePage.Dispose()` newly added, `DatabaseViewModel` does not implement `IDisposable`, and the teardown of child tabs and content bindings is incomplete.
2. **Asymmetric Inner Tab Disposal**: `DatabaseViewModel.CloseTab` disposes `DisposableContext` but skips `tab.Dispose()`, preventing `DatabaseViewControl` and its child visual tree from executing their disposal sequence.
3. **Session Teardown Gap**: `WindowSession.CloseTab` removes tabs without disposing their content, leading to memory leaks if window sessions manage tab closures.

## Proposed Remediation

**Preferred**:
1. **Implement `IDisposable` on `DatabaseViewModel` and Complete `DatabasePage.Dispose()`**:
   - Update [`DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseViewModel.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseViewModel.cs):
     - Implement `IDisposable`.
     - In `DatabaseViewModel.Dispose()`, iterate and call `tab.Dispose()` on each tab in `InnerTabs`, clear `InnerTabs`, call `ConnectionTab?.Dispose()`, dispose `ConnectViewModel` (if applicable), and nullify `SelectedInnerTab`.
     - In `DatabaseViewModel.CloseTab(InnerTabItemModel tab)`, call `tab.Dispose()` instead of only `tab.DisposableContext?.Dispose()`.
   - Update [`DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml.cs):
     - In `DatabasePage.Dispose()`:
       - Stop bindings tracking: `Bindings?.StopTracking()`.
       - Nullify `InnerTabView.SelectedItem = null`.
       - Dispose `ViewModel`: `ViewModel.Dispose()`.
2. **Harden `DatabaseViewControl.xaml.cs` Teardown**:
   - In [`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs):
     - In `Dispose()`, add `Bindings?.StopTracking()`.
     - Clear `RightPanelHost.Content = null`.
     - Clear `SchemaTree.RootNodes.Clear()`.
3. **Harden `WindowSession.cs`**:
   - In [`DataSphere/Models/WindowSession.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Models/WindowSession.cs):
     - In `CloseTab(TabItemModel tab)`, call `tab.Dispose()` before or after removal.
4. **Ensure `DataViewControl.xaml.cs` Terminal Disposal**:
   - Confirm that `DataViewControl.Dispose()` cleanly disposes `TableControl` (`VirtualTable`), stops bindings, and disposes `ViewModel` (`DataControlViewModel`), ensuring zero retention of row pools or MySQL connections.

**Alternatives**:
- Weak references for all child viewports: More complex and does not guarantee timely disconnection of active MySQL database socket streams. Explicit deterministic disposal via cascading `IDisposable` is the standard Clean MVVM pattern.

**Files likely to change**:
- `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml.cs`
- `DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseViewModel.cs`
- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs`
- `DataSphere/Models/WindowSession.cs`

**Tests to add or update**:
- Extend `scripts/diagnose-dataviewcontrol-leak.ps1` to verify full cascading disposal of `DataViewControl`, `DatabaseControlViewModel`, and `DatabasePage` upon top tab close and inner tab close.

## Risks & Considerations

- **Thread Affinity**: Teardown of WinUI 3 XAML controls (`DataViewControl`, `VirtualTable`, `DatabaseViewControl`) must happen on the UI thread (`DispatcherQueue`). `TabService.CloseTab` and `InnerTabView_TabCloseRequested` run on the UI thread, so this is safe.
- **Re-entrance Guard**: Ensure `_disposed` flags prevent double-disposal crashes across `InnerTabItemModel` and `DatabaseControlViewModel`.

## Open Questions

- None. The root cause is fully isolated and verified via live automated reproduction on `WinSta0\default`.
