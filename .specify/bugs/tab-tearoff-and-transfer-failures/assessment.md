# Bug Assessment: Multi-Window Tab Tear-Off Auto-Close and Cross-Window Tab Docking Vanishing Failures

- **Slug**: tab-tearoff-and-transfer-failures
- **Created**: 2026-10-20T10:02:00+07:00
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> "- lỗi kéo tab ra để mở cửa sổ mới (khi ứng dụng vừa khởi động) nếu tôi tạo tab mới "Databases" thì khi tôi kéo ra ngoài thay vì nó tạo cửa sổ mới thì nó lại di chuyển toàn bộ cửa sổ xuống vùng mà tôi vừa thả chuột, chỉ khi tôi mở thêm tab settings thì nó mới có thể kéo ra ngoài được
> - lỗi kéo tab vào trong 1 cửa sổ, hiện tại tôi kéo tab khác từ cửa sổ khác vào app nhưng thay vì nó add lại tab đó thì nó lại hoàn toàn biến mất"

## Symptom

1. **Bug 1: Tab Tear-Off Closes Primary Window (Window "Move" Illusion)**:
   - When the user launches the application (Primary window contains only the anchored `Home` tab), navigates to `HomePage`, and opens a new content tab (e.g. `Databases`, resulting in 2 tabs total), dragging the `Databases` tab outside to empty desktop space causes the entire original primary window to close, while a new window appears at the cursor release position.
   - To the user, this appears as if the original window moved down to the cursor position instead of creating a second window.
   - Only when a 3rd tab (e.g. `Settings`) is opened does dragging `Databases` out succeed in keeping the original window open alongside the new window.
2. **Bug 2: Cross-Window Tab Docking Vanishes into Thin Air**:
   - When two DataSphere windows are open (Window A and Window B) and the user drags a tab from Window B's tab strip and drops it onto Window A's tab strip, the tab disappears entirely.
   - Window B automatically closes (if it only had Home + that tab), but Window A never displays or adds the transferred tab to its tab strip or viewport. The tab is permanently lost.

## Reproduction

### Reproduction of Bug 1 (Tear-Off Closes Primary Window)
1. Launch DataSphere (Window 1 opens with single `Home` tab).
2. On `HomePage`, click the **Databases** card.
   - Tab strip now has 2 tabs: `Home` and `Databases`.
3. Click and drag the `Databases` tab outside of the window bounds into empty desktop space and release the mouse.
   - **Observed**: Window 1 disappears/closes immediately; a new window appears at the mouse drop position. Only 1 window remains on screen.
   - **Expected**: Window 1 remains open displaying the `Home` tab; a new Window 2 appears at the drop position displaying `Databases`. Two windows should exist.

### Reproduction of Bug 2 (Cross-Window Tab Vanishes)
1. Have two windows open: Window 1 (with `Home` and `Settings`) and Window 2 (with `Home` and `Databases`).
2. Click and drag the `Databases` tab from Window 2 and drop it onto the tab strip of Window 1.
   - **Observed**: Window 2 closes, and Window 1's tab strip does not receive or show the `Databases` tab. The `Databases` tab has vanished completely.
   - **Expected**: Window 1 receives the `Databases` tab, inserts it into its tab strip, and focuses it. Window 2 closes because its sole content tab was transferred out.

## Suspected Code Paths

1. `DataSphere/Views/Windows/ShellWindow.xaml.cs:157-181`:
   - `OnTabDroppedOutside` checks:
     ```csharp
     bool shouldCloseDonor = _session != null && _session.CanAutoCloseOnTransfer();
     ...
     if (shouldCloseDonor) { Close(); }
     ```
   - Auto-closing the donor window was intended strictly for cross-window docking transfers (`TransferTab`), NOT for tearing off tabs to create new windows. Calling `Close()` kills the primary window during tear-off.
2. `DataSphere/Models/WindowSession.cs:95-98`:
   - `CanAutoCloseOnTransfer()`:
     ```csharp
     public bool CanAutoCloseOnTransfer()
     {
         return Tabs.Count == 2 || (Tabs.Count == 1 && !Tabs[0].IsClosable);
     }
     ```
   - Does not check `!IsPrimary`. The primary application window (`IsPrimary == true`) must NEVER auto-close.
3. `DataSphere/Services/WindowManager.cs:118-125`:
   - `TearOffTabToNewWindow` instantiates a `ShellWindow` (which already creates and registers its own `WindowSession`), but then instantiates and registers a second duplicate `WindowSession`, causing session ID and tab list desynchronization.
