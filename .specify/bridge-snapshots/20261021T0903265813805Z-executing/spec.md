# Feature Specification: Dedicated ComboBox Models and Dynamic i18n Theme Architecture

**Feature Branch**: `011-combobox-models-theme-i18n`

**Created**: 2026-10-21

**Status**: Draft

**Input**: User description: "triển khai model cho các combobox và hãy xem theme ở phía: D:\DEV\RustWinUI\Nexa-Optimizer\src\NexaOptimizer.UI ở NexaOptimizer tôi thấy xử lý theme khá là tốt thông qua model riêng cho combobox hỗ trợ i18n rất tốt"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Type-Safe Theme Selection with In-Place i18n Refresh (Priority: P1)

As an application user, I want the Theme selection dropdown in Settings to present crystal-clear, localized choices (Sáng / Tối / Mặc định hệ thống) that update their displayed text immediately when I switch languages, without resetting my active selection, causing visual jitter, or losing focus.

**Why this priority**: Theme switching is one of the most prominent customization features. Having a dedicated, strongly-typed model eliminates fragile string-based lookups, prevents UI desynchronization bugs, and guarantees fluid localization reactivity inspired by the proven architecture in `NexaOptimizer.UI`.

**Independent Test**: Can be verified by opening the Settings page, observing the Theme ComboBox loaded with localized items, switching UI language between English and Vietnamese, and confirming that the ComboBox display names update in-place while keeping the currently selected theme intact.

**Acceptance Scenarios**:

1. **Given** the application is open in Settings with Vietnamese language and "Tối" (Dark) theme selected, **When** the user changes language to English, **Then** the ComboBox item labels change immediately to "Light", "Dark", and "Windows Default" while the selected item remains "Dark" without any collection rebuild or selection flicker.
2. **Given** the application is running, **When** the user selects "Sáng" (Light) or "Tối" (Dark) from the dropdown, **Then** the application shell applies the chosen theme instantly across all visual elements and window titlebar buttons, persisting the choice safely to `userdata.json`.

---

### User Story 2 - Type-Safe System Backdrop Selection with Dynamic Descriptions (Priority: P2)

As an application user, I want the System Backdrop dropdown in Settings to provide rich, localized material options (Mica, Tabbed, Acrylic, Solid) accompanied by dynamic descriptive subtitles that immediately reflect my chosen language.

**Why this priority**: System backdrops provide modern Fluent Design 2 visual materials. Dedicated modeling with typed enums guarantees that each backdrop item carries its localized title, explanatory summary, and Segoe Fluent glyph, maintaining clean MVVM separation.

**Independent Test**: Can be tested by navigating to the System Backdrop card in Settings, verifying all 4 backdrop options, switching backdrops, and confirming dynamic update of localized summary text upon language alteration.

**Acceptance Scenarios**:

1. **Given** the user is viewing the System Backdrop options, **When** the user selects "Mica", "Tabbed", "Acrylic", or "Solid", **Then** the window backdrop updates instantly and the selected backdrop summary reflects the chosen material's characteristics.
2. **Given** a backdrop is selected, **When** the user toggles the application language, **Then** the backdrop option names and summaries refresh in-place without resetting the active selection.

---

### User Story 3 - Unified Reactive ComboBox Option Models for Language and App Settings (Priority: P3)

As a developer maintaining DataSphere, I want a standardized, reusable ComboBox option modeling pattern across the entire application (Settings, Dialogs, Data View) so that all dropdown controls follow Clean MVVM, use type-safe enums, and support seamless dynamic localization (`TranslationSource`) without boilerplate code.

**Why this priority**: Standardizing dropdown models eliminates ad-hoc implementations (`SettingOptionItem`, untyped strings, or manual dictionary maps), reducing defects and establishing Tier-1 enterprise maintainability across the codebase.

**Independent Test**: Can be tested by verifying that ComboBox items in Settings (Theme, Backdrop, Language) all inherit from observable models and bind cleanly via `ItemsSource`, `SelectedItem`, and `DisplayMemberPath`.

**Acceptance Scenarios**:

1. **Given** any dropdown control bound to an `ObservableCollection<T>` of option models, **When** a language change event fires, **Then** the option models update their `DisplayName` properties in-place via property change notifications, eliminating collection reconstruction.
2. **Given** persistent storage loads initial preferences from `userdata.json`, **When** the ViewModel initializes, **Then** options match and bind using typed equality (`Equals`/`GetHashCode`) without string mismatches or case-sensitivity errors.

---

### Edge Cases

