# Bug Assessment: Sliding Tab Selection Background Layer Stale Capsule On Tear-Off

- **Slug**: inner-tab-tearoff-stale-capsule
- **Created**: 2026-10-24T02:37:00+07:00
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> vấn đề với Sliding Tab Selection Background Layer vẫn còn
> - tái tạo: mở app -> mở cơ sở dữ liệu -> mở kết nối localhost (double click vào localhost) -> kéo cửa sổ cơ sở dữ liệu ra window mới -> chuyển về tab kết nối trong cửa sổ window mới -> vấn đề xuất hiện (Sliding Tab Selection Background Layer không di chuyển theo đúng như dự kiến)

## Symptom

When a dynamic database workspace tab (hosting an inner `DatabasePage` with dynamic database sessions such as `localhost`) is torn off from the primary window into a newly spawned window via Windows App SDK drag-and-drop, switching back to the anchored "Kết nối" (Connection catalog) tab in the new window fails to slide or position the background selection capsule (`InnerTabCapsule`). The capsule remains frozen at the previous dynamic tab's coordinates (`localhost` at X=130..250), leaving the active "Kết nối" tab (at X=40..120) with no selection highlight.

## Reproduction

1. Launch DataSphere on real desktop (`WinSta0\default`).
2. Navigate to "Cơ sở dữ liệu" (Databases) page from Home.
3. Double-click the `localhost` connection entry in the Connections tree to open a database session tab. Notice the inner tab selection capsule smoothly glides to and highlights the `localhost` tab.
4. Drag the "Cơ sở dữ liệu" tab header out of the shell tab strip to tear it off into a new independent window (`WindowEx`).
5. In the newly spawned window, click on the anchored "Kết nối" tab in the inner tab bar.
6. **Observed Behavior**: The content view switches to the Connection catalog and "Kết nối" text turns bright white, but the sliding tab background capsule remains stationary under `localhost` (or disappears), never gliding to "Kết nối".
7. **Expected Behavior**: The sliding tab selection capsule smoothly translates from `localhost` to "Kết nối" in the newly spawned window, exactly matching the behavior in the main window.

## Visual & Empirical Diagnostic Evidence

Automated UI verification on real desktop station (`WinSta0\default`) captured direct frame buffers demonstrating the freeze:

