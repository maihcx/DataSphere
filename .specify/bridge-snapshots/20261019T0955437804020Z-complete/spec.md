# Feature Specification: Dynamic Internationalization & Zero Hardcoded Strings (i18n)

**Feature Branch**: `002-dynamic-i18n-localization`

**Created**: 2026-10-19

**Status**: Draft

**Input**: User description: "các hardcode string như public void OpenDatabase() { _tabService.OpenTab(typeof(DatabasePage), \"Cơ sở dữ liệu\", \"\\uE774\"); } hay public partial string Title { get; set; } = \"Cơ sở dữ liệu\"; hiện không hỗ trợ / không tuân thủ i18n, hãy xem Translations.cs và cách sử dụng nó trong các lớp và các xaml lập quy tắc bằng cách chạy lệnh /speckit-constitution để khi code, agent phải tuân thủ quy tắc này, tránh hardcode"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Dynamic Tab Titles & Window Tab Strip Localization (Priority: P1) 🎯 MVP

As a multi-lingual user switching between English and Vietnamese, I want the browser-style tab titles (including the anchored "Home" tab, "Database" tab, and "Settings" tab) to dynamically update their text immediately when I change the application language, so that my active workspace reflects my preferred language without restarting the app.

**Why this priority**: Tab titles are the most prominent and persistent UI elements in DataSphere's tabbed shell. Hardcoded tab titles break the user experience and violate Constitution Principle VII.

**Independent Test**: Launch DataSphere. Verify Home tab title displays localized name. Open Database and Settings tabs. Go to Settings, change language from Vietnamese to English (or vice versa). Verify tab headers immediately change (e.g., "Cơ sở dữ liệu" ➔ "Database", "Cài Đặt" ➔ "Settings") across all open tabs and windows in real-time.

**Acceptance Scenarios**:

1. **Given** the application is running in Vietnamese, **When** the window shell initializes, **Then** the anchored Home tab displays "Trang chủ" (or localized equivalent) instead of a hardcoded string.
2. **Given** the user opens "Cơ sở dữ liệu" and "Cài Đặt" tabs, **When** the user changes language to English in Settings, **Then** all tab titles update immediately to "Database" and "Settings" without recreating the tabs or losing page state.
3. **Given** tabs are torn off into a second window, **When** the language is changed in any window, **Then** tabs in all open windows update their titles synchronously.

---

### User Story 2 - Home Dashboard & Page ViewModels Dynamic String Binding (Priority: P1)

As a user navigating the Home dashboard and feature pages, I want all action cards, headings, descriptions, and page titles to be dynamically bound to localization resources, so that all interface text matches the selected language.

**Why this priority**: Eliminates hardcoded literals in `HomePage.xaml`, `HomeViewModel.cs`, `DatabaseViewModel.cs`, and `SettingsViewModel.cs`, fulfilling the core intent of removing hardcoded UI strings.

**Independent Test**: Open the Home dashboard; inspect the banner title, description, and action cards ("Cơ sở dữ liệu", "Cài Đặt"). Switch language in Settings and return to Home; confirm that 100% of the visible dashboard cards, action button descriptions, and page headers update to the new language instantly.

**Acceptance Scenarios**:

1. **Given** the user is viewing `HomePage`, **When** language is set to Vietnamese, **Then** action cards display "Cơ sở dữ liệu", "Cài Đặt", and localized description summaries.
2. **Given** the user switches language to English, **When** returning to `HomePage`, **Then** cards display "Database", "Settings", and English description text.
3. **Given** `DatabaseViewModel.Title`, **When** culture changes in `TranslationSource.Instance`, **Then** the `Title` property automatically refreshes its value from `TranslationSource` and notifies bindings.

---

### User Story 3 - Centralized Localization Resources & Tab Service API Modernization (Priority: P2)

As a developer maintaining DataSphere, I want `ITabService.OpenTab` to accept a localization key (`titleKey`) alongside glyph and page type, and I want all application strings to be cleanly organized across `String.resx`, `String.en.resx`, and `String.vi.resx` with graceful fallbacks, so that any new feature can easily add localized tabs and views without hardcoding strings.

**Why this priority**: Provides the architectural foundation and API contract to guarantee long-term compliance with Constitution Principle VII.

