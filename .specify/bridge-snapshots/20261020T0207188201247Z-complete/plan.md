# Implementation Plan: User Preferences & State Persistence (UserDataStore Integration)

**Branch**: `003-user-data-store-persistence` | **Date**: 2026-10-20 | **Spec**: [specs/003-user-data-store-persistence/spec.md](spec.md)

**Input**: Feature specification from `/specs/003-user-data-store-persistence/spec.md`

## Summary

Integrate local preferences storage (`UserDataStore`) across DataSphere to restore and persist user settings previously utilized in the application's legacy baseline. Specifically, this plan implements:
1. **Application Theme Persistence & Live Sync**: Persisting `"IThemeType"` ("Light", "Dark", "Default") in `UserDataStore`, restoring it at startup via a new `ThemeService`, and updating all open windows in real-time.
2. **Language Preference Startup Restoration**: Reading `"Language"` from `UserDataStore` during startup in `ApplicationHostService` so that `TranslationSource.Instance.CurrentCulture` initializes the user's preferred language before any UI renders.
3. **Window Geometry & Maximized State Persistence**: Saving window position (`Window_Left`, `Window_Top`), dimensions (`Window_Width`, `Window_Height`), and state (`IsWindow_Maximized`) on window close, and restoring them during shell window startup with multi-monitor boundary validation.
4. **Hardened Storage Reliability**: Ensuring `UserDataStore` is completely thread-safe, auto-creates directory structure, silently recovers from corrupted files, and maintains encrypted storage for sensitive data.

## Technical Context

**Language/Version**: C# (LangVersion `preview`), .NET 10 (`net10.0-windows10.0.26100.0`)  
**Primary Dependencies**: `Microsoft.WindowsAppSDK` (v2.5.1), `WinUIEx` (v2.9.3), `CommunityToolkit.Mvvm` (v8.4.0), `Microsoft.Extensions.Hosting` (v10.0.0)  
**Storage**: Local JSON file at `%LOCALAPPDATA%\DataSphere\userdata.json` (`UserDataStore`), encrypted with `PasswordEncryptor` (AES-GCM / Windows DPAPI) for sensitive data  
**Testing**: Standalone executable headless verification suite (`scratch/TestTranslationSource`) + solution build validation  
**Target Platform**: Windows 10/11 x64 desktop (unpackaged desktop app)  
**Project Type**: Desktop application (WinUI 3 / Windows App SDK)  
**Performance Goals**: Startup preference reading overhead < 15ms; 60 FPS UI responsiveness  
**Constraints**: Zero hardcoded strings (Constitution Principle VII); 100% US English XML doc comments (Constitution Principle V); 0 error, 0 warning build  
**Scale/Scope**: 4 primary persistence areas (Theme, Language, Window Geometry, Encrypted Credentials) across `ShellWindow`, `SettingsViewModel`, `ApplicationHostService`, and `UserDataStore`  

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Requirement | Status | Compliance Details |
|---|---|:---:|---|
| **Principle I: Clean MVVM & Type Safety** | ViewModels UI-agnostic; no visual types in ViewModels | **PASS** | `ThemeService` handles window-level theming; `SettingsViewModel` only interacts with string preference keys. |
| **Principle II: Modern Fluent UI / UX** | Fluent Design 2, Dark/Light theme, Mica backdrop | **PASS** | `ThemeService` coordinates `RequestedTheme` on root elements and synchronizes caption button styling. |
| **Principle III: Secure Credentials** | No plain-text passwords on disk | **PASS** | `UserDataStore.SetValuePass` and `GetValuePass` strictly use `PasswordEncryptor`. |
| **Principle IV: High Performance** | Non-blocking async I/O, <16ms frame budget | **PASS** | Thread-safe in-memory caching in `UserDataStore` eliminates disk reading stalls on property access. |
| **Principle V: English Documentation** | 100% US English XML doc comments on all symbols | **PASS** | All new services, methods, interfaces, and properties are documented with full XML doc comments. |
| **Principle VI: Spec-Driven Development** | Spec-Kit + Superpowers workflow with bridge | **PASS** | Plan follows strict phase sequence (`spec.md` &rarr; `research.md` &rarr; `data-model.md` &rarr; `contracts/` &rarr; `quickstart.md` &rarr; `plan.md`). |
| **Principle VII: Zero Hardcoded Strings** | Localization via `TranslationSource` & `.resx` | **PASS** | All user-facing theme names and labels bind directly to `TranslationSource` resources. |

