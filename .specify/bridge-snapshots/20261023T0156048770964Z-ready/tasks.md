# Tasks: Tab Sleeping & Memory Saver

**Input**: Design documents from `specs/016-tab-sleeping-memory-saver/`  
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/tab-memory-saver-contract.md`, `quickstart.md`

## Format: `[ID] [P?] [Story?] Description with file path`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Localization strings and baseline enum declarations

- [ ] T001 Register localization resource keys in `DataSphere/Resources/Locales/String.resx`, `DataSphere/Resources/Locales/String.en.resx`, and `DataSphere/Resources/Locales/String.vi.resx` for Memory Saver settings (card title, description, toggle label, timeout options, sleeping tab tooltip) in strict UTF-8 without BOM
- [ ] T002 Add `Sleeping` enum value with XML doc comments to `DataSphere/Models/TabLifecycleState.cs`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core interfaces, models, and service registrations required by all user stories

- [ ] T003 [P] Define `ISleepableTabContent` interface in `DataSphere/Services/Contracts/ISleepableTabContent.cs` with `CanSleep`, `Sleep()`, and `WakeUp()` methods
- [ ] T004 [P] Define `TabSleepTimeoutOption` model in `DataSphere/Models/Settings/TabSleepTimeoutOption.cs`
- [ ] T005 Augment `TabItemModel` in `DataSphere/Models/TabItemModel.cs` with `LastActiveTime`, `IsSleeping`, `HasUnsavedChanges`, and `CanSleep` properties
- [ ] T006 Define `ITabMemorySaverService` in `DataSphere/Services/Contracts/ITabMemorySaverService.cs`
- [ ] T007 Register `ITabMemorySaverService` and `TabMemorySaverService` in the dependency injection container in `DataSphere/App.xaml.cs`

**Checkpoint**: Foundation ready - user story implementation can proceed.

---

## Phase 3: User Story 1 - Instant Responsive Tab Switching (Priority: P1) 🎯 MVP

**Goal**: Keep inactive tabs alive in active memory during normal multi-tab switching, achieving <16ms frame time with zero reload latency, preserved row selection, and exact scroll offsets.

**Independent Test**: Open a database table, scroll down, switch to Home/Settings, return to Database tab, and verify immediate 0ms reactivation without blank frames or row rebuild lag.

- [ ] T008 [US1] Update `DataSphere/Services/TabService.cs` to refresh `LastActiveTime` when switching tabs without clearing visual state on background transition
- [ ] T009 [US1] Ensure `DataSphere/ViewModels/Windows/ShellViewModel.cs` binds active tab selection to keep hot background tabs intact in memory
- [ ] T010 [US1] Validate US1 end-to-end on real desktop (`WinSta0\default`) using automated UI script in `scripts/reproduce-tab-switch-freeze.ps1`

**Checkpoint**: At this point, User Story 1 (MVP) is fully functional and delivers 0ms responsive tab switching.

---

## Phase 4: User Story 2 - User-Configurable Memory Saver Settings (Priority: P2)

**Goal**: Provide a Fluent Design 2 card section in Settings allowing users to toggle tab memory saving on/off and select idle timeout duration (5m, 15m, 30m, 1h), persisted across restarts.

**Independent Test**: Navigate to Settings, toggle switch, change timeout, restart application, and verify persistent state.

- [ ] T011 [P] [US2] Add `EnableTabMemorySaver` and `TabSleepTimeoutMinutes` properties with local persistence to `DataSphere/ViewModels/PagesBottom/SettingsViewModel.cs`
- [ ] T012 [P] [US2] Implement `TabSleepTimeoutOption` list generation in `DataSphere/ViewModels/PagesBottom/SettingsViewModel.cs` supporting dynamic language changes via `TranslationSource`
- [ ] T013 [US2] Add Performance & Memory section with `ToggleSwitch` and `ComboBox` to `DataSphere/Views/PagesBottom/SettingsPage.xaml` using Fluent Design 2 card layout
- [ ] T014 [US2] Bind Settings ViewModel properties to update `ITabMemorySaverService` policy dynamically upon user change

**Checkpoint**: User Stories 1 and 2 are functional; user settings persist and dynamically control policy.

---

## Phase 5: User Story 3 - Automated Background Tab Sleeping & Wakeup (Priority: P3)

**Goal**: Periodically detect idle background tabs exceeding timeout and transition them into sleeping state, releasing pooled UI elements while retaining query context; wake up smoothly on focus.

**Independent Test**: Leave a database tab idle beyond the configured timeout, verify sleeping badge appears on tab header and memory is released, then click tab and verify smooth wakeup.

- [ ] T015 [US3] Implement `ISleepableTabContent` in `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs` to suspend pooled visual canvas rows on `Sleep()` and trigger `TableControl?.Refresh()` on `WakeUp()`
- [ ] T016 [US3] Implement `TabMemorySaverService` in `DataSphere/Services/TabMemorySaverService.cs` with a 60-second `DispatcherTimer` evaluating tab idle duration against active policy
- [ ] T017 [US3] Wire wakeup trigger in `DataSphere/Services/TabService.cs` when a sleeping tab is selected
- [ ] T018 [US3] Add sleeping visual indicator badge (glyph `\uEC46` / muted opacity) to `TabViewItem` template in `DataSphere/Views/Windows/ShellWindow.xaml`

**Checkpoint**: All three primary user stories are complete and integrated.

---

## Phase 6: User Story 4 - Clean Terminal Disposal on Tab Closure (Priority: P4)

**Goal**: Ensure closing a tab via the `X` button completely disposes all underlying ViewModels, connections, and visual row pools to prevent memory leaks.

**Independent Test**: Open and close 10 database tabs sequentially and verify process working set returns to baseline.

- [ ] T019 [US4] Update tab close handling in `DataSphere/Services/TabService.cs` and `DataSphere/ViewModels/Windows/ShellViewModel.cs` to invoke `IDisposable.Dispose()` on closed tab contents
- [ ] T020 [US4] Verify deterministic cleanup of database sessions and UI elements when closing tabs

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation compliance, code quality checks, and real-desktop validation

- [ ] T021 [P] Verify 100% US English XML doc comments across all newly added and modified types/methods in `DataSphere/Services/`, `DataSphere/Models/`, `DataSphere/ViewModels/`
- [ ] T022 [P] Verify UTF-8 without BOM encoding on `DataSphere/Resources/Locales/String.*.resx` files
- [ ] T023 Execute full solution build `dotnet build DataSphere\DataSphere.csproj -c Debug` verifying 0 warnings and 0 errors
- [ ] T024 Execute automated UI verification test on real desktop (`WinSta0\default`) validating end-to-end lifecycle per `quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories.
- **User Story 1 (Phase 3)**: Depends on Phase 2 — Deliverable MVP.
- **User Story 2 (Phase 4)**: Depends on Phase 2 — Can run in parallel with US1 or sequentially.
- **User Story 3 (Phase 5)**: Depends on US1 (Phase 3) and US2 (Phase 4).
- **User Story 4 (Phase 6)**: Depends on Phase 2.
- **Polish (Phase 7)**: Depends on all user stories being complete.

---

## Parallel Opportunities

- T003 (`ISleepableTabContent`) and T004 (`TabSleepTimeoutOption`) can be developed in parallel.
- T011 (SettingsViewModel properties) and T012 (Timeout options) can be developed in parallel.
- T021 (Doc comments) and T022 (Resource encoding check) can run in parallel during polish.
