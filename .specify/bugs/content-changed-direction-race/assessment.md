# Bug Assessment: Race Condition Between Content Changed and Selected Index in CachedContentControl

- **Slug**: content-changed-direction-race
- **Created**: 2026-10-23T16:30:00+07:00
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

> "sự kiện OnContentChanged chạy trước OnSelectedIndexChanged dẫn tới việc _slideDirection không kịp cập nhật"

The user observed that when switching tabs, the `OnContentChanged` callback in `CachedContentControl` executes before `OnSelectedIndexChanged`. As a consequence, `_slideDirection` is not updated in time, causing the horizontal slide entrance transition to play with the stale direction from the previous tab switch.

## Symptom

When switching tabs in either the outer workspace (`ShellWindow`) or the inner database sessions (`DatabasePage`):
- Switching from a higher tab index to a lower tab index (e.g., from Tab 1 `localhost` to Tab 0 `Kết nối`) plays the slide entrance animation as if entering from the right (+32px, forward motion) instead of entering from the left (-32px, backward motion).
- Switching subsequently from a lower tab index to a higher tab index plays the slide entrance animation entering from the left (-32px, backward motion) instead of entering from the right (+32px, forward motion).
- Every tab switch transition runs with an inverted / stale direction because `_slideDirection` lags behind by exactly one transition cycle.

## Reproduction

1. Launch DataSphere on interactive desktop `WinSta0\default`.
2. Navigate to Database page, right-click `localhost` connection and select "Mở kết nối" to open an active session tab alongside the anchored "Kết nối" explorer tab.
3. Total inner tabs: Tab 0 (`Kết nối`) and Tab 1 (`localhost`). Active tab is Tab 1.
4. Click Tab 0 (`Kết nối`) to navigate backwards (1 -> 0, expected direction: -1, offset: -32px).
   - `OnContentChanged` fires first.
   - `UpdateActiveContent` reads `_slideDirection` (which still holds +1 from the initial state).
   - Compositor starts horizontal slide from +32px (entering from the right, forward).
   - Immediately after, `OnSelectedIndexChanged` fires and sets `_slideDirection = -1`. The update arrives too late.
5. Click Tab 1 (`localhost`) to navigate forwards (0 -> 1, expected direction: +1, offset: +32px).
   - `OnContentChanged` fires first.
   - `UpdateActiveContent` reads `_slideDirection` (which still holds -1 from step 4).
   - Compositor starts horizontal slide from -32px (entering from the left, backward).
   - Immediately after, `OnSelectedIndexChanged` fires and sets `_slideDirection = +1`. The update arrives too late.

