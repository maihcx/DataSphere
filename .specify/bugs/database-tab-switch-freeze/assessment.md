# Bug Assessment: Database Tab Freeze and Unresponsive Table Viewport on Tab Switching

- **Slug**: database-tab-switch-freeze
- **Created**: 2026-10-23T08:28:00+07:00
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

The user reports that when viewing database table data, switching to the Settings page, and then returning to the Database tab, the table becomes completely frozen:
> "giúp tôi sửa lỗi không thể tương tác với database (khóa cứng) và khi cuộn lên thì không thể thấy content mới, click vô cell thì nó cũng không phản ứng gì khi tôi mở cơ sở dữ liệu rồi mở trang cài đặt sau đó quay lại trang cơ sở dữ liệu"

Attached user screenshots demonstrate:
1. Active table `banggiada_backup` populated with records (`id`, `cid`, `pid`, `code`, etc.).
2. After scrolling, an empty white area appears underneath row 23 with missing rows and complete lack of interactivity.

## Symptom

1. **Table Viewport Frozen on Tab Navigation**:
   - When a user views table records in the "Cơ sở dữ liệu" (Database) tab, switches away (e.g. to the "Trang chủ" or "Cài đặt" tab), and then switches back to the Database tab:
     - Clicking on table cells does not select cells, trigger cell editing, or produce any visual feedback.
     - Scrolling up or down via mouse wheel or scrollbar does not fetch, render, or recycle rows. The viewport content remains completely static or displays a blank canvas.
     - The table control behaves as if permanently locked or dead.

## Reproduction

1. Launch DataSphere on real desktop (`WinSta0\default`).
2. Navigate to "Cơ sở dữ liệu" (Database) tab from Home dashboard.
3. Connect to `localhost` and expand `ngocthamcatalog` -> `Các bảng`.
4. Click on table `banggiada_backup` (or `accessed`).
   - Table records populate in `VirtualTable` (verified with `01_table_active_before_switch.png`).
5. Click "Trang chủ" (Home) tab icon, then click "Cài đặt" (Settings) card.
   - Settings tab opens and becomes active viewport (verified with `02_settings_tab_opened.png`).
6. Click the "Cơ sở dữ liệu" (Database) tab in the top `ShellTabView` strip to return.
   - **Observed**: Table viewport is completely blank or stuck; no row elements respond (verified with `03_switched_back_frozen.png`).
7. Attempt physical click on table cells and scroll down using mouse wheel.
   - **Observed**: Clicks produce no reaction; scrolling produces zero visual change (`04_scrolled_blank_frozen.png` pixel hash is 100% identical to `03_switched_back_frozen.png`).

### Diagnostic Evidence

- **Screenshot 01 (Table Active)**: `01_table_active_before_switch.png`
- **Screenshot 02 (Settings Opened)**: `02_settings_tab_opened.png`
- **Screenshot 03 (Switched Back Frozen)**: `03_switched_back_frozen.png`
- **Screenshot 04 (Scrolled Frozen)**: `04_scrolled_blank_frozen.png`
- **UIA Element Delta**: 7,218 pixels out of 17,600 sampled in the table area altered, followed by 0-pixel delta upon mouse scroll, confirming total unresponsiveness.

## Suspected Code Paths

- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs:147, 353-356`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L147):
  ```csharp
  Unloaded += OnUnloaded;
  ...
  private void OnUnloaded(object sender, RoutedEventArgs e)
  {
      Dispose();
  }
  ```
  In WinUI 3, `Unloaded` is fired whenever a control is detached from the visual tree. During tab switching in `ShellWindow`, `ActiveViewportContent` changes from `DatabasePage` to `SettingsPage`. The entire `DatabasePage` visual subtree is detached, triggering `Unloaded` on `VirtualTable`.
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs:419-478`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L419-L478) (`Dispose`):
  `Dispose()` performs permanent control teardown:
  - Sets `_disposed = true`.
  - Detaches `Loaded -= OnLoaded` and `Unloaded -= OnUnloaded`.
  - Detaches `TableScrollViewer.ViewChanged -= OnScrollViewerViewChanged`.
  - Detaches `VirtualCanvas.PointerPressed`, `PointerMoved`, `PointerWheelChanged`, `PointerReleased`, `KeyDown`.
  - Clears `_rowPool.Clear(VirtualCanvas)`, `_headerBorders.Clear()`, `Columns.Clear()`.
  - Nulls `DataProvider = null`.
  Because `Loaded` was detached and `_disposed` set to `true`, when the user navigates back to the Database tab, the control cannot re-initialize or respond to events.
