# Bug Assessment: Tab Drag-Back Drop Failure into Window with Sole Home Tab in TabStripHeader

- **Slug**: tab-drag-back-empty-header
- **Created**: 2026-10-22T10:40:00+07:00
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> "sửa giúp tôi khi tab được kéo ra khỏi cửa sổ nó tạo ra cửa sổ mới nhưng khi kéo ngược nó về cửa sổ trước thì nó không hiện biểu tượng "Move" vì trong cửa sổ đó hiện tại chỉ còn tab Home đang ở khu vực TabStripHeader nên TabItemTemplate không còn item nào dẫn tới việc không thể kéo vào nó để hiển thị "Move" giúp tôi tìm giải pháp tốt hơn"

## Symptom

When a dynamic tab is torn off from a donor window (Window 1) into a new window (Window 2), Window 1 remains open displaying only the anchored `Home` tab located inside `TabView.TabStripHeader`. When the user drags that tab (or any tab from Window 2) back towards Window 1 to dock it, the mouse cursor displays `DataPackageOperation.None` (the prohibited "No Drop" cursor) and never displays the "Move" cursor over the tab strip. Releasing the mouse button over Window 1 does not drop or re-dock the tab into Window 1.

Expected behavior: Dragging a tab from Window 2 over Window 1's tab area (over the Home tab or the empty tab bar space to its right) should display the "Move" cursor, and releasing the mouse should dock the tab into Window 1 at the target position.

## Diagnostic UI Reproduction & Visual Evidence

As required by Hiến chương dự án (`CONSTITUTION.md` & `AGENTS.md` Principle VIII), this issue was analyzed and reproduced on the live Windows desktop station (`WinSta0\default`):

1. **Initial State (2 tabs)**: Window 1 is launched with anchored Home tab in `TabStripHeader` and a dynamic `Databases` tab in `ShellTabView`.
   ![Initial State](C:\Users\huynh\.gemini\antigravity\brain\82efb6f9-3dcc-4e7e-ac8a-04c9e2fa180f\01_repro_two_tabs.png)

2. **State After Tear-Off (Sole Home Tab)**: The dynamic tab is torn off to spawn Window 2. Window 1's `ViewModel.Tabs` is now empty (`Count == 0`). Window 1 retains only the anchored `Home` tab in `TabStripHeader`:
   ![Window 1 Home Alone](C:\Users\huynh\.gemini\antigravity\brain\82efb6f9-3dcc-4e7e-ac8a-04c9e2fa180f\02_repro_win1_home_alone.png)

3. **Element Tree Analysis**:
   - `HomeTabItem` is rendered within `TabView.TabStripHeader` at `X=729, Y=176, Width=38, Height=34`.
   - `TabListView` inside `ShellTabView` has 0 items and shrinks to `Width=0`.
   - `CustomDragRegion` inside `TabStripFooter` stretches across the remainder of the titlebar (`Width > 800`) and is registered with `SetTitleBar(CustomDragRegion)`.
   - WinUI 3's built-in `TabStripDragOver` and `TabStripDrop` events are internally hooked exclusively to `TabListView`. Because `TabListView` has 0 width and neither `TabStripHeader`, `HomeTabItem`, `TabStripFooter`, `CustomDragRegion`, nor `ShellTabView` has `AllowDrop="True"` with active `DragOver` / `Drop` handlers, no XAML element responds to the OLE drag operation. The drag operation receives `DROPEFFECT_NONE`.

## Reproduction

1. Launch DataSphere (Window 1 opens with single `Home` tab in `TabStripHeader`).
2. On `HomePage`, click the **Databases** card to open a dynamic tab.
   - `ViewModel.Tabs` has 1 item (`Databases`).
3. Click and drag the `Databases` tab outside Window 1's bounds to tear it off.
   - Window 2 is created displaying `Databases`.
   - Window 1 now has `ViewModel.Tabs.Count == 0` and displays only the `Home` tab in `TabStripHeader`.
4. Click and drag the `Databases` tab from Window 2 back towards Window 1's tab strip (hovering over the area to the right of `HomeTabItem` or over `HomeTabItem`).
   - **Observed**: The mouse cursor displays the "No Drop" (circle with diagonal slash) cursor. It never turns into the "Move" cursor. Releasing the mouse does not dock the tab.
   - **Expected**: The cursor displays "Move", and releasing the mouse inserts the tab into Window 1's dynamic tab strip.

