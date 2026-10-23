# Bug Fix: Restore VirtualTable Interaction and Row Recycling across Tab Navigation

- **Slug**: database-tab-switch-freeze
- **Fixed**: 2026-10-23T08:34:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Prevented premature permanent destruction of `VirtualTable` during tab navigation by transforming `OnUnloaded` into a transient suspension mechanism (cancelling cell edits and pausing DirectComposition expression animations) rather than invoking `Dispose()`. When switching back to the Database tab, `OnLoaded` synchronizes scroll offsets and seamlessly resumes GPU compositor sync and row recycling.

## Changes

| File | Change | Notes |
|------|--------|-------|
| [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs) | modified | Replaced `Dispose()` call in `OnUnloaded` with non-destructive `CancelCellEdit()` and `TeardownHeaderCompositorSync()`. In `OnLoaded`, restored scroll offsets, re-initialized compositor sync, and triggered `Refresh()`. Added defensive `_disposed` checks in `Refresh()`, `Clear()`, and `Recycle()`. |

## Diff Highlights

```csharp
<<<<
        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            SetupHeaderCompositorSync();
            Refresh();
        }

        private void OnUnloaded(object sender, RoutedEventArgs e)
        {
            Dispose();
        }
====
        /// <summary>
        /// Handles the <see cref="FrameworkElement.Loaded"/> event, restoring compositor scroll synchronization
        /// and refreshing visual rows when the table re-enters the active visual tree.
        /// </summary>
        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            if (_disposed) return;
            if (TableScrollViewer != null)
            {
                _scrollOffsetY = TableScrollViewer.VerticalOffset;
                _scrollOffsetX = TableScrollViewer.HorizontalOffset;
            }
            SetupHeaderCompositorSync();
            Refresh();
        }

        /// <summary>
        /// Handles the <see cref="FrameworkElement.Unloaded"/> event, pausing active cell editing and compositor animations
        /// without permanently disposing resources while the table is detached from the visual tree (e.g. during tab switching).
        /// </summary>
        private void OnUnloaded(object sender, RoutedEventArgs e)
        {
            CancelCellEdit();
            TeardownHeaderCompositorSync();
        }
>>>>
```

## Tests Added or Updated

- [`scripts/reproduce-tab-switch-freeze.ps1`](file:///d:/DEV/C%23DOTNET/DataSphere/scripts/reproduce-tab-switch-freeze.ps1) — End-to-end UI Automation testing full tab-switching lifecycle:
  1. Open database connection and select table `banggiada_backup`.
  2. Switch away to Home and open Settings tab.
  3. Switch back to Database tab.
  4. Perform physical clicks and mouse wheel scrolling to verify that row recycling, hit testing, and cell selection are fully operative.

## Local Verification

- **Build**: `dotnet build DataSphere\DataSphere.csproj -c Debug` → 0 Warning(s), 0 Error(s).
- **Automation Execution**: `powershell -ExecutionPolicy Bypass -File scripts\reproduce-tab-switch-freeze.ps1`:
  - Before Fix: 0 text elements in table area; mouse wheel scroll caused 0 pixel change (frozen).
  - After Fix: 261 text elements active in table area; mouse scroll dynamically updated visible rows (`03_switched_back_frozen.png` = 66,727 bytes vs `04_scrolled_blank_frozen.png` = 69,999 bytes, distinct image hashes).

## Deviations from Assessment

None. The implementation follows the preferred remediation exactly.

## Follow-ups

- Proceed to `/speckit-bug-test slug=database-tab-switch-freeze` to generate the formal verification artifact report.
