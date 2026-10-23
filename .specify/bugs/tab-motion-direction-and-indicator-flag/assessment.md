# Bug Assessment: Tab Motion Direction Inversion and Accent Indicator Visibility Flag

- **Slug**: tab-motion-direction-and-indicator-flag
- **Created**: 2026-10-23T15:58:00+07:00
- **Source**: pasted text & user screenshot (`media_1792745552565_4db1a96a.png`)
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

The user reported:
> "Indicator trông xấu quá, hãy tạm tắt nó đi bằng cái cờ gì đó (vẫn giữ animation trượt của selected nhé!), đồng thời kiểm tra lại logic animation chuyển tab ở CachedContentControl, tôi thấy hiệu ứng chuyển từ tab thấp lên cao và cao xuống thấp chưa chuẩn lắm!"

Summary:
1. The bottom accent indicator pill is perceived as visually redundant or clashing with the tab layout and user wants an opt-in/opt-out configuration flag (`IsIndicatorVisible` or similar) to cleanly disable it while keeping the sliding background capsule animation intact.
2. The directional horizontal slide transition in `CachedContentControl` between lower-index and higher-index tabs (and vice versa) behaves erratically, feeling reversed or inconsistent during navigation.

## Symptom

1. **Indicator Visibility**: Even when users only desire the smooth background capsule glide, the bottom accent pill is always rendered with no configuration property or attached flag to hide it.
2. **Transition Direction Desynchronization**: In `CachedContentControl`, when switching from a higher-index tab to a lower-index tab (e.g. Tab 2 -> Tab 1 or Tab 1 -> Tab 0), the incoming viewport content often slides in from the right (`+32px`) instead of from the left (`-32px`), or slides inconsistently across rapid switches.

## Reproduction

1. Launch DataSphere with multiple workspace tabs open (e.g. Home, Database, Database (2), Database (3)).
2. Observe that the teal accent pill is permanently attached below each active tab.
3. Switch from Tab 0 (Home) -> Tab 1 ("Cơ sở dữ liệu") -> Tab 2 ("Cơ sở dữ liệu (2)"). Observe entrance animation direction.
4. Switch backward from Tab 2 -> Tab 1, or Tab 1 -> Tab 0 (Home).
5. Observe that the entrance transition does not reliably enter from the left (`-32px`), because `_lastSelectedIndex` was mutated in `UpdateActiveContent` before or out-of-sync with `OnSelectedIndexChanged`.

## Suspected Code Paths

- `DataSphere/Controls/CachedContentControl.cs:88-94` — `OnSelectedIndexChanged` only updates `_lastSelectedIndex = (int)e.OldValue`, but `UpdateActiveContent` prematurely overrides `_lastSelectedIndex = SelectedIndex` at line 142.
- `DataSphere/Controls/CachedContentControl.cs:132-143` — Direction computation compares `SelectedIndex` against `_lastSelectedIndex` inside `UpdateActiveContent`, which runs when `Content` changes, frequently before the `SelectedIndex` dependency property binding has propagated the new index.
- `DataSphere/Controls/CachedContentControl.cs:203-212` — Slide animation inserts and starts animation on `"Translation"` on the composition visual PropertySet without cleanly synchronizing starting offsets.
- `DataSphere/Controls/SlidingTabIndicatorBehavior.cs:140-160` — Lacks an attached dependency property `IsIndicatorVisible` to selectively toggle the accent pill visibility while keeping `BackgroundCapsule` motion active.
- `DataSphere/Controls/TabMotionConfiguration.cs:35-50` — Lacks a centralized global configuration switch `IsIndicatorVisible` (or `ShowAccentIndicator`) for default indicator suppression.

## Root Cause Hypothesis

**Confidence: High**

1. **Direction Desynchronization**: In `CachedContentControl`, `Content` (`ActiveViewportContent`) and `SelectedIndex` (`EffectiveTabIndex`) are two independent XAML dependency properties. When the active tab changes in the ViewModel, property change notifications fire sequentially. In XAML, `Content` binding executes `UpdateActiveContent` before `SelectedIndex` has updated its new value. Consequently, `UpdateActiveContent` reads the stale `SelectedIndex` (still equal to `_lastSelectedIndex`), causing the condition `SelectedIndex < _lastSelectedIndex` to evaluate to false. It then overwrites `_lastSelectedIndex = SelectedIndex`, irreversibly corrupting the transition state history so that subsequent backward switches also evaluate to forward (`+32px`).
2. **Indicator Toggle**: `SlidingTabIndicatorBehavior` tightly couples the indicator visual lifecycle to `IsEnabledProperty`. There is no granular attached property `IsIndicatorVisible` (defaulting to `false` per user preference) to hide the accent pill visual while allowing the background capsule to glide independently.

## Proposed Remediation

**Preferred**:
1. **Direction-Safe Tracking in `CachedContentControl`**:
   - In `OnSelectedIndexChanged(d, e)`: Compute and record `_slideDirection = (newIndex >= oldIndex) ? 1 : -1` directly from `e.OldValue` and `e.NewValue`.
   - Remove the mutable assignment `_lastSelectedIndex = SelectedIndex` from `UpdateActiveContent`.
   - Use `_slideDirection` to reliably select between `+TabMotionConfiguration.EntranceOffsetX` (forward / lower-to-higher) and `-TabMotionConfiguration.EntranceOffsetX` (backward / higher-to-lower).
   - In addition, if `SelectedIndex` changes for already-loaded content, ensure direction reflects the actual tab progression.
2. **Add Granular Indicator Visibility Flag**:
   - Add `IsIndicatorVisible` attached dependency property in `SlidingTabIndicatorBehavior.cs` (default `false`).
   - Add `IsIndicatorVisible` static configuration property in `TabMotionConfiguration.cs` (default `false`).
   - When `IsIndicatorVisible` is `false`, set `indicatorVisual.IsVisible = false` and skip pill animations, while `bgCapsule` (sliding background) continues to animate smoothly.

**Files likely to change**:
- `DataSphere/Controls/CachedContentControl.cs`
- `DataSphere/Controls/SlidingTabIndicatorBehavior.cs`
- `DataSphere/Controls/TabMotionConfiguration.cs`

**Tests to add or update**:
- Automated UI test validating forward transition (`Tab 0 -> Tab 1 -> Tab 2`) enters from right (`+32px -> 0px`).
- Automated UI test validating backward transition (`Tab 2 -> Tab 1 -> Tab 0`) enters from left (`-32px -> 0px`).
- Verify indicator is hidden when `IsIndicatorVisible = false` and background capsule glides between tabs.

## Risks & Considerations

- **Visual Tree Cache**: In `CachedContentControl`, cached views remain in `Children`. Ensure `Translation` property is cleanly reset to `Vector3.Zero` when an animation ends so elements don't remain offset when reopened.
- **Single Tab / Initial Load**: When opening the app (Home tab), `oldIndex == -1` or `oldIndex == newIndex`, transition should default to neutral (or standard entrance) without erroneous lateral shifts.

## Open Questions

- None. Both requirements are well-defined and straightforward.
