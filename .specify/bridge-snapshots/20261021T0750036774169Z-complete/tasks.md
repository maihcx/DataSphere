# Tasks: Fluent Settings Redesign, System Backdrops & Native WinUI 3 Theme Architecture

**Input**: Design documents from `specs/010-fluent-settings-and-system-backdrops/` (`spec.md`, `plan.md`, `data-model.md`, `contracts/settings-backdrop-contracts.md`, `research.md`, `quickstart.md`)

**Prerequisites**: `plan.md`, `spec.md`, `data-model.md`, `contracts/settings-backdrop-contracts.md`

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (`[US1]`, `[US2]`, `[US3]`)
- Every task includes exact file paths

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, entity models, and localization resources

- [x] T001 [P] Create `BackdropOptionItem` entity in `DataSphere/Models/BackdropOptionItem.cs` containing `Key` ("Mica", "Tabbed", "Acrylic", "Solid"), `Content`, `Summary`, and `IconGlyph` with US English XML doc comments
- [x] T002 [P] Add backdrop and layout localization entries (`page_settings_backdrop_title`, `page_settings_backdrop_summary`, `backdrop_tabbed`, `backdrop_mica`, `backdrop_acrylic`, `backdrop_solid`) to `DataSphere/Resources/Locales/String.resx`, `DataSphere/Resources/Locales/String.en.resx`, and `DataSphere/Resources/Locales/String.vi.resx` strictly in UTF-8 without BOM

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core theme service and backdrop contracts that MUST be complete before user story implementation

**⚠️ CRITICAL**: Must complete before User Story 2 or 3 implementation

- [x] T003 Extend `IThemeService` interface in `DataSphere/Services/Contracts/IThemeService.cs` with `CurrentBackdrop`, `BackdropChanged` event, and `SetBackdrop(string backdrop)` method
- [x] T004 Implement system backdrop management in `DataSphere/Services/ThemeService.cs` reading and writing `ISystemBackdropType` from `UserDataStore`, broadcasting `BackdropChanged`, and defaulting to `"Tabbed"`

**Checkpoint**: Foundation ready — User Story 1 (Layout) and User Story 2 (Backdrops) can now proceed

---

## Phase 3: User Story 1 - Clean & Responsive Settings Page Layout (Priority: P1) 🎯 MVP

**Goal**: Deliver a cleanly structured, balanced, and responsive Settings page that centers content symmetrically without rightward drift, and ensures ComboBoxes never truncate text.

**Independent Test**: Navigate to the Settings tab in any window resolution (800px to maximized); verify cards are centered with balanced margins, no empty 300px left gap exists, and ComboBoxes show full titles.

### Implementation for User Story 1

- [x] T005 [US1] Redesign root layout in `DataSphere/Views/PagesBottom/SettingsPage.xaml` using `<Grid HorizontalAlignment="Stretch" VerticalAlignment="Stretch">`, `<ScrollViewer HorizontalAlignment="Stretch" HorizontalScrollBarVisibility="Disabled" VerticalScrollBarVisibility="Auto">`, and child `<StackPanel HorizontalAlignment="Center" MaxWidth="900" Padding="24,24,24,32" Spacing="16">` to eliminate the 300px rightward drift bug
- [x] T006 [US1] Update Theme and Language card ComboBoxes in `DataSphere/Views/PagesBottom/SettingsPage.xaml` with `MinWidth="200"`, `HorizontalAlignment="Right"`, and refined card padding (`16,14`) to prevent text clipping and ellipsis truncation

**Checkpoint**: User Story 1 is fully functional and independently verifiable (MVP achieved).

---

## Phase 4: User Story 2 - Dynamic System Backdrops (Mica, Tabbed, Acrylic, Solid) (Priority: P1)

**Goal**: Enable dynamic toggling between Windows 11 Mica (Base), Tabbed (Mica Alt), Desktop Acrylic, and Solid fallback, with immediate visual application and persistent storage across app restarts.

**Independent Test**: In Settings -> Hiệu ứng nền, select "Mica", "Tabbed", "Acrylic", and "Mặc định (Solid)". Verify window surface updates immediately (<100ms) and preference persists on application relaunch.

### Implementation for User Story 2

