# Implementation Plan: Dedicated ComboBox Models and Dynamic i18n Theme Architecture

**Branch**: `011-combobox-models-theme-i18n` | **Date**: 2026-10-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/011-combobox-models-theme-i18n/spec.md`

## Summary

Refactor and upgrade the application's ComboBox modeling architecture inspired by the robust, type-safe implementation in `NexaOptimizer.UI`. Replace fragile string-based lookups and ad-hoc collection resets with dedicated domain enums (`AppThemeMode`, `AppBackdropMode`), observable option item models (`ThemeOptionItem`, `BackdropOptionItem`, `LanguageOptionItem`), and in-place reactive internationalization (i18n) property updates. Ensure 100% pure WinUI 3 XAML compiled data binding, full backward compatibility with `UserDataStore`, zero UI flicker on language toggle, and strict compliance with the DataSphere Constitution.

## Technical Context

**Language/Version**: C# (LangVersion `preview`), .NET 10 (`net10.0-windows10.0.26100.0`), Windows App SDK (WinUI 3).

**Primary Dependencies**: `Microsoft.WindowsAppSDK` (WinUI 3 controls, Theme management, SystemBackdrops), `CommunityToolkit.Mvvm` (MVVM Toolkit v8.4+ ObservableObject and Source Generators), `WinUIEx`.

**Storage**: Persistent user configuration via `UserDataStore` (`%LOCALAPPDATA%\DataSphere\userdata.json`).

**Testing**: Windows UI Automation (`scripts/test-real-desktop.ps1` pattern on `WinSta0\default`), DirectComposition screen capture (`PW_RENDERFULLCONTENT`), dotnet build gate (0 warnings, 0 errors).

**Target Platform**: Windows 10 build 1809+ (17763) and Windows 11 desktop (x64 / ARM64).

**Project Type**: Desktop DBMS Client Application (WinUI 3 Modern Desktop).

**Performance Goals**: ComboBox item selection latency < 16ms (60 FPS); dynamic in-place language translation update < 50ms across all items without collection re-allocation or UI flicker.

**Constraints**:
- Strict Clean MVVM: ViewModels and Models MUST NOT import UI visual namespaces (`Microsoft.UI.Xaml.Controls`).
- Zero Hardcoded Strings: All user-facing text sourced exclusively from `.resx` in UTF-8 without BOM.
- English XML Documentation: 100% documentation coverage in technical US English on all public and internal symbols.
- Zero-AutomationId: Clean production XAML without testing-only attributes.
- Live UI Verification Gate: End-to-end testing on `WinSta0\default` with verified DirectComposition visual proof before handoff.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Requirement | Plan Alignment | Status |
|-----------|-------------|----------------|--------|
| **Principle I: Clean MVVM & Type Safety** | ViewModels UI-agnostic; `[ObservableProperty]`; No UI types in models | `ThemeOptionItem` and `BackdropOptionItem` inherit from `ObservableObject` in `DataSphere.Models`, using domain enums. ViewModels have no visual references. | **PASS** |
| **Principle II: Modern Fluent UI / UX Standards** | WinUI 3 Fluent Design 2, Mica/Acrylic, modern controls | ComboBoxes bind to observable models with `DisplayMemberPath="DisplayName"`, supporting fluid theme & backdrop switching. | **PASS** |
| **Principle III: Secure Database Connection & Credential Protection** | Password encryption, no secrets in logs | No database credentials involved in ComboBox UI models. | **PASS** |
| **Principle IV: High Performance & Thread Stewardship** | 60 FPS UI responsiveness, async execution | In-place property mutation avoids collection rebuilds and GC overhead, executing well under 16ms. | **PASS** |
| **Principle V: English Technical Documentation Standard** | 100% US English XML doc comments on all symbols | All newly introduced enums, models, and methods include comprehensive technical US English XML doc comments. | **PASS** |
| **Principle VI: Spec-Driven Development & Superpowers Discipline** | Spec-Kit + Superpowers workflow via bridge | Following `/speckit-plan` -> `/speckit-tasks` -> Superpowers execution -> `/speckit-converge`. | **PASS** |
| **Principle VII: Zero Hardcoded Strings & Dynamic i18n** | No hardcoded text, UTF-8 without BOM, dynamic translation | All ComboBox labels resolved via `LanguageBase.GetLangValue` / `TranslationSource`, updating in-place upon `PropertyChanged`. | **PASS** |
| **Principle VIII: Visual UI Reproduction & Verification Gate** | Live UI testing on `WinSta0\default`, DirectComposition screenshots | Validated via `scripts/verify-fluent-settings-and-backdrops.ps1` with physical click interaction and screenshots. | **PASS** |

## Project Structure

### Documentation (this feature)

```text
specs/011-combobox-models-theme-i18n/
├── spec.md              # Feature specification
├── plan.md              # Implementation plan (this file)
├── research.md          # Architecture research & decisions
├── data-model.md        # Domain enums and observable models
├── quickstart.md        # Verification scenarios
├── contracts/
│   └── combobox-contracts.md # ViewModel and View binding contracts
└── checklists/
    └── requirements.md  # Quality validation checklist
```

### Source Code (repository root)

```text
DataSphere/
├── Models/
│   ├── AppThemeMode.cs          # [NEW] Domain enum for theme modes (Default, Light, Dark)
│   ├── AppBackdropMode.cs       # [NEW] Domain enum for backdrop materials (Mica, Tabbed, Acrylic, Solid)
│   ├── ThemeOptionItem.cs       # [NEW] Dedicated observable model for theme selector
│   ├── BackdropOptionItem.cs    # [MODIFIED] Refactored to use AppBackdropMode and ObservableObject
│   └── LanguageOptionItem.cs    # [NEW/REFACTORED] Dedicated observable model for language selector
├── Services/
│   ├── Contracts/
│   │   └── IThemeService.cs     # [MODIFIED] Strongly typed with AppThemeMode and AppBackdropMode
│   └── ThemeService.cs          # [MODIFIED] Implements typed methods and enum-based window application
├── ViewModels/
│   └── PagesBottom/
│       └── SettingsViewModel.cs # [MODIFIED] Uses typed collections, in-place i18n refresh, Clean MVVM
├── Views/
│   └── PagesBottom/
│       └── SettingsPage.xaml    # [MODIFIED] Bound to DisplayName, clean compiled bindings
└── Resources/Locales/
    ├── String.resx              # [VERIFIED] UTF-8 without BOM localization entries
    ├── String.en.resx           # [VERIFIED] English resource keys
    └── String.vi.resx           # [VERIFIED] Vietnamese resource keys
```

**Structure Decision**: The implementation refactors the presentation and model layers of the single DataSphere desktop project without introducing extraneous libraries.

## Implementation Phases

### Phase 0: Outline & Research
- Completed and documented in [research.md](./research.md).
- Evaluated domain enum pattern from `NexaOptimizer.UI`.
- Established in-place i18n property mutation pattern to prevent collection recreation bugs.

### Phase 1: Design & Contracts
- Completed and documented in [data-model.md](./data-model.md), [contracts/combobox-contracts.md](./contracts/combobox-contracts.md), and [quickstart.md](./quickstart.md).
- Re-evaluated Constitution Check: **All 8 Principles PASS**.

## Complexity Tracking

> **No violations**. Standard WinUI 3 Clean MVVM architecture with zero added dependencies.
