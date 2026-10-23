# Feature Specification: Tab Switching Transition Animations (ShellWindow & DatabasePage)

**Feature Branch**: `017-tab-transition-animations`

**Created**: 2026-10-23

**Status**: Draft

**Input**: User description: "triển khai thêm hiệu ứng khi tôi chuyển tab cho ShellWindow và DatabasePage (dành cho tab và nội dung controls:CachedContentControl)"

## Clarifications

### Session 2026-10-23

- Q: Bạn muốn kiểu chuyển động (motion style) bằng WinUI Compositor nào cho nội dung khi chuyển đổi tab trong `CachedContentControl`? → A: Option A - Fade + Micro-Slide Y (167ms, Opacity 0 → 1, Translation Y +12px → 0px, CubicBezier(0.1, 0.9, 0.2, 1.0)).
- Q: Bạn muốn hiệu ứng chuyển động cho thanh tiêu đề tab (`TabViewItem`) ở `ShellWindow` và `DatabasePage` được thực hiện như thế nào? → A: Option B - Sliding Selection Pill / Underline (Compositor horizontal sliding animation using `Offset` / `Vector3KeyFrameAnimation` between tab positions).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Smooth Viewport Content Transition in CachedContentControl (Priority: P1)

When a user switches tabs in either the main application shell (`ShellWindow`) or within a database workspace (`DatabasePage`), the newly activated content view transitions smoothly (e.g., subtle opacity fade-in and micro-translation entrance motion) rather than abruptly popping into view, providing a polished and coherent Fluent Design experience while maintaining instant responsiveness.

**Why this priority**: High-fidelity visual transitions between views prevent visual jarring and elevate the perceived quality of the application to Tier-1 enterprise desktop standards.

**Independent Test**: Switch between Home tab, Settings tab, and Database tabs in `ShellWindow`, and switch between Database View / Table Data tabs in `DatabasePage`; verify that each view activates with a fluid, flicker-free entrance transition.

**Acceptance Scenarios**:

1. **Given** multiple open tabs in `ShellWindow`, **When** the user clicks a different tab, **Then** the newly active view hosted inside `CachedContentControl` becomes visible with a smooth, fluid entrance transition (approx. 150–200ms) without visual tearing or frame drop.
2. **Given** multiple open workspace tabs (e.g., Database View, Table Data) in `DatabasePage`, **When** the user switches between them, **Then** the cached content activates smoothly while preserving internal scroll position and without re-triggering heavy data loading passes.

---

### User Story 2 - Fluent Tab Header Interaction & Selection Motion (Priority: P2)

When clicking or moving between tab headers in the Chrome TabView (both outer top-level shell tabs and inner database workspace tabs), the tab selection indicator (pill/underline) slides continuously and horizontally between the previous tab and newly selected tab using WinUI Compositor offset animation, giving a fluid, tactile visual cue of active focus.

**Why this priority**: Responsive, smooth tab header motion provides visual continuity that complements the content viewport transition, creating an integrated Windows 11 Fluent experience.

**Independent Test**: Click different tabs in the TabView header strip; observe that the active selection indicator slides smoothly across the horizontal axis to the newly selected tab.

**Acceptance Scenarios**:

1. **Given** multiple tab items in `ShellWindow` or `DatabasePage` tab strip, **When** a user clicks an inactive tab, **Then** the selection pill/indicator animates horizontally from the old tab position to the new tab position using WinUI 3 Compositor offset animation without visual popping.

---

### User Story 3 - System Accessibility & Reduced Motion Compliance (Priority: P3)

Users who have disabled animations in Windows settings (Windows Settings > Accessibility > Visual Effects > Animation effects = Off) or prefer reduced motion should have animations gracefully suppressed (instant transitions) to avoid motion discomfort and respect accessibility preferences.

**Why this priority**: Respecting OS-level accessibility settings is a core requirement for Tier-1 Windows desktop applications.

**Independent Test**: Disable Windows animations in system settings or toggle accessibility mode; verify tab and content transitions become instant with 0ms duration.

**Acceptance Scenarios**:

1. **Given** Windows animation effects are disabled in the operating system, **When** the user switches tabs, **Then** content and tab headers switch instantly without transition delays or motion artifacts.

---

### Edge Cases