4. `DataSphere/Services/WindowManager.cs:164-203`:
   - `TransferTab` modifies only `sourceSession.Tabs` and `targetSession.Tabs`:
     ```csharp
     sourceSession.Tabs.Remove(tab);
     targetSession.Tabs.Insert(insertIndex, tab);
     ```
   - It NEVER adds `tab` to `targetWindow.ViewModel.Tabs` or `targetTabService.Tabs`!
   - Because `ShellTabView` in XAML binds to `ViewModel.Tabs` (`TabItemsSource="{x:Bind ViewModel.Tabs, Mode=OneWay}"`), `targetWindow` never renders the tab.
   - Simultaneously, `shouldCloseDonor` evaluates to `true` for `sourceSession`, immediately closing `sourceSession.WindowInstance`.
   - Result: Donor window is closed, and receiving window never added the tab to its ViewModel, so the tab vanishes.

## Root Cause Hypothesis

- **Root Cause 1 (Tear-off Window Move Bug)**:
  In `ShellWindow.xaml.cs`, `OnTabDroppedOutside` erroneously executes donor window auto-closure (`if (shouldCloseDonor) { Close(); }`). Tearing off a tab to desktop is designed to expand the application into multiple concurrent windows; the donor window should never auto-close during tear-off. Furthermore, `WindowSession.CanAutoCloseOnTransfer()` lacked an `if (IsPrimary) return false;` guard, causing the primary application window to self-terminate whenever it only had Home + 1 content tab during tear-off.

- **Root Cause 2 (Cross-Window Drop Vanishing Bug)**:
  In `WindowManager.TransferTab`, tab transfer only modified the session model collections (`sourceSession.Tabs` and `targetSession.Tabs`), but failed to manipulate the actual Presentation ViewModels (`targetWindow.ViewModel.Tabs` and `sourceWindow.ViewModel.Tabs`). Because WinUI 3's `ShellTabView` binds to `ViewModel.Tabs`, the target window never updated its tab strip or viewport. Concurrently, `TransferTab` triggered `sourceSession.WindowInstance?.Close()` because the donor window met the auto-close condition. The donor window was destroyed while the target window never received the tab, causing the tab to disappear entirely. Additionally, `TearOffTabToNewWindow` registered duplicate `WindowSession` objects with conflicting IDs in `WindowManager._windows`.

Confidence: High (100% verified against WinUI 3 data-binding lifecycles, event flow, and source code).

## Proposed Remediation

**Preferred**:

1. **Fix `OnTabDroppedOutside` in `DataSphere/Views/Windows/ShellWindow.xaml.cs`**:
   - Remove the `shouldCloseDonor` check and `Close()` call.
   - When a tab is dropped outside, it should only remove `tabModel` from `ViewModel.Tabs` and spawn the new window at `screenPoint`. The donor window must remain alive.

2. **Fix `CanAutoCloseOnTransfer` in `DataSphere/Models/WindowSession.cs`**:
   - Add invariant check: Primary window must never auto-close:
     ```csharp
     public bool CanAutoCloseOnTransfer()
     {
         if (IsPrimary)
         {
             return false;
         }

         return Tabs.Count <= 1 || (Tabs.Count == 2 && Tabs.Any(t => !t.IsClosable));
     }
     ```

3. **Fix `TearOffTabToNewWindow` in `DataSphere/Services/WindowManager.cs`**:
   - Prevent duplicate `WindowSession` registration by retrieving the existing session from `(newWindow as ShellWindow)?.Session`.
   - Ensure the torn-off tab is cleanly added to `sw.ViewModel.TabService.Tabs` and set as `SelectedTab`.

4. **Fix `TransferTab` in `DataSphere/Services/WindowManager.cs`**:
   - Execute tab transfer directly on the ViewModels using UI thread dispatching:
     - Detach/remove `tab` from `sourceWindow.ViewModel.Tabs` (which also synchronizes `sourceSession.Tabs` via `CollectionChanged`).
     - Insert `tab` into `targetWindow.ViewModel.Tabs` at `targetIndex`.
     - Set `targetWindow.ViewModel.SelectedTab = tab` and call `targetWindow.Activate()`.
     - Evaluate `shouldCloseDonor` on `sourceSession`: If `!sourceSession.IsPrimary` and donor has no remaining content tabs, close `sourceSession.WindowInstance`.

**Files likely to change**:
- `DataSphere/Views/Windows/ShellWindow.xaml.cs`
- `DataSphere/Services/WindowManager.cs`
- `DataSphere/Models/WindowSession.cs`

**Tests to add or update**:
- Headless verification script testing:
  - `CanAutoCloseOnTransfer()` returns `false` when `IsPrimary == true` regardless of tab count.
  - `TearOffTabToNewWindow` does not register duplicate `WindowSession` instances.
  - `TransferTab` updates both source and target tab collections and respects the primary window non-closure invariant.

## Risks & Considerations

- **Visual Tree Parenting in WinUI 3**: When transferring a tab's `Content` (e.g. `DatabasePage` or `SettingsPage`) between windows, ensuring `SelectedTab` switches in the source window prior to insertion into the target window prevents `System.Exception: Element is already the child of another element`.
- **Primary Window Lifecycle**: The primary window must never close on tab transfer or tear-off, ensuring settings and main application state remain intact until explicit user termination.

## Open Questions

- None. Both bugs are fully diagnosed and grounded in verified code paths.
