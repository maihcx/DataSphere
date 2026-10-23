# Bug Fix: Tab Selection Background Layer Stale After Closing Preceding Tab

- **Slug**: tab-selection-background-not-updated-on-close
- **Date**: 2026-10-24T01:15:00+07:00
- **Status**: applied
- **Assessment**: [assessment.md](./assessment.md)

## Summary of Changes

Fixed the visual desynchronization where closing an unselected tab preceding the currently active tab caused remaining tabs to shift horizontally while the Fluent selection background highlight capsule (`ShellTabCapsule` / `InnerTabCapsule`) stayed frozen at its outdated physical coordinates in empty space.

Key implementations in `DataSphere/Controls/SlidingTabIndicatorBehavior.cs`:
1. **Dynamic TabItemsSource Property Change Tracking**:
   - Registered a dependency property callback on `TabView.TabItemsSourceProperty` (`RegisterPropertyChangedCallback`) to automatically detect when collection instances are attached, reassigned, or refreshed.
2. **Collection Change Observation (`INotifyCollectionChanged`)**:
   - Subscribed to `INotifyCollectionChanged.CollectionChanged` on the active items source.
   - Listens to item removals, insertions, resets, and index shifts.
   - Implemented clean unsubscription upon property detachment or control unloading to guarantee zero memory leaks.
3. **Multi-Stage Layout Transition Settle Schedule**:
   - Addressed the asynchronous layout latency of WinUI 3's `RepositionThemeTransition` (~350ms).
   - Designed `ScheduleTransitionSettleUpdates` to execute an immediate visual pass followed by staggered milestone passes (40ms, 90ms, 160ms, 260ms, 380ms, 520ms) to follow the repositioning curve and guarantee that coordinates are precisely updated when the layout settles.
4. **Target Coordinate Caching & Redundant Animation Suppression**:
   - Tracked `LastTargetPosition` and `LastTargetWidth` on `TabView`.
   - Prevented animation restarts when the target position has not changed, ensuring smooth cubic-bezier motion without stutter or delay.
5. **Comprehensive Event Coverage**:
   - Subscribed to `TabView.TabCloseRequested`, `TabView.TabDragCompleted`, `TabView.TabDroppedOutside`, and `TabView.TabItemsChanged` across both `ShellWindow` and `DatabasePage`.

## Changed Files

- `DataSphere/Controls/SlidingTabIndicatorBehavior.cs`:
  - Added `LastTargetPositionProperty`, `LastTargetWidthProperty`, and `TransitionMilestonesMs`.
  - Added `ObserveTabItemsSource`, `UnobserveTabItemsSource`, `OnTabItemsSourcePropertyChanged`, `HookCollectionChanged`, `UnhookCollectionChanged`, `OnTabItemsSourceCollectionChanged`.
  - Added `OnTabViewTabCloseRequested`, `OnTabViewTabDragCompleted`, `OnTabViewTabDroppedOutside`.
  - Added `ScheduleTransitionSettleUpdates`.
  - Updated `Attach` and `Detach` to register and unregister all collection and tab lifecycle events.
  - Enhanced `UpdateVisualsPosition` with position caching, dirty checks, and opacity reset when no tab is selected.
- `scripts/reproduce-tab-stale-on-close-bug.ps1`:
  - Real desktop automated regression test with physical mouse events and DirectComposition window capture.
- `scripts/verify-pixels.ps1`:
  - Pixel validation script confirming exact RGB values across the tab header row before and after the fix.

## Deviations from Assessment

None. The remediation directly implemented the proposed architecture with the addition of multi-stage milestone tracking to seamlessly accommodate WinUI 3's ~350ms `RepositionThemeTransition`.

## Verification Results

### 1. Build Verification
- Command: `dotnet build DataSphere\DataSphere.csproj -c Debug`
- Result: **Build succeeded with 0 Warnings, 0 Errors**.

### 2. Live Desktop Automation Verification (`WinSta0\default`)
- Command: `powershell -ExecutionPolicy Bypass -File scripts\reproduce-tab-stale-on-close-bug.ps1`
- Flow:
  1. Opened DataSphere on real desktop station `WinSta0\default`.
  2. Clicked "Cơ sở dữ liệu" (Database) button -> Tab 1 opened and highlighted.
  3. Switched back to Home tab -> Home tab selected.
  4. Clicked "Cài đặt" (Settings) button -> Tab 2 opened and highlighted.
  5. Clicked close button on Tab 1 ("Cơ sở dữ liệu") -> Tab 1 closed. Tab 2 shifted left to Tab 1.
  6. Captured DirectComposition (`PW_RENDERFULLCONTENT`) window state to `step4_after_closing_database_tab.png`.

### 3. Quantitative Pixel Verification
- Command: `powershell -ExecutionPolicy Bypass -File scripts\verify-pixels.ps1`
- Comparison:
  - **Before Fix**:
    - Settings tab area (`X=80..200`): RGB `(223..224, 216, 213..214)` (Unselected background — missing highlight!).
    - Vacated area (`X=260..380`): RGB `(246, 243, 242)` (White capsule frozen in empty space!).
  - **After Fix**:
    - Settings tab area (`X=80..200`): RGB `(245..246, 243, 242..243)` (White capsule smoothly tracking and highlighting Settings tab!).
    - Vacated area (`X=260..380`): RGB `(224..225, 215..216, 212..213)` (Returned cleanly to unselected background!).
