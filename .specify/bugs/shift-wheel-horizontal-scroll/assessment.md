# Bug Assessment: Shift + Mouse Wheel Fails to Scroll Horizontally

- **Slug**: shift-wheel-horizontal-scroll
- **Created**: 2026-10-21
- **Source**: "khi tôi giữ shift và lăn chuột thì nó không cuộn ngang"
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

The user reported that holding the `Shift` key and scrolling the mouse wheel does not scroll the table horizontally:
> "khi tôi giữ shift và lăn chuột thì nó không cuộn ngang"

## Symptom

When a user holds the `Shift` key and scrolls the mouse wheel over the `VirtualTable`, the viewport does not perform horizontal scrolling. Instead, the native WinUI 3 `ScrollViewer` processes the vertical wheel delta as a normal vertical scroll action, moving the rows up/down instead of shifting columns left/right.

## Reproduction

1. Launch DataSphere and connect to `localhost`.
2. Expand `ngocthamcatalog` database, expand `Các bảng`, and open the `admin` table.
3. Move mouse cursor over the table viewport (`VirtualTable`).
4. Press and hold the keyboard `Shift` key.
5. Rotate the mouse wheel downwards by 6 notches.
6. **Observed Behavior**: The table scrolled vertically down to rows 26–46. The horizontal scrollbar remained parked at position 0 (`id` column at the far left edge).
7. **Expected Behavior**: Rotating the mouse wheel while holding `Shift` should translate the viewport horizontally to reveal off-screen columns (`email`, `created_at`, `status`, etc.) with smooth animation.

### Diagnostic Visual Evidence
- **Screenshot**: [`diagnose_shift_wheel_no_horizontal_scroll.png`](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/diagnose_shift_wheel_no_horizontal_scroll.png)
- **Reproduction Script**: [`scripts/reproduce-shift-wheel.ps1`](file:///d:/DEV/C%23DOTNET/DataSphere/scripts/reproduce-shift-wheel.ps1) confirmed on `WinSta0\default` that `VK_SHIFT` + `MOUSEEVENTF_WHEEL` triggered vertical row scrolling down to row 46, leaving `HorizontalOffset = 0`.

## Suspected Code Paths

- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml:13-24`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml#L13-L24): `TableScrollViewer` hosts `VirtualScrollHost` and `VirtualCanvas`. Neither control has a `PointerWheelChanged` handler configured to intercept Shift modifier gestures.
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs:92-110`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L92-L110): The constructor attaches `ViewChanged`, pointer pressed/moved, and key listeners, but does not attach `PointerWheelChanged` on `VirtualCanvas` or `TableScrollViewer`.

## Root Cause Hypothesis

WinUI 3's native `ScrollViewer` (`TableScrollViewer`) is hardwired in DirectComposition to map standard vertical mouse wheel messages (`WM_MOUSEWHEEL`) exclusively to `VerticalOffset`. Unlike standard desktop productivity applications (Microsoft Excel, Visual Studio Code, web browsers), WinUI 3 does not automatically inspect `VirtualKey.Shift` to divert `WM_MOUSEWHEEL` to `HorizontalOffset`. 

Because no child element intercepts `PointerWheelChanged` to handle Shift gestures, the event bubbles directly to `TableScrollViewer`, which consumes it as vertical kinetic scrolling.

## Proposed Remediation

### Preferred Solution: Intercept `PointerWheelChanged` on `VirtualCanvas`

1. Attach `PointerWheelChanged="OnViewportPointerWheelChanged"` to `VirtualCanvas` in `VirtualTable.xaml` (or via constructor in `VirtualTable.xaml.cs`).
2. In `OnViewportPointerWheelChanged(object sender, PointerRoutedEventArgs e)`:
   - Check if `Shift` is pressed using `InputKeyboardSource.GetKeyStateForCurrentThread(VirtualKey.Shift)`.
   - If `Shift` is down:
     - Extract `props = e.GetCurrentPoint(TableScrollViewer).Properties` and `delta = props.MouseWheelDelta`.
     - Calculate horizontal scroll step: `step = (delta / 120.0) * 120.0` (or proportional notch distance).
     - Calculate clamped target offset: `targetX = Math.Clamp(TableScrollViewer.HorizontalOffset - step, 0, Math.Max(0, VirtualScrollHost.Width - TableScrollViewer.ViewportWidth))`.
     - Execute animated horizontal change: `TableScrollViewer.ChangeView(targetX, null, null, disableAnimation: false)`.
     - Set `e.Handled = true` to cancel bubbling, preventing `ScrollViewer` from executing vertical scrolling.
   - If `Shift` is not down:
     - Do not set `e.Handled = true`, allowing the event to bubble seamlessly to `TableScrollViewer` for native DirectComposition kinetic vertical scrolling.

### Files likely to change:
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml)
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs)

### Tests to add or update:
- Create `scripts/verify-shift-wheel-horizontal-scroll.ps1`:
  - Launch app on `WinSta0\default`, open table with wide columns.
  - Hold `VK_SHIFT` and dispatch mouse wheel events.
  - Verify that `TableScrollViewer.HorizontalOffset > 0`, headers shift left in sync, and capture screenshot `winui_shift_wheel_scrolled_horizontal.png`.

## Risks & Considerations

- **Inertial Animation Collision**: Ensure `TableScrollViewer.ChangeView(..., disableAnimation: false)` utilizes the native compositor easing curve without conflicting with pending vertical animations.
- **Trackpad Tilt Support**: Native tilt-wheel / horizontal trackpad swipes already report `props.IsHorizontalMouseWheel == true`. Ensure horizontal wheel gestures are not doubled or suppressed.
