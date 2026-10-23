---
description: "Task list for Fluent Tab Selection Pill, Sliding Background & Directional Page Motion"
---

# Tasks: Fluent Tab Selection Pill, Sliding Background & Directional Page Motion

**Input**: Design documents from `specs/018-tab-motion-and-indicator/`  
**Prerequisites**: `plan.md` (required), `spec.md` (required), `research.md`, `data-model.md`, `contracts/control-contracts.md`, `quickstart.md`  
**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `- [ ] [ID] [P?] [Story?] Description with file path`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (`[US1]`, `[US2]`, `[US3]`)
- Exact file paths included in all task descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Baseline verification and build sanity check

- [ ] T001 Verify existing build baseline with `dotnet build DataSphere\DataSphere.csproj -c Debug`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core motion configuration metrics that MUST be complete before user stories begin

**CRITICAL**: Foundational metrics in `TabMotionConfiguration.cs` block downstream control behaviors.

- [ ] T002 Refactor motion timing and geometry constants (300ms ContentTransitionDuration, 250ms TabIndicatorDuration, 32.0f EntranceOffsetX, 20.0f IndicatorWidth, 3.0f IndicatorHeight, 1.5f IndicatorCornerRadius, 6.0f BackgroundCornerRadius) in `DataSphere/Controls/TabMotionConfiguration.cs`

**Checkpoint**: Foundation ready - user story implementation can now begin.

---

## Phase 3: User Story 1 - Refined Windows 11 Accent Pill Indicator & Sliding Tab Background (Priority: P1) 🎯 MVP

**Goal**: Deliver a compact horizontal rounded pill indicator (20px × 3px, CornerRadius 1.5px) matching Windows 11 system accent color, and a smooth hardware-accelerated sliding selection background capsule (CornerRadius 6px) across tabs.

**Independent Test**: Launch application, switch tabs in `ShellWindow` or `DatabasePage`; verify that the indicator renders as a 20px × 3px rounded pill matching the OS accent color, and the tab selection background capsule glides smoothly between tabs without visual popping.

### Implementation for User Story 1

- [ ] T003 [US1] Update selected visual states in `DataSphere/Themes/TabStyles.xaml` to set `PillBorder.Background = "Transparent"` in Selected, PointerOverSelected, and PressedSelected states so the sliding background capsule is visible without color snapping
- [ ] T004 [US1] Implement dynamic Windows 11 system accent color and theme resolution (`AccentFillColorDefaultBrush` -> `SystemAccentColor` -> `UISettings.GetColorValue`) with `ActualThemeChanged` synchronization in `DataSphere/Controls/SlidingTabIndicatorBehavior.cs`
- [ ] T005 [US1] Implement `AccentPillVisual` as a `ShapeVisual` with `CompositionRoundedRectangleGeometry` (20px × 3px, CornerRadius 1.5px) centered horizontally under the active tab in `DataSphere/Controls/SlidingTabIndicatorBehavior.cs`
- [ ] T006 [US1] Implement `BackgroundCapsuleVisual` as a `ShapeVisual` with `CompositionRoundedRectangleGeometry` (CornerRadius 6.0px) placed at the bottom visual layer of `TabView`, animating `Offset` and `Size` across tab switches in `DataSphere/Controls/SlidingTabIndicatorBehavior.cs`

**Checkpoint**: At this point, User Story 1 is fully functional and independently testable (MVP).

---

## Phase 4: User Story 2 - Tab-Order-Aware Horizontal Page Content Sliding Transition (Priority: P1)

**Goal**: Viewport content enters with a 300ms horizontal slide (`±32px -> 0px`) and fade (`0.0 -> 1.0`) oriented according to tab sequence (entering from right for forward navigation, left for backward navigation).

**Independent Test**: Open multiple tabs; navigate forward (Tab 1 -> Tab 2) and verify content slides in from the right (`+32px -> 0px`); navigate backward (Tab 2 -> Tab 1) and verify content slides in from the left (`-32px -> 0px`) over 300ms.

