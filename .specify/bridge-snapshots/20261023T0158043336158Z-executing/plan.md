# Implementation Plan: Tab Sleeping & Memory Saver

**Branch**: `016-tab-sleeping-memory-saver` | **Date**: 2026-10-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/016-tab-sleeping-memory-saver/spec.md`

## Summary

Implement a two-tier tab lifecycle management system that keeps inactive tabs instantly responsive (0ms frame-time switching) during normal use, while automatically transitioning long-dormant background tabs into a low-power sleeping state after an idle timeout. Include user-configurable toggle and timeout controls in Settings, visual sleeping badges on tab headers, seamless on-demand waking, and strict terminal resource cleanup when closing tabs.

## Technical Context

**Language/Version**: C# 13 (LangVersion `preview`), .NET 10 (`net10.0-windows10.0.26100.0`)  
**Primary Dependencies**: Windows App SDK (WinUI 3), `CommunityToolkit.Mvvm` 8.4+, `WinUIEx`  
**Storage**: Application settings persistence via `UserDataStoreService` (`settings.json`)  
**Testing**: Windows UI Automation on real interactive desktop (`WinSta0\default`), PowerShell, MSTest  
**Target Platform**: Windows 10/11 x64 Desktop  
**Project Type**: Desktop GUI application (WinUI 3)  
**Performance Goals**: <16ms frame time (fluid 60-144 FPS) on active tab switching; >60% private working set reduction on sleeping tabs; wake-up rehydration <500ms  
**Constraints**: Zero hardcoded strings (Principle VII), 100% XML doc comments in US English (Principle V), clean MVVM decoupling (Principle I), zero XAML automation pollution (Principle VIII)  
**Scale/Scope**: Up to 20 concurrent tabs in multi-window desktop session  

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principle I (Clean MVVM & Type Safety)**: PASS. All lifecycle states (`TabLifecycleState`), settings flags, and commands reside in ViewModels and models. ViewModels remain 100% agnostic of visual XAML types.
- **Principle II (Modern Fluent UI / UX Standards)**: PASS. Uses Fluent Design 2 card layout in Settings, standard typography tokens, and non-blocking background orchestration.
- **Principle III (Secure Database Connection & Credential Protection)**: PASS. Sleeping tabs do not dump or expose credentials; database sessions remain protected.
- **Principle IV (High Performance & Thread Stewardship)**: PASS. Evaluated via a single 60s background timer; wake-up operations are non-blocking.
- **Principle V (English Technical Documentation Standard)**: PASS. 100% XML doc comments in technical US English across all new types and methods.
- **Principle VI (Spec-Driven Development & Superpowers Discipline)**: PASS. Built upon spec-kit workflow with full verification gates.
- **Principle VII (Zero Hardcoded User-Facing Strings & Dynamic i18n)**: PASS. All settings labels, tooltips, and timeout options localized via `TranslationSource` in `String.resx`, `String.en.resx`, `String.vi.resx`.
- **Principle VIII (Visual UI Reproduction, Diagnostic Inspection & Verification Gate)**: PASS. End-to-end live testing will execute on `WinSta0\default` with DirectComposition capture.

---

## Project Structure

### Documentation (this feature)

```text
specs/016-tab-sleeping-memory-saver/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output: Tab sleeping patterns & idle scheduling
├── data-model.md        # Phase 1 output: Lifecycle state machine & entity contracts
├── quickstart.md        # Phase 1 output: Validation guide & test scenarios
├── contracts/           # Phase 1 output: Interface definitions
│   └── tab-memory-saver-contract.md
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 output (/speckit-tasks command)
```

### Source Code Layout

```text
DataSphere/
├── Models/
│   ├── TabLifecycleState.cs                  # Added Sleeping state
│   ├── TabItemModel.cs                       # Augmented with LastActiveTime, IsSleeping, CanSleep
│   └── Settings/TabSleepTimeoutOption.cs     # Timeout dropdown option model
├── Services/
│   ├── Contracts/
│   │   ├── ISleepableTabContent.cs           # Sleep & WakeUp contract for tab viewports
│   │   └── ITabMemorySaverService.cs         # Background scheduler and sleep orchestrator
│   ├── TabService.cs                         # Tracks tab activity & triggers sleep/wakeup
│   └── TabMemorySaverService.cs              # Timer-driven background evaluation service
├── ViewModels/
│   └── PagesBottom/
│       └── SettingsViewModel.cs              # Performance & Memory Saver settings properties
├── Views/
│   ├── PagesBottom/
│   │   └── SettingsPage.xaml                 # Performance & Memory card UI
│   └── Windows/
│       └── ShellWindow.xaml                  # Sleeping badge indicator on TabView items
└── Resources/Locales/
    ├── String.resx                           # Neutral English resource keys
    ├── String.en.resx                        # English translation strings
    └── String.vi.resx                        # Vietnamese translation strings
```

**Structure Decision**: Standard layered MVVM extension inside the existing `DataSphere` project. All new services wired cleanly via Microsoft.Extensions.DependencyInjection in `App.xaml.cs`.

---

## Complexity Tracking

> **Constitution check exhibited 0 violations; no complexity exemptions required.**
