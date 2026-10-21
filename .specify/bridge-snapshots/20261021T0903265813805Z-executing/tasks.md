# Tasks: Dedicated ComboBox Models and Dynamic i18n Theme Architecture

**Input**: Design documents from `specs/011-combobox-models-theme-i18n/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/combobox-contracts.md`, `quickstart.md`

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Resource preparation and localization bundle verification

- [ ] T001 Review and verify theme and backdrop localization keys in `DataSphere/Resources/Locales/String.resx`, `DataSphere/Resources/Locales/String.en.resx`, and `DataSphere/Resources/Locales/String.vi.resx` (UTF-8 without BOM)

---

## Phase 2: Foundational (Domain Enums & Observable Models)

**Purpose**: Core domain types and observable models that all user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T002 [P] Create domain enum `AppThemeMode` with US English XML docs in `DataSphere/Models/AppThemeMode.cs`
- [ ] T003 [P] Create domain enum `AppBackdropMode` with US English XML docs in `DataSphere/Models/AppBackdropMode.cs`
- [ ] T004 [P] Implement observable model `ThemeOptionItem` with `[ObservableProperty]` and XML docs in `DataSphere/Models/ThemeOptionItem.cs`
- [ ] T005 [P] Refactor observable model `BackdropOptionItem` to use `AppBackdropMode`, `[ObservableProperty]` for `DisplayName`/`Summary`, and XML docs in `DataSphere/Models/BackdropOptionItem.cs`
- [ ] T006 [P] Implement observable model `LanguageOptionItem` with `[ObservableProperty]` and XML docs in `DataSphere/Models/LanguageOptionItem.cs`

**Checkpoint**: Core domain models and enums ready — user story implementation can begin

---

## Phase 3: User Story 1 - Type-Safe Theme Selection with In-Place i18n Refresh (Priority: P1) 🎯 MVP

**Goal**: Deliver type-safe Theme selection dropdown using `ThemeOptionItem` and `AppThemeMode`, with in-place reactive text updates on language switch without collection re-allocation or selection flicker.

**Independent Test**: Open Settings page, switch themes between Light, Dark, and Default to confirm immediate visual update, then change language to verify item labels update in-place while keeping the selected theme intact.

### Implementation for User Story 1

- [ ] T007 [US1] Update `IThemeService` interface in `DataSphere/Services/Contracts/IThemeService.cs` to support `AppThemeMode` and typed event `ThemeChanged`
- [ ] T008 [US1] Update `ThemeService` implementation in `DataSphere/Services/ThemeService.cs` to handle `AppThemeMode` and backward-compatible mapping to `UserDataStore`
- [ ] T009 [US1] Refactor `SettingsViewModel` in `DataSphere/ViewModels/PagesBottom/SettingsViewModel.cs` to expose `ObservableCollection<ThemeOptionItem> ThemeList` and `ThemeOptionItem? SelectedTheme`
- [ ] T010 [US1] Implement in-place mutation in `SettingsViewModel.UpdateLocalizedStrings()` for `ThemeList` on `TranslationSource.Instance.PropertyChanged`, preserving the selected instance
- [ ] T011 [US1] Update `DataSphere/Views/PagesBottom/SettingsPage.xaml` Theme ComboBox to bind `SelectedItem="{x:Bind ViewModel.SelectedTheme, Mode=TwoWay}"`, `ItemsSource="{x:Bind ViewModel.ThemeList, Mode=OneWay}"`, and `DisplayMemberPath="DisplayName"`

**Checkpoint**: User Story 1 fully functional and testable independently as the MVP

---

## Phase 4: User Story 2 - Type-Safe System Backdrop Selection with Dynamic Descriptions (Priority: P2)

**Goal**: Deliver type-safe System Backdrop selection dropdown using `BackdropOptionItem` and `AppBackdropMode`, with in-place reactive text and subtitle updates on language switch.

**Independent Test**: Open Settings page, verify 4 backdrop items (Mica, Tabbed, Acrylic, Solid) with icons and subtitles, select each backdrop to verify material application, and switch language to confirm in-place updates.

### Implementation for User Story 2

