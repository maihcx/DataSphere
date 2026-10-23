# Bug Fix: Sliding Tab Selection Background Layer Stale Capsule On Tear-Off

- **Slug**: inner-tab-tearoff-stale-capsule
- **Date**: 2026-10-24T03:08:00+07:00
- **Status**: applied
- **Assessment**: [assessment.md](./assessment.md)

## Summary of Changes

Resolved the issue where tearing off a database workspace tab into an independent window and subsequently switching to the anchored "Kết nối" (Connection catalog) tab left the sliding background selection capsule (`InnerTabCapsule`) frozen under `localhost` instead of gliding to "Kết nối".

Key root cause resolutions:
1. **Compositor Lifecycle & Auto-Healing Visual Initialization** in `DataSphere/Controls/SlidingTabIndicatorBehavior.cs`:
   - When `CachedContentControl.DisconnectFromParent` detached `DatabasePage` during window tear-off, `RemoveVisuals` cleaned up composition visuals from the donor window's `Compositor`.
   - In the newly spawned window, if visual properties were cleared or detached, `UpdateVisualsPosition` auto-heals by invoking `InitializeVisuals` under the new window's independent compositor, ensuring `IndicatorVisual`, `IndicatorShape`, and `IndicatorGeometry` are realized immediately.
   - Guarded compositor-dependent operations: generated capsule translation animations using `capsuleVisual.Compositor` to guarantee animations are always tied to the active window's compositor, preventing cross-compositor `COMException`s.
   - In `RemoveVisuals`, wrapped cleanup in a `try/finally` block to guarantee resetting `IndicatorVisual`, `IndicatorShape`, `IndicatorGeometry`, `LastTargetPosition` (`-1, -1`), and `LastTargetWidth` (`-1.0`).
   - Added `FindFirstTabViewItemInTree(headerRoot)` fallback: when `tabView.SelectedItem == null`, if an anchored tab exists in `TabStripHeader`, it is resolved and selected cleanly.
2. **Layering Cleanup** in `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml`:
   - Removed the wrapping `<Border Grid.Row="0" CornerRadius="6" Background="{ThemeResource CardBackgroundFillColorDefaultBrush}">` that occluded `InnerTabBackgroundCanvas`. `InnerTabView` now directly shares `Grid.Row="0"` with `Background="Transparent"`, aligning with `ShellWindow.xaml`.
3. **Event Delegation & Selection Synchronization** in `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml.cs`:
   - Registered `ConnectionTabItem.AddHandler(UIElement.TappedEvent, ..., true)`, `PointerPressedEvent, ..., true`, and `PointerReleasedEvent, ..., true` with `handledEventsToo = true` so clicks are never swallowed by `TabViewItem` control templates.
   - Subscribed to `ConnectionTabItem.RegisterPropertyChangedCallback(TabViewItem.IsSelectedProperty, ...)` to invoke `ActivateConnectionTab()` whenever selection changes.
   - Added `ActivateConnectionTab()` helper to guarantee selection toggling and call `SlidingTabIndicatorBehavior.UpdatePosition(InnerTabView, animate: true)`.
4. **ShellWindow Synchronization** in `DataSphere/Views/Windows/ShellWindow.xaml.cs`:
   - Added calls to `SlidingTabIndicatorBehavior.UpdatePosition(ShellTabView, animate: true)` in `OnHomeTabTapped` and `ViewModel.PropertyChanged` when `IsHomeSelected` changes.

## Changed Files

- `DataSphere/Controls/SlidingTabIndicatorBehavior.cs`:
  - Added `public static void UpdatePosition(TabView tabView, bool animate = true)`.
  - Added auto-healing visual re-initialization in `UpdatePosition` and `UpdateVisualsPosition`.
  - Added cross-compositor check in `InitializeVisuals` and `try/finally` cleanup in `RemoveVisuals`.
  - Added `FindFirstTabViewItemInTree` fallback in `FindActiveTabViewItem`.
- `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml`:
  - Removed opaque wrapping `<Border>` around `InnerTabView`.
  - Added `Background="Transparent"` and `Tapped="OnConnectionTabTapped"` to the `TabStripHeader` `StackPanel`.
- `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml.cs`:
  - Added robust pointer and tap event handlers (`PointerPressed`, `PointerReleased`, `Tapped`) with `handledEventsToo = true`.
  - Added `ActivateConnectionTab` helper.
- `DataSphere/Views/Windows/ShellWindow.xaml.cs`:
  - Synchronized `SlidingTabIndicatorBehavior.UpdatePosition` when Home tab is selected.
- `scripts/reproduce-and-verify.ps1`:
  - End-to-end real desktop verification script with physical mouse clicks and DirectComposition window capture.
- `scripts/map-crop-verified.ps1`:
  - DirectComposition pixel map analysis proving capsule translation.

## Deviations from Assessment

None. The implementation followed the proposed remediation with the addition of auto-healing visual initialization in `UpdatePosition` and `UpdateVisualsPosition` to robustly recover from any intermediate disconnected state during window tear-off.

## Verification Results

### 1. Build Verification
- Command: `dotnet build DataSphere\DataSphere.csproj -c Debug`
- Result: **Build succeeded with 0 Warnings, 0 Errors**.

### 2. Live Real Desktop Verification (`WinSta0\default`)
- Command: `powershell -ExecutionPolicy Bypass -File scripts\reproduce-and-verify.ps1`
- Flow:
  1. Launched DataSphere on real desktop station `WinSta0\default`.
  2. Opened "Cơ sở dữ liệu" (Database) workspace page.
  3. Double-clicked `localhost` connection entry in connection tree to open database session tab.
  4. Performed physical drag-and-drop to tear off "Cơ sở dữ liệu" tab into a new independent window (`WindowEx`).
  5. In the torn-off window, physically clicked on the anchored "Kết nối" (Connection) tab.
  6. Captured DirectComposition (`PW_RENDERFULLCONTENT`) window state to `verified_step4_connection_selected.png`.
- DirectComposition Pixel Analysis (`scripts/map-crop-verified.ps1`):
  - Capsule characters (`C`) at Y=72..78 shifted completely to X=20..95, directly underneath "Kết nối":
    ```
    Y=072: ....CCCCCCCCCCCCCCCC....T.............................................
    Y=075: ....CCCCCCCCCCCCCCCC..................................................
    Y=078: ....CCCCCCCCCCCCCCCC..................................................
    ```
  - Unselected `localhost` area (X=130..250) has 0 capsule pixels (`.`), confirming the capsule cleanly glided to "Kết nối".
  - Content area displays the Connection catalog view.