- [x] T007 [US2] Implement `BackdropList` collection and `SelectedBackdrop` property in `DataSphere/ViewModels/PagesBottom/SettingsViewModel.cs` wired to `IThemeService` and synchronized with localized `BackdropOptionItem` entries
- [x] T008 [US2] Add Backdrop selection card to `DataSphere/Views/PagesBottom/SettingsPage.xaml` under the Personalization section with icon, title, description, and ComboBox bound to `ViewModel.BackdropList` and `ViewModel.SelectedBackdrop`
- [x] T009 [US2] Wire dynamic `SystemBackdrop` application in `DataSphere/Views/Windows/ShellWindow.xaml.cs` to apply `MicaBackdrop` (`Base` or `BaseAlt`), `DesktopAcrylicBackdrop`, or `null` based on `IThemeService.CurrentBackdrop` on window load and upon `IThemeService.BackdropChanged` events

**Checkpoint**: User Stories 1 and 2 are fully integrated and functional.

---

## Phase 5: User Story 3 - Uniform System Theme Color Architecture (Zero Custom Styles) (Priority: P2)

**Goal**: Eradicate all hardcoded background colors and styles, allowing system backdrops to illuminate through the window and tab surfaces while maintaining contrast across Light and Dark themes.

**Independent Test**: Switch between Light and Dark themes across all backdrops; verify `WindowRoot` transparency allows backdrops to show through titlebar and viewports, with cards using `CardBackgroundFillColorDefaultBrush`.

### Implementation for User Story 3

- [x] T010 [US3] Configure `WindowRoot` background transparency when a backdrop is active in `DataSphere/Views/Windows/ShellWindow.xaml` and `DataSphere/Views/Windows/ShellWindow.xaml.cs`
- [x] T011 [US3] Audit and replace all residual static color brushes and custom borders in `DataSphere/Views/PagesBottom/SettingsPage.xaml` and `DataSphere/Views/Windows/ShellWindow.xaml` with native `{ThemeResource ...}` design tokens (`CardBackgroundFillColorDefaultBrush`, `CardStrokeColorDefaultBrush`, `TextFillColorPrimaryBrush`, `TextFillColorSecondaryBrush`)

**Checkpoint**: All three user stories are complete and visually unified.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Build verification, code documentation standards, and automated desktop testing

- [x] T012 Compile project with `dotnet build DataSphere/DataSphere.csproj -c Debug` and verify 0 errors, 0 warnings, and 100% US English XML doc comments
- [x] T013 Create automated desktop UI verification script in `scripts/verify-fluent-settings-and-backdrops.ps1` adhering to Constitution Principle VIII (`WinSta0\default`, physical clicks, zero AutomationId, DirectComposition screenshots)
- [x] T014 Execute live verification on `WinSta0\default` via `scripts/verify-fluent-settings-and-backdrops.ps1` and capture `winui_settings_fluent_layout.png`, `winui_backdrop_tabbed.png`, `winui_backdrop_acrylic.png`, and `winui_backdrop_solid.png` into the artifact directory

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can execute immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 (`BackdropOptionItem` and `.resx` entries).
- **User Story 1 (Phase 3)**: Independent UI fix — can start immediately or after Phase 1.
- **User Story 2 (Phase 4)**: Depends on Phase 2 (`IThemeService` backdrop extension).
- **User Story 3 (Phase 5)**: Depends on Phase 4 (Backdrop dynamic wiring).
- **Polish (Phase 6)**: Depends on all user stories being implemented.

### Parallel Opportunities

- **T001** and **T002** can be executed in parallel (different files).
- **T005** and **T006** can be combined or executed in parallel with foundational service work.
- **T010** and **T011** can be executed in parallel.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete T005 & T006 (Settings page layout overhaul).
2. Validate that the Settings page is centered symmetrically with zero text clipping.

### Incremental Delivery

1. Setup + Foundational (T001–T004) → Core backdrop service ready.
2. User Story 1 (T005–T006) → Settings layout centered & balanced (MVP).
3. User Story 2 (T007–T009) → Dynamic system backdrops operational across windows.
4. User Story 3 (T010–T011) → ThemeResource tokens unified, zero hardcoded styles.
5. Polish & Verification (T012–T014) → Build clean, live desktop UI automation pass with screenshots.