- [ ] T012 [US2] Update `IThemeService` and `ThemeService` in `DataSphere/Services/Contracts/IThemeService.cs` and `DataSphere/Services/ThemeService.cs` to support `AppBackdropMode` and typed event `BackdropChanged`
- [ ] T013 [US2] Refactor `SettingsViewModel` in `DataSphere/ViewModels/PagesBottom/SettingsViewModel.cs` to expose `ObservableCollection<BackdropOptionItem> BackdropList` and `BackdropOptionItem? SelectedBackdrop`
- [ ] T014 [US2] Implement in-place mutation in `SettingsViewModel.UpdateLocalizedStrings()` for `BackdropList` on `TranslationSource.Instance.PropertyChanged`
- [ ] T015 [US2] Update `DataSphere/Views/PagesBottom/SettingsPage.xaml` Backdrop ComboBox to bind `SelectedItem="{x:Bind ViewModel.SelectedBackdrop, Mode=TwoWay}"`, `ItemsSource="{x:Bind ViewModel.BackdropList, Mode=OneWay}"`, and `DisplayMemberPath="DisplayName"`

**Checkpoint**: User Stories 1 and 2 both work seamlessly with typed models and reactive localization

---

## Phase 5: User Story 3 - Unified Reactive ComboBox Option Models for Language and App Settings (Priority: P3)

**Goal**: Unify Language ComboBox modeling with `LanguageOptionItem` and ensure consistent option item contracts across application settings.

**Independent Test**: Open Settings page, switch language via Language ComboBox, and verify that all three ComboBoxes (Theme, Backdrop, Language) update reactively without collection recreation or focus loss.

### Implementation for User Story 3

- [ ] T016 [US3] Refactor `SettingsViewModel` in `DataSphere/ViewModels/PagesBottom/SettingsViewModel.cs` to expose `ObservableCollection<LanguageOptionItem> Languages` and `LanguageOptionItem? SelectedLanguage`
- [ ] T017 [US3] Update `DataSphere/Views/PagesBottom/SettingsPage.xaml` Language ComboBox to bind `SelectedItem="{x:Bind ViewModel.SelectedLanguage, Mode=TwoWay}"`, `ItemsSource="{x:Bind ViewModel.Languages, Mode=OneWay}"`, and `DisplayMemberPath="NativeName"`

**Checkpoint**: All three ComboBoxes in Settings use unified, dedicated observable models

---

## Phase 6: Polish & Verification Gate

**Purpose**: Quality gate verification, zero-error compilation, XML doc verification, and live desktop UI testing

- [ ] T018 Verify clean project compilation with `dotnet build DataSphere\DataSphere.csproj -c Debug` (0 warnings, 0 errors)
- [ ] T019 [P] Verify 100% US English XML doc comments on all new and modified symbols per Principle V
- [ ] T020 Execute live UI automation verification test on `WinSta0\default` with DirectComposition capture per Principle VIII using `scripts/verify-fluent-settings-and-backdrops.ps1`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 completion — BLOCKS all user stories.
- **User Story 1 (Phase 3)**: Depends on Phase 2 completion — MVP slice.
- **User Story 2 (Phase 4)**: Depends on Phase 2 & Phase 3 completion.
- **User Story 3 (Phase 5)**: Depends on Phase 2 & Phase 3 completion.
- **Polish & Verification (Phase 6)**: Depends on all user stories being complete.

### Parallel Opportunities

- In Phase 2: T002, T003, T004, T005, and T006 can all be implemented in parallel (independent model files).
- In Phase 6: T019 can run in parallel with compilation and testing.

---

## Parallel Example: Foundational Models (Phase 2)

```bash
# Launch creation of independent domain enums and models together:
Task: "Create domain enum AppThemeMode with US English XML docs in DataSphere/Models/AppThemeMode.cs"
Task: "Create domain enum AppBackdropMode with US English XML docs in DataSphere/Models/AppBackdropMode.cs"
Task: "Implement observable model ThemeOptionItem with [ObservableProperty] and XML docs in DataSphere/Models/ThemeOptionItem.cs"
Task: "Refactor observable model BackdropOptionItem in DataSphere/Models/BackdropOptionItem.cs"
Task: "Implement observable model LanguageOptionItem in DataSphere/Models/LanguageOptionItem.cs"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (`.resx` key verification).
2. Complete Phase 2: Foundational (`AppThemeMode`, `ThemeOptionItem`).
3. Complete Phase 3: User Story 1 (Theme ComboBox refactored to typed model with in-place i18n).
4. **VALIDATE**: Build and test Theme ComboBox independently.

### Incremental Delivery

1. Complete Setup + Foundational → Domain enums and models ready.
2. Deliver User Story 1 → Type-safe Theme ComboBox with in-place i18n (MVP).
3. Deliver User Story 2 → Type-safe Backdrop ComboBox with in-place i18n.
4. Deliver User Story 3 → Unified Language ComboBox with `LanguageOptionItem`.
5. Execute Verification Gate (Build 0 errors, English XML doc comments, live UI automation).