- **Language switch while ComboBox dropdown is open**: The popup elements must update their displayed text immediately or gracefully upon reopening without visual corruption or application crash.
- **Corrupted or unknown preference value in `userdata.json`**: If the settings file contains an invalid or obsolete string (e.g. legacy `"Default"` for backdrop), the system must fallback gracefully to safe defaults (`AppBackdropMode.Mica`, `AppThemeMode.Default`) without crashing.
- **Operating system theme change event**: When `AppThemeMode.Default` is active and the Windows OS switches between light and dark modes, the application must detect the change and re-evaluate effective styling dynamically.
- **Rapid successive changes**: Switching themes or languages in quick succession must execute asynchronously without thread contention, UI lockup, or memory leaks.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST define strongly-typed domain enums (`AppThemeMode` with `Default`, `Light`, `Dark`, and `AppBackdropMode` with `Mica`, `Tabbed`, `Acrylic`, `Solid`) decoupled from visual UI framework namespaces, following the architecture pattern proven in `NexaOptimizer.UI`.
- **FR-002**: System MUST implement dedicated, observable ComboBox item models (`ThemeOptionItem`, `BackdropOptionItem`, `LanguageOptionItem`) inheriting from `CommunityToolkit.Mvvm.ComponentModel.ObservableObject`.
- **FR-003**: ComboBox item models MUST expose `[ObservableProperty]` for `DisplayName` and `Description` (or `Summary`), ensuring that changes to these properties raise `PropertyChanged` notifications to update the WinUI 3 UI dynamically.
- **FR-004**: ViewModels hosting ComboBox options MUST listen to `TranslationSource.Instance.PropertyChanged` or language change notifications, updating the `DisplayName` and `Description` of existing model instances in-place rather than clearing and repopulating the collection.
- **FR-005**: ViewModels MUST bind ComboBoxes using type-safe two-way data binding (`SelectedItem="{x:Bind ViewModel.SelectedTheme, Mode=TwoWay}"`, `ItemsSource="{x:Bind ViewModel.ThemeList, Mode=OneWay}"`, `DisplayMemberPath="DisplayName"`).
- **FR-006**: System MUST provide bidirectional converters/mappers between domain enums (`AppThemeMode`, `AppBackdropMode`) and configuration storage strings (`UserDataStore`), ensuring backward compatibility with existing user configuration files.
- **FR-007**: `ThemeService` and `SettingsViewModel` MUST use domain enums for theme and backdrop operations, eliminating magic strings and ensuring compile-time type safety.
- **FR-008**: All user-facing strings displayed by ComboBox options MUST be defined in localization resource files (`String.resx`, `String.en.resx`, `String.vi.resx`) in strict UTF-8 without BOM, adhering to Principle VII.
- **FR-009**: All newly introduced or modified classes, enums, properties, and methods MUST have comprehensive XML doc comments in standard technical US English, adhering to Principle V.

### Key Entities *(include if feature involves data)*

- **`AppThemeMode`**: Domain enum representing application theme mode (`Default`, `Light`, `Dark`).
- **`AppBackdropMode`**: Domain enum representing system backdrop material (`Mica`, `Tabbed`, `Acrylic`, `Solid`).
- **`ThemeOptionItem`**: Observable model representing a selectable theme choice. Key attributes: `Mode` (`AppThemeMode`), `DisplayName` (`string`, observable), `Description` (`string`, observable).
- **`BackdropOptionItem`**: Observable model representing a selectable backdrop material. Key attributes: `Mode` (`AppBackdropMode`), `DisplayName` (`string`, observable), `Description` (`string`, observable), `IconGlyph` (`string`).
- **`LanguageOptionItem`**: Observable model representing a selectable UI language. Key attributes: `Code` (`string`), `NativeName` (`string`), `EnglishName` (`string`).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Language switching dynamically updates all ComboBox option text across Settings in under 50ms without collection re-allocation, selection loss, or UI flicker.
- **SC-002**: Selecting any theme or backdrop via ComboBox applies the visual change to the application window within a single rendering frame (<16ms, 60 FPS).
- **SC-003**: 100% of user-facing ComboBox text is sourced from `.resx` localization files with zero hardcoded strings.
- **SC-004**: Project compiles with 0 warnings, 0 errors, and 100% XML documentation coverage in technical US English.
- **SC-005**: Backward compatibility test verifies that existing user preferences in `userdata.json` load seamlessly into the new typed models without data loss.

## Assumptions

- The target runtime is Windows App SDK (WinUI 3) on .NET 10.
- Application localization continues to utilize `TranslationSource` and `.resx` bundles.
- Future ComboBoxes added to dialogs or editor pages can adopt this standardized observable option model pattern.
