# Tasks: Tab Switching Transition Animations (ShellWindow & DatabasePage)

**Input**: Design documents from `/specs/017-tab-transition-animations/`  
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/control-contracts.md`, `quickstart.md`  

## Format: `- [ ] [ID] [P?] [Story] Description with file path`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., [US1], [US2], [US3])
- Strictly follows Clean MVVM: zero code-behind DOM manipulation in views, declarative XAML binding.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Motion timing constants and centralized configuration

- [ ] T001 Create centralized Fluent motion constants in `DataSphere/Controls/TabMotionConfiguration.cs` (167ms duration, 12px Y translation, Cubic-Bezier `(0.1, 0.9, 0.2, 1.0)`)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Accessibility detection for motion reduction

- [ ] T002 Implement system animation accessibility helper in `DataSphere/Controls/TabMotionConfiguration.cs` via `Windows.UI.ViewManagement.UISettings.AnimationsEnabled`

**Checkpoint**: Foundation ready - user story implementation can begin

---

## Phase 3: User Story 1 - Smooth Viewport Content Transition in CachedContentControl (Priority: P1) 🎯 MVP

**Goal**: Deliver fluid 167ms WinUI 3 Compositor entrance animation on newly activated content within `CachedContentControl` without UI thread blocking or visual tree churn.

**Independent Test**: Switch tabs in `ShellWindow` or `DatabasePage`; verify smooth opacity fade-in (0 → 1) and micro upward slide (+12px → 0px) on viewport content.

- [ ] T003 [US1] Add `IsTransitionEnabledProperty` and `PlayEntranceTransition` to `DataSphere/Controls/CachedContentControl.cs` using `ElementCompositionPreview.GetElementVisual`, `ScalarKeyFrameAnimation`, and `Vector3KeyFrameAnimation`
- [ ] T004 [US1] Update `CachedContentControl.UpdateActiveContent` in `DataSphere/Controls/CachedContentControl.cs` to trigger `PlayEntranceTransition` on newly active views with rapid-switching cancellation
- [ ] T005 [US1] Configure `IsTransitionEnabled="True"` on `CachedContentControl` in `DataSphere/Views/Windows/ShellWindow.xaml` and `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml`

**Checkpoint**: Viewport content transitions smoothly on tab changes across ShellWindow and DatabasePage (MVP complete).

---

## Phase 4: User Story 2 - Fluent Tab Header Sliding Selection Indicator (Priority: P2)

**Goal**: Provide a sliding selection indicator (pill/underline) in `TabView` that smoothly animates horizontally between tabs via Compositor `Offset` animations.

**Independent Test**: Click different tabs in the TabView header; verify active selection indicator slides smoothly to the new tab position.

- [ ] T006 [US2] Implement `SlidingTabIndicatorBehavior` attached property and lifecycle event hooks in `DataSphere/Controls/SlidingTabIndicatorBehavior.cs`
- [ ] T007 [US2] Implement compositor-driven horizontal slide animation logic in `DataSphere/Controls/SlidingTabIndicatorBehavior.cs` targeting indicator visual `Offset.X` and `Size.X` based on selected `TabViewItem` geometry
- [ ] T008 [US2] Attach `controls:SlidingTabIndicatorBehavior.IsEnabled="True"` to `ShellTabView` in `DataSphere/Views/Windows/ShellWindow.xaml` and `InnerTabView` in `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml`

**Checkpoint**: Tab selection indicators slide smoothly across both shell and database tab bars.

---

## Phase 5: User Story 3 - System Accessibility & Reduced Motion Compliance (Priority: P3)

**Goal**: Respect Windows Accessibility reduced motion preferences and gracefully bypass transitions when animations are disabled in OS settings.

**Independent Test**: Disable animations in Windows settings; verify tab switches occur instantaneously (<1ms) without motion.

- [ ] T009 [US3] Integrate `TabMotionConfiguration.AreAnimationsEnabled` in `DataSphere/Controls/CachedContentControl.cs` to bypass viewport animations when animations are disabled
- [ ] T010 [US3] Integrate `TabMotionConfiguration.AreAnimationsEnabled` in `DataSphere/Controls/SlidingTabIndicatorBehavior.cs` to bypass indicator slide animations when animations are disabled

**Checkpoint**: Accessibility reduced motion is fully respected across viewport and tab indicators.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, MVVM compliance audit, and build verification

- [ ] T011 [P] Ensure 100% US English XML doc comments on all public/internal members in `CachedContentControl.cs`, `SlidingTabIndicatorBehavior.cs`, and `TabMotionConfiguration.cs`
- [ ] T012 Verify Clean MVVM compliance: ensure `ShellWindow.xaml.cs` and `DatabasePage.xaml.cs` contain 0 lines of DOM/visual tree manipulation
- [ ] T013 Run full compilation verification with `dotnet build DataSphere\DataSphere.csproj -c Debug` ensuring 0 warnings and 0 errors

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: Can start immediately.
- **Phase 2 (Foundational)**: Depends on Phase 1 completion.
- **Phase 3 (User Story 1 - MVP)**: Depends on Phase 2 completion.
- **Phase 4 (User Story 2)**: Depends on Phase 2 completion (can run sequentially after US1).
- **Phase 5 (User Story 3)**: Depends on Phase 3 and Phase 4 completion.
- **Phase 6 (Polish)**: Depends on all user stories being complete.

---

## Implementation Strategy

1. **MVP First**: Complete Phase 1, Phase 2, and Phase 3 (Viewport transitions in `CachedContentControl`). Validate independently.
2. **Tab Header Motion**: Add Phase 4 (`SlidingTabIndicatorBehavior`).
3. **Accessibility Integration**: Complete Phase 5 (Reduced Motion fallback).
4. **Final Gate**: Complete Phase 6 (Doc comments, Clean MVVM audit, and zero-error build).