## Project Structure

### Documentation (this feature)

```text
specs/003-user-data-store-persistence/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (research on WinUI 3 theming & window persistence)
├── data-model.md        # Phase 1 output (JSON schema, WindowPlacementState, ThemeConfiguration)
├── quickstart.md        # Phase 1 output (runnable verification walkthrough)
├── contracts/           # Phase 1 output (IThemeService, WindowPlacementManager, UserDataStore API)
│   └── user-data-store-contract.md
└── checklists/
    └── requirements.md  # Spec quality checklist
```

### Source Code Impact

```text
DataSphere/
├── Services/
│   ├── Contracts/
│   │   ├── IThemeService.cs          # [NEW] Application theme coordination contract
│   │   └── IWindowManager.cs         # Existing multi-window coordinator
│   ├── ThemeService.cs               # [NEW] Implementation of IThemeService applying themes to windows
│   └── ApplicationHostService.cs     # [MODIFY] Initializes language & theme from UserDataStore on startup
├── Utils/
│   ├── UserDataStore.cs              # [MODIFY] Harden thread safety, file auto-creation & null checks
│   ├── Translations.cs               # [MODIFY] Guard GetSetupLanguage() with fallback to CurrentUICulture
│   └── WindowPlacementHelper.cs      # [NEW] Save and restore AppWindow position, size, and maximized state
├── ViewModels/PagesBottom/
│   └── SettingsViewModel.cs          # [MODIFY] Wire theme selection to IThemeService
└── Views/Windows/
    ├── ShellWindow.xaml              # [MODIFY] Name RootGrid for theme targeting
    └── ShellWindow.xaml.cs           # [MODIFY] Save/restore window placement on close/open via WindowPlacementHelper
```

## Architectural Design & Implementation Phases

### Phase 0: Research & Resolution (Completed)
- Documented unpackaged WinUI 3 window bounds handling (`AppWindow.Position`, `AppWindow.Size`, `OverlappedPresenter`).
- Designed live multi-window theme propagation via `IThemeService`.
- Established early startup language initialization pattern in `ApplicationHostService`.

### Phase 1: Data Contracts & Design (Completed)
- Defined `userdata.json` key registry and default fallbacks in `data-model.md`.
- Established `IThemeService` and `WindowPlacementManager` contracts in `contracts/user-data-store-contract.md`.
- Provided step-by-step verification flows in `quickstart.md`.

### Phase 2: Implementation Sequence (for `/speckit-tasks`)
1. **Storage Hardening (`UserDataStore.cs`)**:
   - Add thread synchronization lock (`_syncLock = new object()`) around dictionary updates and disk writes.
   - Guard against invalid JSON parsing and ensure directory `%LOCALAPPDATA%\DataSphere` is created safely.
2. **Language Startup Restoration**:
   - Update `LanguageBase.GetSetupLanguage()` to cleanly fall back if `"Language"` is null or invalid.
   - Call `TranslationSource.Instance.CurrentCulture = LanguageBase.GetSetupLanguage();` in `ApplicationHostService.StartAsync()`.
3. **Theme Service & Real-time Live Theming**:
   - Create `IThemeService` and `ThemeService.cs` implementing theme application on `WindowEx` / `ShellWindow`.
   - Register `IThemeService` as Singleton in `App.xaml.cs`.
   - Update `SettingsViewModel.OnSelectedThemeChanged` to notify `IThemeService`.
   - Initialize theme on startup before window activation.
4. **Window Geometry & Maximized State Persistence**:
   - Create `WindowPlacementHelper.cs` to save `Window_Left`, `Window_Top`, `Window_Width`, `Window_Height`, and `IsWindow_Maximized` on window close.
   - Restore saved bounds during `ShellWindow` initialization, clamping coordinates against active screen display boundaries.
5. **Verification & Testing**:
   - Execute verification tests covering theme persistence, language startup, window geometry restoration, and storage corruption recovery.
   - Compile with 0 errors and 0 warnings.
