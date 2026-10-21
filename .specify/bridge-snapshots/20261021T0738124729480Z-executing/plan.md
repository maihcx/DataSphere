# Implementation Plan: Fluent Settings Redesign, System Backdrops & Native WinUI 3 Theme Architecture

**Branch**: `010-fluent-settings-and-system-backdrops` | **Date**: 2026-10-21T14:14:00+07:00 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/010-fluent-settings-and-system-backdrops/spec.md`

---

## Summary

This plan executes the complete visual and architectural overhaul of DataSphere's window backdrops, theme system, and settings page layout to meet official WinUI 3 Fluent Design 2 standards:
1. **Dynamic System Backdrops**: Integrate native Windows App SDK `MicaBackdrop` (`MicaKind.Base` and `MicaKind.BaseAlt` / Tabbed), `DesktopAcrylicBackdrop`, and Solid color fallback into `ShellWindow` and `ThemeService`, persisted in `UserDataStore`.
2. **Settings Page Fluent Overhaul**: Redesign `SettingsPage.xaml` using standard Fluent setting cards, enclosing `ScrollViewer` inside a stretched root `Grid`, using `<StackPanel HorizontalAlignment="Center" MaxWidth="900" Padding="24,24,24,32" Spacing="16">` to guarantee symmetric centering across all window resolutions (resolving the 300px blank gap and rightward drift bug), and eliminating text truncation on controls (e.g. ComboBoxes min-width 200px so "Mặc định", "Tiếng Việt", "Tabbed" never cut off with ellipses).
3. **Uniform WinUI 3 System Colors**: Eliminate all custom hardcoded colors, ensuring window root transparency when backdrops are active and utilizing standard `{ThemeResource ...}` brushes for cards, strokes, text, and icons across Light and Dark themes.

---

## Technical Context

**Language/Version**: C# (LangVersion `preview`), .NET 10 (`net10.0-windows10.0.26100.0`).

**Primary Dependencies**: `Microsoft.WindowsAppSDK` (WinUI 3 1.6+), `WinUIEx`, `CommunityToolkit.Mvvm` v8.4+.

**Storage**: Local user settings stored via `UserDataStore` (key: `ISystemBackdropType`).

**Testing**: Real Desktop UI Automation (`scripts/verify-fluent-settings-and-backdrops.ps1`) on `WinSta0\default` with DirectComposition capture (`PrintWindow`, `PW_RENDERFULLCONTENT`).

**Target Platform**: Windows 11 (build 22000+) & Windows 10 (1809+).

**Project Type**: Desktop GUI Database Management System (WPF/WinUI 3 Hybrid Architecture).

**Performance Goals**: Instant backdrop switching (<100ms), 60+ FPS window rendering, 0 visual tearing.

**Constraints**:
- Strict Clean MVVM: zero business logic in View code-behind.
- 100% US English XML documentation comments on all new/modified members.
- Zero hardcoded user-facing strings; 100% dynamic localization via `String.*.resx` (UTF-8 without BOM).

**Scale/Scope**: Top-level application shell (`ShellWindow`), `ThemeService`, and `SettingsPage`.

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Requirement | Status | Notes |
|---|---|---|---|
| **Principle I: Clean MVVM & Type Safety** | ViewModels decoupled from Visual Tree, use `[ObservableProperty]` and `[RelayCommand]`. Zero business logic in code-behind. | PASS | `SettingsViewModel` controls backdrop options and state; `ShellWindow` only listens to `IThemeService.BackdropChanged` for window backdrop assignment. |
| **Principle II: Modern Fluent UI / UX Standards** | Native Mica / Acrylic backdrops, TabView titlebar integration, standard spacing tokens, Light/Dark theme sync. | PASS | Directly fulfills this principle by enabling Tabbed Mica, Mica Base, and Desktop Acrylic with full theme synchronization. |
| **Principle III: Secure Database Connection & Credential Protection** | No credential leakage, encrypted storage. | PASS | N/A — this feature governs purely UI presentation and backdrops. |
| **Principle IV: High Performance & Thread Stewardship** | Fluid 60 FPS, non-blocking UI. | PASS | Windows system backdrops are hardware-accelerated on the Compositor thread (DComp). |
| **Principle V: English Technical Documentation Standard** | 100% XML doc comments in US English. | PASS | All new models (`BackdropOptionItem`), services, methods, and properties have standard US English doc comments. |
| **Principle VI: Spec-Driven Development & Superpowers Discipline** | Spec-Kit + Superpowers SDD workflow. | PASS | Following `spec.md` -> `plan.md` -> `tasks.md` -> Superpowers bridge. |
| **Principle VII: Zero Hardcoded User-Facing Strings & Dynamic i18n** | All user text in `.resx` (UTF-8 without BOM), dynamic runtime switching via `TranslationSource`. | PASS | All new backdrop names and summaries are added to `String.resx`, `String.en.resx`, `String.vi.resx` in UTF-8 without BOM. |
| **Principle VIII: Visual UI Verification Gate** | Live UI automation on `WinSta0\default` with DirectComposition screenshots. | PASS | Covered by `scripts/verify-fluent-settings-and-backdrops.ps1`. |

---

## Project Structure

### Documentation (this feature)

```text
specs/010-fluent-settings-and-system-backdrops/
├── spec.md              # Feature specification
├── plan.md              # This implementation plan
├── research.md          # Technical research & design decisions
├── data-model.md        # Entities & state transitions
├── quickstart.md        # Validation scenarios & test runner
├── contracts/           # API and XAML contracts
│   └── settings-backdrop-contracts.md
└── tasks.md             # Actionable task breakdown (Phase 2 output)
```

### Source Code (repository root)

```text
DataSphere/
├── Models/
│   └── BackdropOptionItem.cs                              # Selectable backdrop option model
├── Services/
│   ├── Contracts/
│   │   └── IThemeService.cs                              # Extended with backdrop management
│   └── ThemeService.cs                                   # Backdrop state and persistence implementation
├── ViewModels/
│   └── PagesBottom/
│       └── SettingsViewModel.cs                          # Backdrop options collection & selection command
├── Views/
│   ├── Windows/
│   │   ├── ShellWindow.xaml                              # Transparent window root when backdrops active
│   │   └── ShellWindow.xaml.cs                           # Dynamic native SystemBackdrop assignment
│   └── PagesBottom/
│       └── SettingsPage.xaml                             # Redesigned fluent setting cards & untruncated controls
└── Resources/
    └── Locales/
        ├── String.resx                                   # Localization keys (UTF-8)
        ├── String.en.resx                                # English translations
        └── String.vi.resx                                # Vietnamese translations
```

**Structure Decision**: Modifies existing presentation components cleanly within standard MVVM folders without introducing new third-party libraries.

---

## Complexity Tracking

No constitutional violations or unjustified complexity introduced. All additions leverage built-in Windows App SDK APIs.