**Independent Test**: Call `_tabService.OpenTab(typeof(DatabasePage), "page_database_title", "\uE774")`; verify the tab subscribes to `TranslationSource.Instance.PropertyChanged`, resolves initial title using `titleKey`, and updates automatically whenever culture changes.

**Acceptance Scenarios**:

1. **Given** a tab opened with a `titleKey`, **When** `TranslationSource.Instance.CurrentCulture` changes, **Then** `TabItemModel.Title` is re-evaluated using the `titleKey`.
2. **Given** a missing translation key in the current culture, **When** resolved, **Then** the system falls back to the default culture resource or key identifier without crashing or displaying blank text.
3. **Given** `String.resx`, `String.en.resx`, and `String.vi.resx`, **When** audited, **Then** all required keys for Home, Database, Settings, and Common Actions are defined in all three files.

---

### Edge Cases

- **Missing Translation Key**: What happens if a key is not defined in `String.vi.resx`? The system MUST fall back to `String.resx` (default/English), and if still missing, return the raw key name rather than throwing an exception or rendering empty text.
- **Dynamic Language Switch with Multiple Windows**: What happens when a user changes language in Window 2? `TranslationSource.Instance` is a shared singleton; all windows and tabs across the process MUST receive the `PropertyChanged` event and refresh their text.
- **Custom Tab Titles**: What happens if a tab has a dynamic or user-generated title (e.g., query tab "Query 1 - localhost")? `TabItemModel` MUST support both key-based localized titles (`TitleKey`) and custom dynamic titles (`Title`), updating localized titles only when `TitleKey` is set.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Hardcoded string literals for user-facing UI text in C# code, ViewModels, Models, and XAML are STRICTLY PROHIBITED per Constitution Principle VII.
- **FR-002**: `TabItemModel` MUST include a `TitleKey` property and MUST listen to `TranslationSource.Instance.PropertyChanged` to refresh `Title` dynamically when the application language changes.
- **FR-003**: `ITabService.OpenTab` and `TabService.OpenTab` MUST support passing a `titleKey` (resource key identifier) for automatic localized tab header resolution.
- **FR-004**: `HomeViewModel` MUST NOT hardcode Vietnamese strings in `OpenDatabase()` or `OpenSettings()`; it MUST pass the appropriate localization keys (`page_database_title`, `page_settings_title`).
- **FR-005**: `DatabaseViewModel` MUST NOT hardcode `Title = "Cơ sở dữ liệu"`; it MUST bind to or resolve from `TranslationSource` via `page_database_title` and listen to culture change notifications.
- **FR-006**: `HomePage.xaml` cards, headers, and descriptions MUST be bound to localized properties in `HomeViewModel` that update dynamically when the culture changes.
- **FR-007**: Resource files (`Resources/Locales/String.resx`, `String.en.resx`, `String.vi.resx`) MUST contain complete and symmetric translations for all shell, home, database, and settings UI text.
- **FR-008**: String formatting with dynamic parameters MUST use `LanguageBase.GetLangValue(key, args)`.

### Key Entities

- **`TranslationSource`**: Singleton notifying `INotifyPropertyChanged` when `CurrentCulture` changes; provides indexer `this[string key]` for dynamic string retrieval.
- **`LanguageBase`**: Static helper managing culture list, active culture selection, persistence (`UserDataStore`), and formatted string resolution (`GetLangValue`).
- **`TabItemModel`**: Data model representing a tab; enhanced with `TitleKey` to support real-time header localization upon language change events.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero hardcoded user-facing strings in `HomeViewModel.cs`, `DatabaseViewModel.cs`, `ShellViewModel.cs`, `HomePage.xaml`, and tab creation commands.
- **SC-002**: Switching between "Tiếng Việt" and "English" in Settings immediately updates all open tabs, dashboard cards, and page titles across all open windows in < 100 milliseconds without requiring an application restart.
- **SC-003**: 100% of required UI keys are present in all three resource files (`String.resx`, `String.en.resx`, `String.vi.resx`).
- **SC-004**: The project builds cleanly with 0 errors and 0 warnings (`dotnet build DataSphere\DataSphere.csproj -c Debug`).

## Assumptions

- `TranslationSource` and `LanguageBase` in `DataSphere/Utils/Translations.cs` remain the primary localization engine.
- Supported languages initially include English (`en`) and Vietnamese (`vi`), stored in `DataSphere/Resources/Locales/`.
- User language preference is persisted in `UserDataStore` under key `"Language"`.