- **Rapid Tab Switching (Click Spamming)**: What happens when a user clicks rapidly across multiple tabs in quick succession? Running animations must cancel or gracefully complete immediately to the latest target, avoiding visual overlaps, half-transparent views, or stuck states.
- **Heavy Content Viewports**: What happens when the activating tab contains a large dataset in `VirtualTable` (e.g. 10,000+ rows)? The transition must run smoothly via hardware-accelerated compositor or lightweight animation without blocking the UI thread, maintaining 60 FPS.
- **Tab Close During Transition**: What happens if an active tab is closed while its content is transitioning? The transition stops cleanly and the next selected tab's content begins its transition without null reference exceptions.
- **Theme Change During Tab Switch**: What happens if the system or app theme changes while switching tabs? Visual brushes and transitions adjust seamlessly without visual artifacts or inverted colors.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide an off-thread, hardware-accelerated entrance transition for newly activated content within `CachedContentControl` using WinUI 3 Composition APIs (`Microsoft.UI.Composition.Visual` retrieved via `ElementCompositionPreview.GetElementVisual`).
- **FR-002**: The content transition MUST execute a 167ms entrance animation comprising:
  1. Opacity transition from 0.0 to 1.0 (`ScalarKeyFrameAnimation`).
  2. Vertical micro-slide translation along the Y-axis from +12px to 0px (`Vector3KeyFrameAnimation`).
  3. Cubic-bezier easing curve `CubicBezierEasingFunction(0.1f, 0.9f, 0.2f, 1.0f)` matching Windows 11 Fluent Design Decelerate motion.
- **FR-003**: The content transition MUST operate non-destructively on cached views without detaching them from the visual tree, preserving the view's internal state (scroll offsets, cursor positions, selections).
- **FR-004**: Tab header selection in both `ShellWindow` (top-level shell tabs) and `DatabasePage` (inner workspace tabs) MUST feature a sliding selection indicator (pill/underline) that animates horizontally between tab positions using WinUI 3 Compositor (`Offset` / `Vector3KeyFrameAnimation` or connected indicator offset animation, approx. 150–200ms).
- **FR-005**: If the user rapidly switches tabs before a prior transition completes, the system MUST immediately finalize or abort the prior animation and transition directly to the newly selected view, preventing multiple views from remaining partially visible or conflicting.
- **FR-006**: System MUST respect Windows Accessibility animation settings (`Windows.UI.ViewManagement.UISettings.AnimationsEnabled`), automatically bypassing transition animations when animations are turned off at the OS level.
- **FR-007**: Transition animations MUST run efficiently on the compositor thread to ensure UI frame rate remains at 60 FPS (<16ms per frame) even on large datasets.
- **FR-008**: The implementation MUST strictly preserve Clean MVVM boundaries (Zero code-behind business or visual tree manipulation in `DatabasePage.xaml.cs` or `ShellWindow.xaml.cs`; all transitions encapsulated within the view/control template layer).

### Key Entities

- **`CachedContentControl`**: Reusable viewport host control managing view cache and driving entrance/transition animations for active elements.
- **`TransitionConfiguration`**: Motion timing parameters (duration, easing curve, translation offset) aligned with Fluent Design motion guidelines.
- **`TabViewSelectionVisual`**: Visual state representation and motion indicator for tab headers in top-level and inner tab strips.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Tab content switching in both `ShellWindow` and `DatabasePage` executes the 167ms compositor transition smoothly on the compositor thread without blocking UI thread or layout passes.
- **SC-002**: UI frame rate remains stable at 60 FPS during transition execution without noticeable hitching, jank, or layout stutter.
- **SC-003**: Rapid tab switching (e.g. 5 tab clicks in under 1 second) completes reliably without displaying blank viewports, overlapping views, or lingering intermediate opacity states.
- **SC-004**: When Windows animation effects are toggled off, tab switching executes instantaneously (<1ms) with zero transition animation.
- **SC-005**: 100% adherence to Clean MVVM; `DatabasePage.xaml.cs` and `ShellWindow.xaml.cs` maintain zero code-behind DOM manipulation.
- **SC-006**: Tab header selection indicator transitions with smooth horizontal sliding motion between tabs without visual flickering, misalignment, or layout recalculation overhead.

## Assumptions

- Target environment is Windows 10/11 running WinUI 3 with hardware acceleration enabled by default.
- WinUI 3 / Windows App SDK animation capabilities (e.g. `Microsoft.UI.Xaml.Media.Animation.Storyboard` or Composition APIs) are supported on target systems.
- Top-level shell tabs and inner database tabs use the existing `CachedContentControl` infrastructure established in the previous bug fix.