- [`DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs:48-56`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs#L48-L56):
  `DataViewControl.Dispose()` already properly delegates disposal to `TableControl?.Dispose()` when the view itself is explicitly disposed (e.g. when dropping a database or disposing `DatabaseControlViewModel`).

## Root Cause Hypothesis

**Confidence: High**

In commit `ec78a21eb827619416393b4b5cbe9a1fe95106bf`, `VirtualTable.OnUnloaded` was wired directly to `Dispose()` to address memory retention during table teardown.

However, in WinUI 3 XAML, the `Unloaded` event fires any time an element is temporarily detached from the Visual Tree—which occurs naturally whenever `ShellViewModel.ActiveViewportContent` switches between open tabs (`HomePage`, `DatabasePage`, `SettingsPage`).

When the user navigates to the Settings tab, `VirtualTable` prematurely disposes itself: it wipes out its row pool, removes all pointer/scroll event listeners, unhooks `Loaded`, and sets `_disposed = true`. When the user navigates back to the Database tab, `VirtualTable` is attached back to the Visual Tree as a completely gutted, non-interactive shell that can no longer recycle visual rows or receive mouse clicks.

## Proposed Remediation

**Preferred**:
1. In [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs):
   - Modify `OnUnloaded` to perform only transient suspension instead of full destruction:
     ```csharp
     private void OnUnloaded(object sender, RoutedEventArgs e)
     {
         CancelCellEdit();
         TeardownHeaderCompositorSync();
     }
     ```
     This safely halts DirectComposition animations and active cell editing while detached from the visual tree, without unhooking internal input handlers, destroying `_rowPool`, or setting `_disposed = true`.
   - On `OnLoaded`, ensure `SetupHeaderCompositorSync()` and `Recycle()` / `Refresh()` are executed to seamlessly resume rendering and animation upon returning to the tab.
   - Keep `Dispose()` for true terminal lifecycle disposal (invoked explicitly when `DataViewControl.Dispose()` or `DatabaseControlViewModel.Dispose()` is called upon tab close).
   - In `Dispose()`, safely detach `Loaded -= OnLoaded` and `Unloaded -= OnUnloaded`.

**Alternatives**:
- Cache separate view instances per tab or prevent `ContentPresenter` from removing inactive tab pages from the visual tree (e.g. using a multi-page visibility stack). However, this consumes significantly more GPU/visual memory across many open tabs. Fixing `VirtualTable`'s `Unloaded` handling maintains minimal memory footprint while ensuring flawless tab switching.

**Files likely to change**:
- `DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`

**Tests to add or update**:
- UI Automation regression test simulating:
  1. Open database table data.
  2. Switch to Settings tab.
  3. Switch back to Database tab.
  4. Perform mouse wheel scroll and click assertions, verifying that `TableScrollViewer.ViewChanged` triggers row recycling and the table remains interactive.

## Risks & Considerations

- **DirectComposition Animation Reconnection**: When switching back to the tab, `SetupHeaderCompositorSync()` must re-bind `ElementCompositionPreview.GetScrollViewerManipulationPropertySet` cleanly to guarantee 144Hz scroll sync without throwing COM exceptions.
- **Memory Retention Invariant**: Halting the animation in `OnUnloaded` without disposing the visual tree prevents memory leaks while preserving instant UI reactivation.

## Open Questions

- None. The root cause was definitively isolated through git history analysis and verified with real desktop UI automation reproduction.
