# Tasks: User Preferences & State Persistence (UserDataStore Integration)

**Input**: Design documents from `/specs/003-user-data-store-persistence/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/user-data-store-contract.md](contracts/user-data-store-contract.md), [quickstart.md](quickstart.md)

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify and prepare preferences infrastructure and base storage directories

- [x] T001 Verify and inspect UserDataStore synchronization primitives, default keys, and `%LOCALAPPDATA%\DataSphere\userdata.json` path in `DataSphere/Utils/UserDataStore.cs`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core contracts and models that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: Foundational tasks must complete before user story implementation begins

- [x] T002 [P] Implement `IThemeService` interface contract in `DataSphere/Services/Contracts/IThemeService.cs` with 100% US English XML doc comments
- [x] T003 [P] Implement `WindowPlacementState` model with validation constraints (min width 800.0, min height 500.0) in `DataSphere/Models/WindowPlacementState.cs`

**Checkpoint**: Base contracts and data structures ready — user story implementation can proceed.

---

## Phase 3: User Story 1 - Application Theme & Visual Personalization Persistence (Priority: P1) 🎯 MVP

**Goal**: Persist `"IThemeType"` ("Light", "Dark", "Default") in UserDataStore, apply live across open windows via `IThemeService`, and restore on startup.

**Independent Test**: Change Theme to "Dark" in Settings. Verify that windows update in real-time. Close and reopen the app; confirm all windows render in Dark theme on launch.

- [x] T004 [US1] Implement `ThemeService` in `DataSphere/Services/ThemeService.cs` implementing `IThemeService`, applying `ElementTheme` to `WindowEx.Content` and updating `UserDataStore`
- [x] T005 [P] [US1] Register `IThemeService` as Singleton in `DataSphere/App.xaml.cs`
- [x] T006 [US1] Inject `IThemeService` into `SettingsViewModel` in `DataSphere/ViewModels/PagesBottom/SettingsViewModel.cs` and wire `OnSelectedThemeChanged` to notify `IThemeService.SetTheme(value.Value)`
- [x] T007 [US1] Wire `IThemeService.Initialize()` and apply theme to `ShellWindow` during startup in `DataSphere/Services/ApplicationHostService.cs`

**Checkpoint**: User Story 1 (MVP) complete and independently testable.

---

## Phase 4: User Story 2 - Display Language Preference Persistence & Startup Restoration (Priority: P1)

**Goal**: Restore saved `"Language"` preference ("en", "vi") from `UserDataStore` during startup in `ApplicationHostService` before UI renders, falling back to `CultureInfo.CurrentUICulture` or English if missing.

**Independent Test**: Switch language to "Tiếng Việt" in Settings. Restart app. Verify that initial tab headers and dashboard cards render in Vietnamese on the very first frame.

- [x] T008 [US2] Update `LanguageBase.GetSetupLanguage()` in `DataSphere/Utils/Translations.cs` to safely validate stored culture code against `SupportedLanguages` with fallback to `CultureInfo.CurrentUICulture`
- [x] T009 [US2] Initialize `TranslationSource.Instance.CurrentCulture = LanguageBase.GetSetupLanguage()` in `DataSphere/Services/ApplicationHostService.cs` prior to `ShellWindow` instantiation

**Checkpoint**: User Story 2 complete and independently testable.

---

## Phase 5: User Story 3 - Window Placement, Dimensions & Maximized State Persistence (Priority: P1)

**Goal**: Save and restore primary shell window coordinates (`Window_Left`, `Window_Top`), dimensions (`Window_Width`, `Window_Height`), and state (`IsWindow_Maximized`) with multi-monitor boundary validation.

**Independent Test**: Resize window to custom dimensions (e.g., 1400x900) or maximize it, close the app, and reopen; verify window restores to identical geometry and state.

- [x] T010 [US3] Implement `WindowPlacementHelper` in `DataSphere/Utils/WindowPlacementHelper.cs` to save and restore `AppWindow.Position`, `AppWindow.Size`, and `OverlappedPresenter.State` with multi-monitor boundary clamping
- [x] T011 [US3] Wire window placement restoration into `ShellWindow` constructor and activation in `DataSphere/Views/Windows/ShellWindow.xaml.cs`
- [x] T012 [US3] Wire `WindowPlacementHelper.SavePlacement(this)` in `DataSphere/Views/Windows/ShellWindow.xaml.cs` during `Closed` or `AppWindow.Closing` lifecycle events

**Checkpoint**: User Story 3 complete and independently testable.

---

## Phase 6: User Story 4 - Robust Preferences Storage & Fault Tolerance (Priority: P2)

**Goal**: Guarantee thread safety with synchronization locks (`_syncLock`), automatic directory creation, silent recovery on corrupt JSON, and transparent credential encryption with `PasswordEncryptor`.

**Independent Test**: Corrupt or delete `userdata.json`. Launch DataSphere; verify zero crashes, automatic dictionary re-initialization, and fallback defaults.

- [x] T013 [US4] Add thread synchronization locks (`_syncLock`) and corrupt JSON deserialization try-catch fallback handling in `DataSphere/Utils/UserDataStore.cs`
- [x] T014 [P] [US4] Harden `UserDataStore.GetValuePass` and `UserDataStore.SetValuePass` in `DataSphere/Utils/UserDataStore.cs` with validation against corrupted ciphertext and empty inputs

**Checkpoint**: User Story 4 complete and storage layer resilient to errors.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Quality assurance, constitutional compliance, and end-to-end verification

- [x] T015 [P] Audit all new and modified classes, interfaces, and methods for 100% US English XML doc comments per Constitution Principle V
- [x] T016 [P] Verify zero hardcoded user-facing strings across all modified ViewModels and Views per Constitution Principle VII
- [x] T017 Build solution using `dotnet build DataSphere\DataSphere.csproj -c Debug` ensuring 0 compilation errors and 0 warnings
- [x] T018 Run manual/headless verification following scenarios defined in `specs/003-user-data-store-persistence/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Independent — can start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS User Stories.
- **User Story 1 (Phase 3 - US1)**: Depends on Foundational completion.
- **User Story 2 (Phase 4 - US2)**: Depends on Foundational completion (independent of US1).
- **User Story 3 (Phase 5 - US3)**: Depends on Foundational completion (independent of US1 & US2).
- **User Story 4 (Phase 6 - US4)**: Depends on Foundational completion (reinforces storage for all stories).
- **Polish (Phase 7)**: Depends on all user stories completion.