### Implementation for User Story 2

- [ ] T007 [US2] Add `SelectedIndex` dependency property (int, default -1) and previous index tracking to determine slide direction in `DataSphere/Controls/CachedContentControl.cs`
- [ ] T008 [US2] Implement direction-aware horizontal entrance animation (`Translation` along X-axis: `+32px` for forward navigation, `-32px` for backward navigation) with 300ms duration, opacity fade, and Fluent Decelerate easing in `DataSphere/Controls/CachedContentControl.cs`
- [ ] T009 [P] [US2] Bind `SelectedIndex="{x:Bind ViewModel.SelectedTabIndex, Mode=OneWay}"` on `CachedContentControl` in `DataSphere/Views/Windows/ShellWindow.xaml`
- [ ] T010 [P] [US2] Bind `SelectedIndex="{x:Bind ViewModel.SelectedTabIndex, Mode=OneWay}"` on `CachedContentControl` in `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml`

**Checkpoint**: User Stories 1 AND 2 are both independently functional and deliver cohesive tab-and-page motion.

---

## Phase 5: User Story 3 - System Accessibility & Motion Suppression (Priority: P2)

**Goal**: Instantly switch tabs and page content with zero animation duration when OS animation effects are turned off.

**Independent Test**: Verify that when `UISettings.AnimationsEnabled == false`, `SlidingTabIndicatorBehavior` and `CachedContentControl` set offsets immediately with 0ms transition.

### Implementation for User Story 3

- [ ] T011 [US3] Verify and ensure accessibility bypass logic in `DataSphere/Controls/SlidingTabIndicatorBehavior.cs` and `DataSphere/Controls/CachedContentControl.cs` applies instant visual placement (<1ms) without dispatching animations when `TabMotionConfiguration.AreAnimationsEnabled` is false

**Checkpoint**: All user stories functional and compliant with Windows Accessibility guidelines.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Quality gates, documentation, and live visual verification

- [ ] T012 Ensure 100% US English XML doc comments and Clean MVVM compliance across `DataSphere/Controls/TabMotionConfiguration.cs`, `SlidingTabIndicatorBehavior.cs`, and `CachedContentControl.cs`
- [ ] T013 Compile project with `dotnet build DataSphere\DataSphere.csproj -c Debug` to verify 0 errors and 0 warnings
- [ ] T014 Execute live UI automation verification on interactive desktop (`WinSta0\default`) using `scripts/test-real-desktop.ps1` and capture DirectComposition screenshot evidence

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 - BLOCKS all user stories.
- **User Story 1 (Phase 3)**: Depends on Phase 2 - delivers core tab visual refinement (MVP).
- **User Story 2 (Phase 4)**: Depends on Phase 2 - delivers directional viewport motion. Can run in parallel with US1 or sequentially after US1.
- **User Story 3 (Phase 5)**: Depends on US1 and US2 implementation to enforce accessibility suppression.
- **Polish (Phase 6)**: Depends on all user stories being implemented.

### Parallel Opportunities

- T009 and T010 can be executed in parallel (different XAML view files).
- Phase 3 (US1: Tab header visuals) and Phase 4 (US2: Viewport content transition) touch distinct control areas and can be implemented concurrently once Foundational (Phase 2) completes.

---

## Implementation Strategy

### MVP First (User Story 1 Only)
1. Complete Phase 1: Setup (`T001`).
2. Complete Phase 2: Foundational (`T002`).
3. Complete Phase 3: User Story 1 (`T003`–`T006`).
4. Validate MVP: Tab indicator renders as a 20px × 3px rounded pill matching Windows 11 accent color, with smooth background capsule sliding.

### Incremental Delivery
1. Add User Story 2 (`T007`–`T010`): Direction-aware 300ms horizontal page sliding.
2. Add User Story 3 (`T011`): Accessibility suppression verification.
3. Complete Polish (`T012`–`T014`): Zero-error compilation and live UI screenshot verification.