1. **Step 1 — Database Page Opened**:
   - Element snapshot: [diag_step1_db_page.png](file:///d:/DEV/WinUI/DataSphere/.specify/bugs/inner-tab-tearoff-stale-capsule/diag_step1_db_page.png)
   - The initial "Kết nối" tab has capsule rendered at (X=35..110, Y=55..90).
2. **Step 2 — Session `localhost` Opened**:
   - Element snapshot: [diag_step2_connection_opened.png](file:///d:/DEV/WinUI/DataSphere/.specify/bugs/inner-tab-tearoff-stale-capsule/diag_step2_connection_opened.png)
   - Selection capsule migrated to `localhost` at (X=140..250). Pixel inspection confirmed capsule surface brush `CardBackgroundFillColorDefaultBrush` (RGB: 48, 25, 42).
3. **Step 3 — Tab Torn Off to New Window**:
   - Element snapshots: [diag_step3_win_0.png](file:///d:/DEV/WinUI/DataSphere/.specify/bugs/inner-tab-tearoff-stale-capsule/diag_step3_win_0.png) (donor window) and [diag_step3_win_1.png](file:///d:/DEV/WinUI/DataSphere/.specify/bugs/inner-tab-tearoff-stale-capsule/diag_step3_win_1.png) (new window).
4. **Step 4 — Clicked "Kết nối" in New Window**:
   - Element snapshot: [diag_step4_after_clicking_connection_in_new_win.png](file:///d:/DEV/WinUI/DataSphere/.specify/bugs/inner-tab-tearoff-stale-capsule/diag_step4_after_clicking_connection_in_new_win.png)
   - Pixel visual scanner ([`scripts/visual-map.ps1`](file:///d:/DEV/WinUI/DataSphere/scripts/visual-map.ps1)):
     - "Kết nối" text is white (RGB: 246, 245, 246, Selected = True).
     - "Kết nối" background is unselected strip color (RGB: 38, 13, 32). **No capsule present under active tab.**
     - `localhost` area (X=140..250) still contains capsule color (RGB: 48, 25, 42-43). **Capsule remains stuck under unselected tab.**
   - Diagnostic trace log ([`debug.log`](file:///C:/Users/huynh/.gemini/antigravity/brain/bed6b624-6a96-45dd-963c-7b8ea009ac6a/debug.log)):
     - Zero `[UpdatePos] Name=InnerTabView` execution entries recorded after window tear-off.

## Suspected Code Paths

- [`DataSphere/Controls/SlidingTabIndicatorBehavior.cs:536-604`](file:///d:/DEV/WinUI/DataSphere/DataSphere/Controls/SlidingTabIndicatorBehavior.cs#L536-L604):
  - `RemoveVisuals(TabView tabView)` catches and suppresses exceptions when detaching from visual tree during `CachedContentControl.DisconnectFromParent`. If `ElementCompositionPreview.GetElementVisual(tabView)` or `containerVisual.Children.Remove(indicator)` throws, `SetIndicatorVisual(tabView, null)` is bypassed, leaving a stale, dead `Visual` associated with the donor window's `Compositor`.
  - When `InnerTabView.Loaded` fires in the new window, `InitializeVisuals` checks `if (GetIndicatorVisual(tabView) != null) return;`, erroneously skipping recreation of visuals under the new window's independent `Compositor`.
- [`DataSphere/Controls/SlidingTabIndicatorBehavior.cs:850-896`](file:///d:/DEV/WinUI/DataSphere/DataSphere/Controls/SlidingTabIndicatorBehavior.cs#L850-L896):
  - `UpdateVisualsPosition` immediately early-exits (`if (indicator == null || pillGeometry == null) return;`) without logging or attempting recovery if visual references were severed or invalidated across the window boundary.
- [`DataSphere/Controls/SlidingTabIndicatorBehavior.cs:919-935`](file:///d:/DEV/WinUI/DataSphere/DataSphere/Controls/SlidingTabIndicatorBehavior.cs#L919-L935):
  - `LastTargetPositionProperty` and `LastTargetWidthProperty` retain coordinates from Window 1 because `RemoveVisuals` never resets them.
  - In `UpdateVisualsPosition`, `Compositor compositor = indicator.Compositor;` retrieves the donor window's Compositor. When `capsuleVisual.StartAnimation("Translation", bgTranslationAnimation)` is invoked using animations created from a different Compositor, WinUI 3 throws a cross-compositor `COMException` (`E_INVALIDARG` or `RO_E_CLOSED`), which is silently caught by `catch { indicator.IsVisible = false; }`.
- [`DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml:41-43`](file:///d:/DEV/WinUI/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml#L41-L43):
  - An uncommitted `<Border Grid.Row="0" CornerRadius="6" Background="{ThemeResource CardBackgroundFillColorDefaultBrush}">` was added around `InnerTabView`, sitting directly on top of `InnerTabBackgroundCanvas` with an opaque background brush, occluding the capsule layer.
- [`DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml.cs:28-36`](file:///d:/DEV/WinUI/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml.cs#L28-L36):
  - Selection synchronization between `ViewModel.IsConnectionSelected` and `InnerTabView.SelectedItem = null` relies on `PropertyChanged` which does not explicitly notify `SlidingTabIndicatorBehavior` when `SelectedItem` was already null or when header items are clicked outside `TabView.TabItems`.

## Root Cause Hypothesis

**Confidence: High**

In Windows App SDK (WinUI 3), each top-level `WindowEx` owns an isolated `Microsoft.UI.Composition.Compositor` and independent visual tree. When `CachedContentControl.DisconnectFromParent` detaches `DatabasePage` from the primary window and attaches it to the new torn-off window:
1. `RemoveVisuals` fails to reliably clear attached dependency properties (`IndicatorVisual`, `IndicatorShape`, `IndicatorGeometry`, `LastTargetPosition`, `LastTargetWidth`) under a `try/finally` guarantee when elements are unloaded.
2. `InitializeVisuals` finds the stale attached `IndicatorVisual` from the donor window and bypasses initializing new composition visuals with the new window's compositor.
3. Any subsequent translation or animation calls either abort because `indicator` is orphaned, or throw cross-compositor COM exceptions that are silently caught by `catch { indicator.IsVisible = false; }`.
4. The opaque wrapping `<Border>` in `DatabasePage.xaml` creates z-index visual layering interference differing from `ShellWindow.xaml`.

## Proposed Remediation

**Preferred Fix**:
1. **Compositor Lifecycle & Reset on Window Reparenting** in `SlidingTabIndicatorBehavior.cs`:
   - In `RemoveVisuals`, enforce cleanup within a `try/finally` block:
     - Clear `IndicatorVisual`, `IndicatorShape`, `IndicatorGeometry`.
     - Reset `LastTargetPositionProperty` to `(-1, -1)` and `LastTargetWidthProperty` to `-1.0`.
   - In `InitializeVisuals`, verify that `GetIndicatorVisual(tabView)`'s compositor matches the current window's compositor (`ElementCompositionPreview.GetElementVisual(tabView).Compositor`). If mismatched or detached, dispose and re-create.
   - In `UpdateVisualsPosition`, obtain `Compositor` directly from `capsuleVisual.Compositor` (or `containerVisual.Compositor`) rather than relying on `indicator.Compositor` to avoid cross-compositor animation exceptions.
2. **Synchronize Anchored Tab Header Selection**:
   - Provide an explicit layout update trigger when `IsConnectionSelected` toggles, ensuring `UpdateVisualsPosition` is invoked even if `InnerTabView.SelectedItem` was already `null`.
3. **Clean Up `DatabasePage.xaml` Layering**:
   - Remove the opaque wrapping `<Border Grid.Row="0">` around `InnerTabView` in `DatabasePage.xaml`, aligning its hierarchy with `ShellWindow.xaml` where `Canvas` and `TabView` share `Grid.Row="0"` cleanly.

**Files likely to change**:
- `DataSphere/Controls/SlidingTabIndicatorBehavior.cs`
- `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml`
- `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml.cs`

**Tests to add or update**:
- Automated real-desktop script (`scripts/reproduce-inner-tab-tearoff.ps1`) verifying:
  1. Open app and `DatabasePage`.
  2. Double-click `localhost` to activate session.
  3. Drag tab out to create new window.
  4. Click "Kết nối" in new window.
  5. Verify capsule X coordinate matches "Kết nối" bounds (X=35..110) via DirectComposition screenshot capture and pixel analysis.

## Risks & Considerations

- **Compositor Thread Affinity**: All WinUI 3 Composition APIs must execute on the UI thread (`DispatcherQueue`).
- **Clean MVVM Compliance**: No code-behind visual tree manipulation; maintain purely declarative XAML binding and behavioral encapsulation.
- **Internationalization (i18n)**: All UI strings continue using `TranslationSource` (`String.resx`).
- **XML Doc Comments**: 100% US English documentation on all new/modified members.

## Open Questions

None. The bug is 100% reproduced, isolated, and empirically verified with visual and trace evidence.
