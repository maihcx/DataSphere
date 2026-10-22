# Implementation Plan: Surface & Tab Selected Theme Brush Contrast Enhancement

**Branch**: `015-surface-brush-contrast` | **Date**: 2026-10-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/015-surface-brush-contrast/spec.md`

---

## Summary

Standardize all user-facing content workspace backgrounds (`DatabasePage`, `ConnectViewControl`, `DatabaseViewControl`, `VirtualTable`) and selected tab pill visual states (`PillTabViewItemStyle`) on `CardBackgroundFillColorDefaultBrush`. This resolves the issue where `LayerFillColorDefaultBrush` renders as a faint 5% alpha wash in dark theme, restoring crisp visual elevation, high contrast, and visual parity with the cards on `HomePage`.

---

## Technical Context

**Language/Version**: C# (LangVersion preview), .NET 10 (`net10.0-windows10.0.26100.0`)

**Primary Dependencies**: Windows App SDK (WinUI 3), `CommunityToolkit.Mvvm` v8.4+, `WinUIEx`

**Storage**: N/A (Declarative XAML theme resources)

**Testing**: Live UI Automation on interactive desktop (`WinSta0\default`), DirectComposition screen capture (`PrintWindow` with `PW_RENDERFULLCONTENT`)

**Target Platform**: Windows 10/11 Desktop (x64)

**Project Type**: Windows Desktop Application (WinUI 3 XAML)

**Performance Goals**: Fluid 60 FPS rendering (<16ms frame time), instant (<100ms) theme switching

**Constraints**: WCAG AA contrast (> 4.5:1) for all foreground text and icons, zero code-behind business logic, zero `AutomationProperties.AutomationId` pollution in XAML

**Scale/Scope**: 5 target files (`TabStyles.xaml`, `DatabasePage.xaml`, `ConnectViewControl.xaml`, `DatabaseViewControl.xaml`, `VirtualTable.xaml`)

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Requirement | Status | Compliance Details |
|---|---|---|---|
| **Principle I: Clean MVVM & Type Safety** | Zero business logic in code-behind; ViewModels UI-agnostic | **PASS** | 100% declarative XAML `{ThemeResource}` updates; no code-behind additions. |
| **Principle II: Modern Fluent UI / UX Standards** | Native Fluent 2 controls, seamless Light/Dark theme sync | **PASS** | Adopts official `CardBackgroundFillColorDefaultBrush` with `CardStrokeColorDefaultBrush`. |
| **Principle III: Secure Database Connection** | Zero credential leaks | **PASS** | No database credential or connection string operations affected. |
| **Principle IV: High Performance & Thread Stewardship** | 60 FPS, non-blocking I/O | **PASS** | Native XAML resource lookup handled by hardware-accelerated DirectComposition. |
| **Principle V: English Technical Documentation** | 100% XML doc comments in standard technical US English | **PASS** | All spec, plan, research, and contract files authored in US English. |
| **Principle VI: Spec-Driven Development & Superpowers** | Spec Kit + Superpowers Bridge discipline | **PASS** | Managed via `/speckit-plan` with subsequent bridge handoff. |
| **Principle VII: Zero Hardcoded User-Facing Strings** | All text from `TranslationSource` / `.resx` | **PASS** | No user-facing text changed or added. |
| **Principle VIII: Visual UI Reproduction & Verification Gate** | Live UI testing on `WinSta0\default`, DirectComposition screenshots | **PASS** | Verification script will launch on `WinSta0\default` and capture Dark/Light theme evidence. |

---

## Project Structure

### Documentation (this feature)

```text
specs/015-surface-brush-contrast/
├── spec.md              # Requirements and user stories
├── plan.md              # This file (architectural plan)
├── research.md          # Research and design decisions
├── data-model.md        # Token mapping and visual states
├── quickstart.md        # Interactive validation scenarios
├── contracts/
│   └── xaml-brush-contract.md  # Exact XAML declarations
└── checklists/
    └── requirements.md  # Quality validation checklist
```

### Source Code (repository root)

```text
DataSphere/
├── Themes/
│   └── TabStyles.xaml                         # Update Selected states of PillTabViewItemStyle
├── Views/
│   └── Pages/
│       └── DatabaseGroup/
│           ├── DatabasePage.xaml              # Update Row 1 inner workspace Grid Background
│           ├── ConnectViewControl.xaml        # Update Root Grid Background
│           └── DatabaseViewControl.xaml       # Update Root Grid Background
└── Controls/
    └── VirtualTable/
        └── VirtualTable.xaml                  # Update Root Grid Background
```

**Structure Decision**: Direct modification of existing presentation markup files. No new libraries, services, or models required.

---

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

*No violations. All 8 Constitution principles pass cleanly.*
