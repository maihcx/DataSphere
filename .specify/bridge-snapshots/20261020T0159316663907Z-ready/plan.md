# Implementation Plan: Dynamic Internationalization & Zero Hardcoded Strings (i18n)

**Branch**: `002-dynamic-i18n-localization` | **Date**: 2026-10-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-dynamic-i18n-localization/spec.md`

## Summary

Eradicate all hardcoded user-facing string literals in C# ViewModels, Services, and XAML markup across DataSphere to comply with Constitution Principle VII. Modernize `ITabService` to accept resource `titleKey` identifiers, enhance `TabItemModel` to listen to `TranslationSource.Instance.PropertyChanged` for live tab title updates without tab recreation, bind `HomePage` cards and page titles dynamically to `TranslationSource`, and ensure 100% symmetric key coverage across `String.resx`, `String.en.resx`, and `String.vi.resx`.

## Technical Context

**Language/Version**: C# (LangVersion `preview`), .NET 10 (`net10.0-windows10.0.26100.0`).

**Primary Dependencies**: `Microsoft.WindowsAppSDK` (WinUI 3 v2.5.1), `CommunityToolkit.Mvvm` (v8.4.0), `WinUIEx` (v2.9.3), `Microsoft.Extensions.Hosting` (v10.0.0).

**Storage**: `UserDataStore` (local JSON user preferences storing `"Language"` setting).

**Testing**: CLI verification (`dotnet build DataSphere\DataSphere.csproj -c Debug`), quickstart run scenarios, automated string search validation for zero hardcoded UI strings.

**Target Platform**: Windows 10 (Build 19041+) and Windows 11 Desktop (x64 unpackaged).

**Project Type**: Windows Desktop Application (WinUI 3 + Clean MVVM).

**Performance Goals**: Instantaneous dynamic string update across all open tabs, windows, and pages upon language switch in < 100ms with zero UI visual stutter.

**Constraints**: Zero hardcoded user-facing strings in C# and XAML (Constitution Principle VII); 100% US English XML doc comments (Principle V); 0 build errors and 0 warnings (Quality Gates).

**Scale/Scope**: 4 primary Views (`ShellWindow`, `HomePage`, `DatabasePage`, `SettingsPage`), 4 ViewModels, 2 Core Services (`TabService`, `WindowManager`), 3 Resource files (`String.resx`, `String.en.resx`, `String.vi.resx`).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principle I (Clean MVVM & Type Safety)**: PASS. All dynamic localization logic resides in ViewModels and Services. Views remain pure XAML binding via `{x:Bind Mode=OneWay}`.
- **Principle II (Modern Fluent UI / UX Standards)**: PASS. TabView and modern controls maintain fluent Mica design seamlessly.
- **Principle III (Credential Protection)**: PASS. No credentials or connection strings are modified or exposed.
- **Principle IV (Performance & Thread Stewardship)**: PASS. String lookups are memory-cached via `ResourceManager`; dynamic updates execute immediately without background I/O contention.
- **Principle V (English Technical Documentation)**: PASS. All new/modified members will have 100% US English XML doc comments (`/// <summary>`, `<param>`, `<returns>`).
- **Principle VI (Spec-Driven Development & Superpowers)**: PASS. Flow follows Spec-Kit plan ➔ tasks ➔ superpowers bridge.
- **Principle VII (Zero Hardcoded User-Facing Strings & Dynamic i18n)**: PASS. This feature explicitly satisfies and implements Principle VII.

## Project Structure

### Documentation (this feature)

```text
specs/002-dynamic-i18n-localization/
├── plan.md              # This implementation plan
├── research.md          # Architectural research & decisions
├── data-model.md        # Extended TabItemModel & schema
├── quickstart.md        # End-to-end verification guide
├── contracts/
│   └── tab-service-contract.md # ITabService localized contract
└── tasks.md             # Implementation tasks (/speckit-tasks output)
```

### Source Code Layout

```text
DataSphere/
├── Models/
│   └── TabItemModel.cs               # Add TitleKey & dynamic culture listener
├── Services/
│   ├── Contracts/
│   │   └── ITabService.cs           # Update OpenTab to receive titleKey
│   └── TabService.cs                 # Implement titleKey resolution & TabItemModel binding
├── ViewModels/
│   ├── Pages/
│   │   ├── HomeViewModel.cs          # Localized card properties & TitleKey dispatches
│   │   └── DatabaseGroup/
│   │       └── DatabaseViewModel.cs  # Dynamic Title property bound to TranslationSource
│   └── Windows/
│       └── ShellViewModel.cs         # Anchor Home tab with titleKey: "page_home_title"
├── Views/
│   ├── Pages/
│   │   ├── HomePage.xaml             # Bind banner, section title & cards to ViewModel
│   │   └── DatabaseGroup/
│   │       └── DatabasePage.xaml     # Bind header to ViewModel.Title
│   └── Windows/
│       └── ShellWindow.xaml.cs       # Clean tab management
└── Resources/
    └── Locales/
        ├── String.resx               # Neutral/Invariant keys
        ├── String.en.resx            # English translations
        └── String.vi.resx            # Vietnamese translations
```

**Structure Decision**: Single WinUI 3 project layout targeting `DataSphere/` with dedicated MVVM separation.

## Complexity Tracking

> **No constitutional violations detected. Table left intentionally empty.**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| None | N/A | N/A |
