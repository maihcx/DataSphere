# Tasks: Surface & Tab Selected Theme Brush Contrast Enhancement

**Input**: Design documents from `/specs/015-surface-brush-contrast/`
**Prerequisites**: [plan.md](./plan.md) (required), [spec.md](./spec.md) (required for user stories), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/xaml-brush-contract.md](./contracts/xaml-brush-contract.md), [quickstart.md](./quickstart.md)

## Organization: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `- [ ] [TaskID] [P?] [Story?] Description with file path`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., [US1], [US2], [US3])
- Strict checklist format with exact file paths in descriptions

---

## Phase 1: Setup & Foundational

**Purpose**: Confirm target surface baseline across project themes

- [ ] T001 Audit and catalog all occurrences of `LayerFillColorDefaultBrush` across XAML views in `DataSphere/Themes/TabStyles.xaml`, `DataSphere/Views/Pages/DatabaseGroup/`, and `DataSphere/Controls/VirtualTable/`

---

## Phase 2: User Story 1 - Elevated Contrast for Selected Tab Pills (Priority: P1) 🎯 MVP

**Goal**: Elevate contrast and depth of active tab pills in Dark theme by binding `PillBorder.Background` in selected states to `CardBackgroundFillColorDefaultBrush`.

**Independent Test**: Launch the application in Dark theme, select any tab (Home or Database), and verify that the selected tab pill background displays a distinct, solid elevated card fill with crisp border outline instead of a faint 5% wash.

### Implementation for User Story 1

- [ ] T002 [US1] Update `PillBorder.Background` in `Selected` visual state from `LayerFillColorDefaultBrush` to `{ThemeResource CardBackgroundFillColorDefaultBrush}` in `DataSphere/Themes/TabStyles.xaml`
- [ ] T003 [US1] Update `PillBorder.Background` in `PointerOverSelected` and `PressedSelected` visual states to `{ThemeResource CardBackgroundFillColorDefaultBrush}` in `DataSphere/Themes/TabStyles.xaml`

**Checkpoint**: Tab pills in `PillTabViewItemStyle` now render with high-contrast card backgrounds when selected in both Dark and Light themes.

---

## Phase 3: User Story 2 - Elevated Contrast for Workspace & Data Grid Surfaces (Priority: P2)

**Goal**: Replace faint layer fills in workspace containers with elevated card surfaces matching the visual language of `HomePage`.

**Independent Test**: Navigate to `DatabasePage` in Dark theme, open `ConnectViewControl`, `DatabaseViewControl`, and inspect `VirtualTable` canvas; verify that all content surfaces have rich, elevated card backgrounds with zero transparent washout.

### Implementation for User Story 2

- [ ] T004 [P] [US2] Update Row 1 inner workspace Grid background from `LayerFillColorDefaultBrush` to `{ThemeResource CardBackgroundFillColorDefaultBrush}` in `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml`
- [ ] T005 [P] [US2] Update root Grid background from `LayerFillColorDefaultBrush` to `{ThemeResource CardBackgroundFillColorDefaultBrush}` in `DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml`
- [ ] T006 [P] [US2] Update root Grid background from `LayerFillColorDefaultBrush` to `{ThemeResource CardBackgroundFillColorDefaultBrush}` in `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml`
- [ ] T007 [P] [US2] Update root Grid background from `LayerFillColorDefaultBrush` to `{ThemeResource CardBackgroundFillColorDefaultBrush}` in `DataSphere/Controls/VirtualTable/VirtualTable.xaml`

**Checkpoint**: All workspace panels and data grid backgrounds consistently render with `CardBackgroundFillColorDefaultBrush`.

---

## Phase 4: User Story 3 - Theme Synchronization & Dynamic Switching (Priority: P3)

**Goal**: Verify declarative `{ThemeResource}` bindings across all updated views to ensure zero code-behind logic and instant runtime theme switching without application restart.

**Independent Test**: Switch theme between Light and Dark in Settings, return to `DatabasePage`, and verify all surfaces immediately transition without delay or visual artifacts.

### Implementation for User Story 3

- [ ] T008 [US3] Verify declarative `{ThemeResource}` markup across all 5 target files to confirm strict MVVM compliance and seamless runtime theme synchronization

**Checkpoint**: Instant theme switching works flawlessly across all updated surfaces.

---

## Phase 5: Polish & Verification

**Purpose**: Build validation, live desktop UI automation, and constitutional compliance verification

- [ ] T009 Verify zero-error compilation with `dotnet build DataSphere/DataSphere.csproj -c Debug`
- [ ] T010 Create and execute live desktop UI automation script `scripts/verify-brush-contrast.ps1` on `WinSta0\default` to verify high-contrast card fills in Dark theme and capture DirectComposition screenshots into artifact directory
- [ ] T011 Execute interactive validation scenarios defined in `specs/015-surface-brush-contrast/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup & Foundational (Phase 1)**: Can start immediately.
- **User Story 1 (Phase 2 - P1 MVP)**: Depends on Phase 1 completion. Updates tab styling.
- **User Story 2 (Phase 3 - P2)**: Depends on Phase 1 completion. Can execute in parallel with US1 on different files.
- **User Story 3 (Phase 4 - P3)**: Depends on Phase 2 and Phase 3 completion. Validates theme switching.
- **Polish & Verification (Phase 5)**: Depends on all implementation tasks being complete.

### Parallel Opportunities

- Within Phase 3: `T004`, `T005`, `T006`, and `T007` touch different XAML files and can run concurrently.
- `T010` (Automation verification script) can be authored while implementation is underway.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: `T001` (Audit baseline).
2. Complete Phase 2: `T002`, `T003` (`TabStyles.xaml` selected tab pills).
3. **STOP and VALIDATE**: Confirm selected tab pills display crisp card background in Dark mode.

### Incremental Delivery

1. Phase 1 + 2: Tab pill selected contrast resolved (MVP).
2. Phase 3: Workspace containers updated to card fill.
3. Phase 4: Theme switching validated.
4. Phase 5: Full verification, desktop UI automation, and DirectComposition artifact captures.