### User Story Dependencies

- **User Story 1 (P1)**: Independent increment.
- **User Story 2 (P1)**: Independent increment; shares startup lifecycle in `ApplicationHostService.cs`.
- **User Story 3 (P1)**: Independent increment; operates on `ShellWindow.xaml.cs`.
- **User Story 4 (P2)**: Hardens `UserDataStore.cs` used by US1, US2, and US3.

### Parallel Opportunities

- `T002` and `T003` in Phase 2 can run in parallel.
- `T005` can run in parallel with `T004`.
- `T014` can run in parallel with `T013`.
- `T015` and `T016` in Phase 7 can run in parallel.

---

## Parallel Example: User Story 1

```bash
# Implement Theme contract and models in parallel:
Task: "Implement IThemeService interface contract in DataSphere/Services/Contracts/IThemeService.cs"
Task: "Register IThemeService as Singleton in DataSphere/App.xaml.cs"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)
1. Complete Phase 1: Setup (`T001`).
2. Complete Phase 2: Foundational (`T002`, `T003`).
3. Complete Phase 3: User Story 1 (`T004` - `T007`).
4. **STOP and VALIDATE**: Verify theme switching and persistence across app restarts.

### Incremental Delivery
1. Phase 1 + Phase 2 &rarr; Foundation ready.
2. User Story 1 &rarr; Theme persistence verified (MVP).
3. User Story 2 &rarr; Language startup restored.
4. User Story 3 &rarr; Window placement remembered.
5. User Story 4 &rarr; Storage fault tolerance hardened.
6. Polish &rarr; Build 0 error, 100% US English docs, zero hardcoded strings.