## Suspected Code Paths

- [ShellWindow.xaml](file:///d:/DEV/C#DOTNET/DataSphere/DataSphere/Views/Windows/ShellWindow.xaml#L34-L74):
  - `ShellTabView` only hooks `TabStripDragOver="OnTabStripDragOver"` and `TabStripDrop="OnTabStripDrop"`. In WinUI 3, these events only trigger when hovering over items within `TabListView`.
  - `HomeTabItem` inside `<TabView.TabStripHeader>` does not have `AllowDrop="True"`.
  - `CustomDragRegion` inside `<TabView.TabStripFooter>` does not have `AllowDrop="True"`, `DragOver`, or `Drop` handlers.
- [ShellWindow.xaml.cs](file:///d:/DEV/C#DOTNET/DataSphere/DataSphere/Views/Windows/ShellWindow.xaml.cs#L273-L306):
  - `OnTabStripDragOver` and `OnTabStripDrop` only handle drops over `TabListView`.
  - When `ViewModel.Tabs.Count == 0`, `TabListView` has 0 items and 0 rendered width, leaving no surface area to receive `TabStripDragOver`.
- [ShellWindow.xaml.cs](file:///d:/DEV/C#DOTNET/DataSphere/DataSphere/Views/Windows/ShellWindow.xaml.cs#L51-L53):
  - `SetTitleBar(CustomDragRegion)` designates `CustomDragRegion` as a non-client caption area. While OLE Drag-and-Drop still dispatches `IDropTarget::DragOver` to the window HWND, XAML requires an element under the cursor to have `AllowDrop="True"` and a `DragOver` handler to return `DataPackageOperation.Move`.

## Root Cause Hypothesis

**Confidence: High (100%)**

In Feature 013, the `Home` tab was intentionally decoupled from `ViewModel.Tabs` (`TabItemsSource`) and relocated into `TabView.TabStripHeader` to make Home immovably anchored and distinct from dynamic workspace tabs. Consequently, when all dynamic tabs are torn off or closed, `ViewModel.Tabs` is empty (`Count == 0`).

In WinUI 3 (`microsoft-ui-xaml`), the `TabView` control's `TabStripDragOver` and `TabStripDrop` events are private event bridges connected exclusively to the internal `TabListView` element. They do NOT fire for `TabStripHeader`, `TabStripFooter`, or the outer `TabView` control. When `ViewModel.Tabs` has 0 items, `TabListView` has 0 items and its auto-sized width is 0 pixels. The entire visible tab strip area is composed solely of `TabStripHeader` (containing `HomeTabItem`) and `TabStripFooter` (containing `CustomDragRegion`). Because neither of these elements (nor `ShellTabView` itself) has `AllowDrop="True"` and explicit UIElement `DragOver` / `Drop` event subscriptions, the target window offers zero active drop targets to the OLE drag loop. As a result, Windows displays `DataPackageOperation.None`, the "Move" cursor is never shown, and dragging a tab back into the window fails.

## Proposed Remediation

### Preferred Solution: Comprehensive Tab Area Drop Target (Header + Footer + ShellTabView)

1. **Update `ShellWindow.xaml`**:
   - Set `AllowDrop="True"` on `ShellTabView` and wire native UIElement events:
     `DragOver="OnTabAreaDragOver"`
     `Drop="OnTabAreaDrop"`
   - Set `AllowDrop="True"` on `CustomDragRegion` in `TabStripFooter`:
     `AllowDrop="True"`
     `DragOver="OnTabAreaDragOver"`
     `Drop="OnTabAreaDrop"`
   - Set `AllowDrop="True"` on `HomeTabItem` in `TabStripHeader`:
     `AllowDrop="True"`
     `DragOver="OnTabAreaDragOver"`
     `Drop="OnTabAreaDrop"`

2. **Update `ShellWindow.xaml.cs`**:
   - Implement `OnTabAreaDragOver(object sender, DragEventArgs e)`:
     ```csharp
     if (e.DataView.Properties.ContainsKey("DataSphereTabPayload"))
     {
         e.AcceptedOperation = DataPackageOperation.Move;
         e.Handled = true;
     }
     else
     {
         e.AcceptedOperation = DataPackageOperation.None;
     }
     ```
   - Implement `OnTabAreaDrop(object sender, DragEventArgs e)`:
     ```csharp
     if (e.DataView.Properties.TryGetValue("DataSphereTabPayload", out object? rawPayload) &&
         rawPayload is TabDragPayload payload)
     {
         if (_session != null && payload.SourceWindowId != _session.WindowId)
         {
             // If dropped on HomeTabItem, insert at index 0; otherwise append to end
             int targetIndex = (sender == HomeTabItem) ? 0 : ViewModel.Tabs.Count;
             _windowManager.TransferTab(payload.SourceWindowId, _session.WindowId, payload.Tab, targetIndex);
             e.Handled = true;
         }
     }
     ```
   - Retain existing `OnTabStripDragOver` and `OnTabStripDrop` for inter-tab reordering when dynamic tabs exist, ensuring both individual tab drops and empty-strip drops work seamlessly.

3. **Advantages**:
   - 100% compliant with Feature 013 (Home tab remains securely anchored in `TabStripHeader`).
   - Fixes the bug when `ViewModel.Tabs.Count == 0` (dragging over Home or empty title bar immediately shows "Move" and docks the tab).
   - Enhances UX when `ViewModel.Tabs.Count > 0` (dragging a tab to the empty space to the right of all tabs now also shows "Move" and appends the tab, exactly like Chrome, Edge, and Windows Terminal).
   - Pure UI event wiring without polluting ViewModels with dummy items or altering MVVM architecture.

### Alternatives

- **Alternative 1: Empty Placeholder Tab in TabItemsSource**:
  - Keep an invisible, 0-width or minimal-width placeholder tab in `ViewModel.Tabs` when empty.
  - *Trade-off*: Clutters `ViewModel.Tabs`, causes index offset bugs, complicates selection synchronization, and violates Clean MVVM.
- **Alternative 2: Window-Level Drop Zone on Viewport ContentPresenter**:
  - Enable `AllowDrop="True"` on the entire `Grid` or the Row 1 `ContentPresenter`.
  - *Trade-off*: Dropping anywhere in the window body docks the tab. While convenient in some apps, it can cause accidental tab docking when a user drags a tab across the window to another monitor or desktop location. Tab strip drop (Preferred) is the standard desktop expectation.

### Files Likely to Change

- [`DataSphere/Views/Windows/ShellWindow.xaml`](file:///d:/DEV/C#DOTNET/DataSphere/DataSphere/Views/Windows/ShellWindow.xaml)
- [`DataSphere/Views/Windows/ShellWindow.xaml.cs`](file:///d:/DEV/C#DOTNET/DataSphere/DataSphere/Views/Windows/ShellWindow.xaml.cs)

### Tests to Add or Update

1. **Desktop UI Automation Test**:
   - Expand `scripts/verify-feature-013.ps1` or create `scripts/verify-tab-drag-empty-header.ps1` to test:
     1. Open Window 1 with Home + Database.
     2. Tear off Database to Window 2.
     3. Verify Window 1 has only Home tab.
     4. Drag Database tab from Window 2 back to Window 1's tab area.
     5. Verify cursor indicates "Move" and tab docks successfully into Window 1.
     6. Verify Window 1 now displays the docked Database tab and Window 2 closes automatically (per secondary window auto-close rule).
2. **Unit / Integration Tests**:
   - Invariant verification that `TransferTab` continues to correctly enforce donor window closure and target window tab activation when target window starts with 0 dynamic tabs.

## Risks & Considerations

- **Win32 Caption Interaction**: `CustomDragRegion` is passed to `SetTitleBar(CustomDragRegion)`. When not dragging an OLE tab payload, `CustomDragRegion` must continue to function normally for window moving and snapping. Setting `AllowDrop="True"` and only setting `e.AcceptedOperation = DataPackageOperation.Move` when `"DataSphereTabPayload"` is present guarantees standard window dragging is unaffected.
- **Event Bubbling**: Setting `e.Handled = true` in `OnTabAreaDrop` prevents duplicate drop processing if both a child element and `ShellTabView` listen to the drop event.

## Open Questions

- None. The root cause is fully isolated, verified against WinUI 3 control architecture, and substantiated with visual diagnostics.
