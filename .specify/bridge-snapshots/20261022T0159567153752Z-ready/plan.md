# Implementation Plan: Pill-Shaped TabViewItem Styling and Borderless TabStrip

**Branch**: `012-pill-tabview-styling` | **Date**: 2026-10-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/012-pill-tabview-styling/spec.md`

## Summary

Transform the standard chrome tab strip in `ShellWindow.xaml` into a modern Fluent Design 2 pill-shaped (capsule) tab navigation system, and eliminate the horizontal bottom divider line beneath the `TabView`. This achieves a fluid, floating header experience that seamlessly blends with the page content below, while fully preserving drag-and-drop reordering, closable tab handling, and titlebar window dragging.

## Technical Context

**Language/Version**: C# (LangVersion `preview`), .NET 10 (`net10.0-windows10.0.26100.0`), Windows App SDK (WinUI 3).

**Primary Dependencies**: `Microsoft.WindowsAppSDK` (`TabView`, `TabViewItem`, `ThemeResource`), `WinUIEx`.

**Storage**: N/A (Visual styling only).

**Testing**: Windows UI Automation on real desktop station (`WinSta0\default`), DirectComposition screen capture (`PW_RENDERFULLCONTENT`), pixel inspection of tab corners and bottom seam.

**Target Platform**: Windows 10 build 1809+ / Windows 11 desktop (x64 / ARM64).

**Project Type**: Desktop DBMS Client Application.

**Performance Goals**: Tab switching, hover animations, and drag-and-drop maintain fluid 60 FPS (<16ms per frame).

**Constraints**:
- Strict Clean MVVM: ViewModels remain 100% UI-agnostic.
- Layout Decoupling Mandate (Principle VII): ContentPresenter remains strictly decoupled into `Grid.Row="1"`, NOT placed inside `<TabView>` tags.
- DirectComposition Screen Capture: Verified with `PrintWindow(..., PW_RENDERFULLCONTENT)`.
- Zero-AutomationId Invariant: Production XAML remains clean without testing IDs.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Requirement | Plan Alignment | Status |
|-----------|-------------|----------------|--------|
| **Principle I: Clean MVVM & Type Safety** | ViewModels UI-agnostic; no visual tree coupling | Styling implemented purely in XAML markup (`ShellWindow.xaml`) and resources. `ShellViewModel` and `TabItemModel` remain untouched. | **PASS** |
| **Principle II: Modern Fluent UI / UX Standards** | Fluent Design 2, Mica/Acrylic, modern controls | Pill-shaped tabs with floating capsule geometry and borderless tab strip embody standard Fluent Design 2 aesthetics. | **PASS** |
| **Principle III: Secure Database Connection & Credential Protection** | Credential encryption, no plaintext leaks | No credentials or sensitive data involved in visual tab styling. | **PASS** |
| **Principle IV: High Performance & Thread Stewardship** | 60 FPS responsiveness, async execution | Pure XAML styles and resource overrides run on GPU composition engine with zero thread blocking. | **PASS** |
| **Principle V: English Technical Documentation Standard** | 100% US English XML doc comments | Any code/XAML comments authored in technical US English. | **PASS** |
| **Principle VI: Spec-Driven Development & Superpowers Discipline** | Spec-Kit + Superpowers discipline | Full SDD workflow: specify -> plan -> tasks -> bridge execute -> converge. | **PASS** |
| **Principle VII: Zero Hardcoded Strings & Decoupled Layout** | Zero hardcoded strings; TabView viewport decoupled | Tab headers use `{x:Bind Title}`; `<ContentPresenter>` resides in decoupled `Grid.Row="1"`. | **PASS** |
| **Principle VIII: Visual UI Reproduction & Verification Gate** | Live UI testing on `WinSta0\default`, DirectComposition screenshots | Verified on live desktop with DirectComposition screenshot showing pill tabs and borderless seam. | **PASS** |

## Project Structure

### Documentation (this feature)

```text
specs/012-pill-tabview-styling/
├── spec.md              # Feature specification
├── plan.md              # Implementation plan (this file)
├── research.md          # Architecture research & decisions
├── data-model.md        # Visual component model & resource tokens
├── quickstart.md        # Validation scenarios
├── contracts/
│   └── tabview-styling-contract.md # XAML layout and style contracts
└── checklists/
    └── requirements.md  # Quality validation checklist
```

### Source Code (repository root)

```text
DataSphere/
└── Views/
    └── Windows/
        └── ShellWindow.xaml    # [MODIFIED] Defines PillTabViewItemStyle, borderless TabView overrides
```

**Structure Decision**: Changes are contained cleanly within `ShellWindow.xaml`, applying style resources locally to the application shell without modifying global templates or risking regressions in dialogs.

## Implementation Phases

### Phase 0: Outline & Research
- Completed and documented in [research.md](./research.md).
- Researched WinUI 3 `TabView` internal template tokens: `TabViewBorderThickness`, `TabViewBorderBrush`, `TabViewTabStripBorderThickness`, `TabViewItemStroke`, `TabViewItemSeparator`.
- Prototyped pill geometry using `CornerRadius="16"`, `Margin="3,4,3,4"`, and `MinHeight="34"`.

### Phase 1: Design & Contracts
- Completed and documented in [data-model.md](./data-model.md), [contracts/tabview-styling-contract.md](./contracts/tabview-styling-contract.md), and [quickstart.md](./quickstart.md).
- Re-evaluated Constitution Check: **All 8 Principles PASS**.

## Complexity Tracking

> **No violations**. Lightweight pure XAML styling refactoring.
