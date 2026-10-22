# Implementation Plan: Home Tab in TabStripHeader and Unified Tab Styling

**Branch**: `013-home-tab-tabstripheader` | **Date**: 2026-10-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/013-home-tab-tabstripheader/spec.md`

## Summary

Relocate the permanent Home tab into `TabView.TabStripHeader` at the leftmost position of `ShellTabView`, isolating it from the dynamic, draggable `TabItemsSource` collection. Preserve all existing lifecycle rules: Home displays a close button only when it is the sole open tab; closing Home terminates the application; Home is unclosable when dynamic tabs exist; and Home cannot be moved or dragged. Extract `PillTabViewItemStyle` into a dedicated `Themes/TabStyles.xaml` resource dictionary merged into `App.xaml`, enabling reuse in `DatabasePage.xaml`'s `InnerTabView`, and configure a uniform container background for the `DatabasePage` inner workspace.

## Technical Context

**Language/Version**: C# (LangVersion `preview`), .NET 10 (`net10.0-windows10.0.26100.0`), Windows App SDK (WinUI 3).

**Primary Dependencies**: `Microsoft.WindowsAppSDK` (`TabView`, `TabViewItem`, `ThemeResource`), `WinUIEx`, `CommunityToolkit.Mvvm` v8.4+.

**Storage**: N/A (Presentation and UI styling only).

**Testing**: Windows UI Automation on interactive desktop (`WinSta0\default`), DirectComposition screen capture (`PW_RENDERFULLCONTENT`), physical mouse dispatch (`SetCursorPos`/`mouse_event`), and zero-warning compilation.

**Target Platform**: Windows 10 build 1809+ / Windows 11 desktop (x64 / ARM64).

**Project Type**: Desktop DBMS Client Application (Windows App SDK / WinUI 3).

**Performance Goals**: Tab switching and viewport transitions complete in <16ms (fluid 60 FPS).

**Constraints**:
- Clean MVVM: ViewModels remain 100% UI-agnostic without visual tree references.
- Layout Decoupling Mandate (Principle VII): Viewport `ContentPresenter` remains decoupled in Grid Row 1, NOT placed inside `<TabView>` tags.
- Zero-AutomationId Invariant: Production XAML remains clean; UI automation locates elements via structural geometry, control types, and localized content matching.
- Zero-Speculation Gate (Principle VIII): Live verification on `WinSta0\default` with DirectComposition screenshots required before handoff.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Requirement | Plan Alignment | Status |
|---|---|---|---|
| **Principle I: Clean MVVM & Type Safety** | ViewModels UI-agnostic; no visual tree coupling | `ShellViewModel` coordinates state (`HomeTab`, `Tabs`, `IsHomeSelected`, `SelectedTab`) using source generators without referencing UI controls. View handles layout binding. | **PASS** |
| **Principle II: Modern Fluent UI / UX Standards** | Fluent Design 2, Mica/Acrylic, modern controls | Anchored capsule tab in `TabStripHeader`, shared `Themes/TabStyles.xaml`, uniform card background in `DatabasePage`. | **PASS** |
| **Principle III: Secure Database Connection & Credential Protection** | Credential encryption, no plaintext leaks | No sensitive credentials or queries altered by tab navigation structure. | **PASS** |
| **Principle IV: High Performance & Thread Stewardship** | 60 FPS responsiveness, async execution | Tab switching uses lightweight binding; all operations execute without UI thread stalls. | **PASS** |
| **Principle V: English Technical Documentation Standard** | 100% US English XML doc comments | All new and modified classes, methods, properties, and RelayCommands documented in technical US English. | **PASS** |
| **Principle VI: Spec-Driven Development & Superpowers Discipline** | Spec-Kit + Superpowers discipline | Full SDD workflow: specify -> clarify -> plan -> tasks -> bridge execute -> converge. | **PASS** |
| **Principle VII: Zero Hardcoded Strings & Decoupled Layout** | Zero hardcoded strings; TabView viewport decoupled | Home tab title bound dynamically to `page_home_title`; viewport decoupled in Grid Row 1. | **PASS** |
| **Principle VIII: Visual UI Reproduction & Verification Gate** | Live UI testing on `WinSta0\default`, DirectComposition screenshots | Automated UI test script executes end-to-end scenarios on real desktop with genuine screen captures. | **PASS** |

## Project Structure

### Documentation (this feature)

```text
specs/013-home-tab-tabstripheader/
├── spec.md              # Feature specification & clarifications
├── plan.md              # Implementation plan (this file)
├── research.md          # Architecture research & technical decisions
├── data-model.md        # Component model & state transitions
├── quickstart.md        # Runnable validation scenarios
├── contracts/
│   └── tabstripheader-home-contract.md # XAML layout, ViewModel, and Theme contracts
└── checklists/
    └── requirements.md  # Quality validation checklist
```

### Source Code (repository root)

```text
DataSphere/
├── App.xaml                                     # [MODIFIED] Merges Themes/TabStyles.xaml
├── Themes/
│   └── TabStyles.xaml                           # [NEW] Reusable PillTabViewItemStyle & TabView tokens
├── ViewModels/
│   └── Windows/
│       └── ShellViewModel.cs                    # [MODIFIED] Hosts HomeTab, IsHomeSelected, dynamic Tabs
├── Views/
│   ├── Windows/
│   │   ├── ShellWindow.xaml                     # [MODIFIED] TabStripHeader hosts Home, removes inline style
│   │   └── ShellWindow.xaml.cs                  # [MODIFIED] Wire Home tab events and session sync
│   └── Pages/
│       └── DatabaseGroup/
│           └── DatabasePage.xaml                # [MODIFIED] InnerTabView applies PillTabViewItemStyle, uniform background
```

**Structure Decision**: Extraction of tab styles into `DataSphere/Themes/TabStyles.xaml` establishes a clean, reusable foundation for tab styling across the application, merged centrally in `App.xaml`.

## Implementation Phases

### Phase 0: Outline & Research
- Completed and documented in [research.md](./research.md).
- Researched `TabView.TabStripHeader` hosting of `TabViewItem` with `PillTabViewItemStyle`.
- Designed decoupled state management in `ShellViewModel` for `HomeTab` vs dynamic `Tabs`.
- Decided on standalone `Themes/TabStyles.xaml` resource dictionary.
- Researched uniform background container for `DatabasePage.xaml`.

### Phase 1: Design & Contracts
- Completed and documented in [data-model.md](./data-model.md), [contracts/tabstripheader-home-contract.md](./contracts/tabstripheader-home-contract.md), and [quickstart.md](./quickstart.md).
- Re-evaluated Constitution Check: **All 8 Principles PASS**.

## Complexity Tracking

> **No violations**. The plan strictly follows Clean MVVM, layout decoupling, dynamic localization, and Fluent Design standards.