Visual proof captured during diagnostic test run:
- Initial state with `localhost` active: [01_tab_localhost_active.png](file:///d:/DEV/C%23DOTNET/DataSphere/.specify/bugs/content-changed-direction-race/01_tab_localhost_active.png)
- Backward switch to `Kết nối`: [02_tab_ketnoi_active.png](file:///d:/DEV/C%23DOTNET/DataSphere/.specify/bugs/content-changed-direction-race/02_tab_ketnoi_active.png)
- Forward switch to `localhost`: [03_tab_localhost_switched_back.png](file:///d:/DEV/C%23DOTNET/DataSphere/.specify/bugs/content-changed-direction-race/03_tab_localhost_switched_back.png)

## Suspected Code Paths

- `DataSphere/Controls/CachedContentControl.cs:88-97`
  `OnSelectedIndexChanged` updates `_slideDirection = newIdx > oldIdx ? 1 : -1` only when the `SelectedIndex` dependency property changes.
- `DataSphere/Controls/CachedContentControl.cs:99-105`
  `OnContentChanged` immediately and synchronously calls `UpdateActiveContent(e.NewValue)` as soon as the `Content` dependency property changes.
- `DataSphere/Controls/CachedContentControl.cs:138-160`
  `UpdateActiveContent` synchronously computes `float offsetX = _slideDirection >= 0 ? ... : ...` and calls `PlayEntranceTransition(element, offsetX)` without waiting for pending `SelectedIndex` updates that occur in the same UI message cycle.
- `DataSphere/ViewModels/Windows/ShellViewModel.cs:104-115`
  `_tabService.PropertyChanged` handler notifies `SelectedTab` and `ActiveViewportContent`, but fails to notify `EffectiveTabIndex`.
- `DataSphere/ViewModels/Windows/ShellViewModel.cs:220-233`
  `SelectTab(int index)` notifies `SelectedTab` and `ActiveViewportContent`, but fails to notify `EffectiveTabIndex`.
- `DataSphere/ViewModels/Windows/ShellViewModel.cs:200-216`
  `CloseTab(TabItemModel? tab)` fails to notify `EffectiveTabIndex`.
- `DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseViewModel.cs:129-136`
  `SelectConnection()` notifies `ActiveInnerContent`, but fails to notify `EffectiveTabIndex`.

## Root Cause Hypothesis

**Confidence: High**

In WinUI 3 XAML data binding, compiled `{x:Bind}` updates dependency properties independently. `CachedContentControl` exposes two separate dependency properties: `Content` and `SelectedIndex`.

When the user switches tabs, the ViewModel updates both the active content and the effective tab index. In the XAML binding execution order:
1. `Content` is updated first, invoking `OnContentChanged` synchronously.
2. `OnContentChanged` invokes `UpdateActiveContent`, which immediately checks `_slideDirection` to determine whether the entrance transition should slide from `+32px` or `-32px`, and launches the WinUI 3 Compositor keyframe animation.
3. At this moment, `OnSelectedIndexChanged` has NOT yet executed. `_slideDirection` holds the stale value from the previous tab switch.
4. Shortly after in the same or subsequent tick, `SelectedIndex` updates and `OnSelectedIndexChanged` computes the new `_slideDirection`, but the animation is already in flight with the incorrect offset.

Additionally, in `ShellViewModel`, `EffectiveTabIndex` is omitted from `PropertyChanged` invocations in `_tabService.PropertyChanged`, `SelectTab`, and `CloseTab`, meaning `SelectedIndex` on the root viewport is never updated during dynamic workspace tab switches. In `DatabaseViewModel`, `SelectConnection()` similarly omits `EffectiveTabIndex`.

## Proposed Remediation

**Preferred**:

1. **Defer Animation Dispatching in `CachedContentControl.cs`**:
   - In `UpdateActiveContent`, update the visual tree child element visibility (`Visibility.Visible` / `Visibility.Collapsed`) immediately so there is no layout delay or blank flash.
   - Defer the entrance transition animation calculation and dispatching to the UI thread dispatcher queue:
     ```csharp
     DispatcherQueue.TryEnqueue(Microsoft.UI.Dispatching.DispatcherQueuePriority.Normal, () =>
     {
         if (element.Visibility == Visibility.Visible && IsTransitionEnabled && TabMotionConfiguration.AreAnimationsEnabled)
         {
             float offsetX = _slideDirection >= 0
                 ? TabMotionConfiguration.EntranceOffsetX
                 : -TabMotionConfiguration.EntranceOffsetX;
             PlayEntranceTransition(element, offsetX);
         }
     });
     ```
   - Because `DispatcherQueue.TryEnqueue` schedules execution after all synchronous dependency property updates in the current dispatch pass have finished, `OnSelectedIndexChanged` is guaranteed to have updated `_slideDirection` before `PlayEntranceTransition` reads it.
   - If `OnSelectedIndexChanged` executes before `OnContentChanged`, `_slideDirection` is also up to date. This makes `CachedContentControl` completely immune to the execution order of `Content` and `SelectedIndex` data bindings.

2. **Fix Missing `EffectiveTabIndex` Notifications in ViewModels**:
   - In `ShellViewModel.cs`:
     - Inside `_tabService.PropertyChanged` listener (lines 104-115), add `OnPropertyChanged(nameof(EffectiveTabIndex));`.
     - Inside `SelectTab(int index)` (lines 220-233), add `OnPropertyChanged(nameof(EffectiveTabIndex));`.
     - Inside `CloseTab(TabItemModel? tab)` (lines 200-216), add `OnPropertyChanged(nameof(EffectiveTabIndex));`.
   - In `DatabaseViewModel.cs`:
     - Inside `SelectConnection()` (lines 129-136), add `OnPropertyChanged(nameof(EffectiveTabIndex));`.

**Alternatives**:
- Bind a composite navigation context object containing `{ Content, Index }` to a single dependency property.
  *Trade-off*: Requires refactoring ViewModel interfaces and complicates XAML bindings without offering benefits over the dispatcher queue approach.

**Files likely to change**:
- `DataSphere/Controls/CachedContentControl.cs`
- `DataSphere/ViewModels/Windows/ShellViewModel.cs`
- `DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseViewModel.cs`

**Tests to add or update**:
- Automated UI verification script verifying alternating tab transitions (Tab 0 -> Tab 1 -> Tab 0 -> Tab 1) on `WinSta0\default`, confirming smooth directional entrance animations with 0 exceptions and no reverse sliding.
- Unit test ensuring `EffectiveTabIndex` property change notifications are raised correctly in `ShellViewModel` and `DatabaseViewModel`.

## Risks & Considerations

- **Visual Flicker**: Deferring `PlayEntranceTransition` must NOT defer setting `child.Visibility = Visibility.Visible`. Child visibility and initial element opacity (0.0) should be applied synchronously so no blank frame or un-animated flash occurs.
- **Rapid Clicking**: If the user rapidly clicks multiple tabs before an animation finishes, any pending queued transition should only animate the element that remains currently active (`element.Visibility == Visibility.Visible`).

## Open Questions

- None. The root cause is fully identified, isolated, and verified via UI Automation and static code analysis.
