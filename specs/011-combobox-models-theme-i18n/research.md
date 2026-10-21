# Research: Dedicated ComboBox Models and Dynamic i18n Theme Architecture

**Feature Branch**: `011-combobox-models-theme-i18n`
**Date**: 2026-10-21
**Spec**: [spec.md](./spec.md)

## Overview & Architecture Context

DataSphere previously used an untyped generic `SettingOptionItem` (with `string Value` and `string Content`) for Theme selection and a partially typed `BackdropOptionItem` (with `string Key`). In `SettingsViewModel`, whenever language changed, string values were mutated or collections manipulated, but the coupling to magic strings created fragile edge cases, lack of compile-time safety, and desynchronization risks (as diagnosed in `dark-theme-backdrop-desynchronization`).

By benchmarking against `NexaOptimizer.UI` (`D:\DEV\RustWinUI\Nexa-Optimizer\src\NexaOptimizer.UI\Models\AppearanceOption.cs` and `Services\AppServices\AppearanceService.cs`), we identified a superior architectural pattern:
1. Strongly typed domain enums decoupled from visual UI controls.
2. Dedicated ComboBox item models inheriting from `ObservableObject`.
3. In-place observable property mutation on language changes, completely avoiding `ObservableCollection.Clear()` / rebuilds.
4. Clean TwoWay XAML compiled bindings.

---

## Research Findings & Architectural Decisions

### Decision 1: Domain Enums vs Magic Strings

- **Chosen**: Define domain enums in `DataSphere.Models`:
  ```csharp
  public enum AppThemeMode
  {
      Default,
      Light,
      Dark
  }

  public enum AppBackdropMode
  {
      Mica,
      Tabbed,
      Acrylic,
      Solid
  }
  ```
- **Rationale**: 
  - Prevents typos and invalid state transitions across the application.
  - Matches the design of `AppAppearanceMode` and `AppThemeMode` in `NexaOptimizer.UI`.
  - Enables fast switch expressions and exhaustive pattern matching in services and viewmodels.
- **Alternatives Considered**:
  - *Keeping string constants*: Rejected because string matching is error-prone, vulnerable to case sensitivity bugs, and lacks IDE autocomplete / refactoring support.
  - *Directly using WinUI 3 `ElementTheme` / `SystemBackdrop`*: Rejected because ViewModels and Models must remain UI-agnostic per Principle I (Clean MVVM).

---

### Decision 2: In-Place Reactive i18n Mutation vs Collection Recreation

- **Chosen**:
  - `ThemeOptionItem` and `BackdropOptionItem` inherit from `ObservableObject` and declare `DisplayName` and `Description` (or `Summary`) with `[ObservableProperty]`.
  - On `TranslationSource.Instance.PropertyChanged`, the ViewModel iterates over the existing items in `ThemeList` and `BackdropList`, assigning newly translated strings directly:
    ```csharp
    foreach (var theme in ThemeList)
    {
        theme.DisplayName = GetLocalizedThemeName(theme.Mode);
        theme.Description = GetLocalizedThemeDescription(theme.Mode);
    }
    ```
- **Rationale**:
  - When properties with `[ObservableProperty]` are updated, `PropertyChanged` notifies the ComboBox items in WinUI 3 without recreating the collection.
  - The currently selected item (`SelectedItem`), selection index, and dropdown scroll position are completely preserved.
  - Zero memory allocation, zero GC churn, zero visual flicker.
- **Alternatives Considered**:
  - *Calling `ObservableCollection.Clear()` and adding new items*: Rejected because clearing the collection sets `SelectedItem` to null, triggers unnecessary `OnSelectedThemeChanged` events, and can cause visual glitches or focus jumps.

---

### Decision 3: Dedicated Domain Option Models vs Universal Generic Option Item

- **Chosen**: Provide dedicated models:
  - `ThemeOptionItem`: Contains `AppThemeMode Mode`, `DisplayName`, `Description`, `IconGlyph`.
  - `BackdropOptionItem`: Contains `AppBackdropMode Mode`, `DisplayName`, `Summary`, `IconGlyph`.
  - `LanguageOptionItem`: Contains `string Code`, `string NativeName`, `string EnglishName`.
- **Rationale**:
  - Each setting card in Fluent Design 2 has unique visual metadata (e.g. Backdrops have icon glyphs and summaries, Themes have specific mode enums and descriptions).
  - Dedicated models allow clean, specific XML doc comments and clear semantic contracts.
  - Mirrors `NexaOptimizer.UI.Models.AppearanceOption` and `NexaOptimizer.UI.Models.UpdateChannelOption`.
- **Alternatives Considered**:
  - *A single generic `OptionItem<T>`*: Rejected because generic models require complex type arguments in XAML, have less readable data bindings, and make specialized formatting harder to manage.

---

### Decision 4: Backward-Compatible Storage Serialization

- **Chosen**:
  - In `UserDataStore`, keys `IThemeType` and `ISystemBackdropType` continue to store standard string identifiers (`"Default"`, `"Light"`, `"Dark"` and `"Mica"`, `"Tabbed"`, `"Acrylic"`, `"Solid"`).
  - Provide helper methods in models or extensions:
    `AppThemeModeHelper.ToString(mode)` / `AppThemeModeHelper.FromString(str)`
    `AppBackdropModeHelper.ToString(mode)` / `AppBackdropModeHelper.FromString(str)`.
  - Legacy `"Default"` value for `ISystemBackdropType` is transparently migrated to `AppBackdropMode.Mica` (or `Solid` as configured).
- **Rationale**:
  - Guarantees 100% backward compatibility with existing `userdata.json` files on user machines.
  - Requires zero breaking migration or database upgrades.

---

### Decision 5: Complete English XML Documentation & UTF-8 Resource Encoding

- **Chosen**:
  - All new models, enums, methods, and viewmodel properties must be documented with technical US English XML doc comments per Principle V.
  - Resource files `String.resx`, `String.en.resx`, `String.vi.resx` are updated exclusively in UTF-8 without BOM per Principle VII.
