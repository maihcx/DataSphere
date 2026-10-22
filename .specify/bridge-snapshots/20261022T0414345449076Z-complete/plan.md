# Implementation Plan: Anchored Connection Tab in TabStripHeader & In-Page Tab Reordering for DatabasePage

**Branch**: `014-database-tabstrip-header` | **Date**: 2026-10-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/014-database-tabstrip-header/spec.md`

## Summary

Apply the architectural pattern established in Feature 013 (`ShellWindow`) to `DatabasePage`'s inner workspace: anchor the permanent Connection catalog tab into `<TabView.TabStripHeader>` on `InnerTabView` at the leftmost position, isolating it from the dynamic tab collection (`InnerTabs`). Update the Connection tab's icon to the dedicated Segoe Fluent Icon glyph `\uE703` ("Connect"), replacing `\uE774`. Enable fluid horizontal tab reordering (`CanReorderTabs="True"`) for open database session tabs within the inner tab strip while strictly bounding drag interactions inside the page (`CanDragTabs="False"`, 0 external windows spawned). Decouple selection state in `DatabaseViewModel` with mutual exclusion between `IsConnectionSelected` and `SelectedInnerTab`, ensuring automatic fallback to the Connection catalog when all dynamic tabs are closed.

## Technical Context

**Language/Version**: C# (LangVersion `preview`), .NET 10 (`net10.0-windows10.0.26100.0`), Windows App SDK (WinUI 3).

**Primary Dependencies**: `Microsoft.WindowsAppSDK` (`TabView`, `TabViewItem`, `ThemeResource`), `WinUIEx`, `CommunityToolkit.Mvvm` v8.4+.

**Storage**: N/A (Presentation and UI workspace state management only).

**Testing**: Windows UI Automation on interactive desktop (`WinSta0\default`), DirectComposition screen capture (`PW_RENDERFULLCONTENT`), physical mouse dispatch (`SetCursorPos`/`mouse_event`), and zero-warning compilation.

**Target Platform**: Windows 10 build 1809+ / Windows 11 desktop (x64 / ARM64).

**Project Type**: Desktop DBMS Client Application (Windows App SDK / WinUI 3).

**Performance Goals**: In-page tab reordering and viewport switching execute in <16ms (fluid 60 FPS).

**Constraints**:
- **Clean MVVM**: `DatabaseViewModel` remains 100% UI-agnostic without visual tree references.
- **Layout Decoupling Mandate (Principle VII)**: Viewport `ContentControl` remains decoupled in Grid Row 1, NOT placed inside `<TabView>` tags.
- **Zero-AutomationId Invariant**: Production XAML remains clean; UI automation locates elements via structural geometry, control types, and localized content matching.
- **Zero-Speculation Gate (Principle VIII)**: Live verification on `WinSta0\default` with DirectComposition screenshots required before handoff.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Requirement | Plan Alignment | Status |
|---|---|---|---|
| **Principle I: Clean MVVM & Type Safety** | ViewModels UI-agnostic; no visual tree coupling | `DatabaseViewModel` coordinates state (`ConnectionTab`, `InnerTabs`, `IsConnectionSelected`, `SelectedInnerTab`) using source generators without referencing UI controls. View handles layout binding. | **PASS** |
| **Principle II: Modern Fluent UI / UX Standards** | Fluent Design 2, modern controls, capsule tabs | Anchored pill tab in `TabStripHeader`, shared `Themes/TabStyles.xaml`, uniform card background in `DatabasePage`. | **PASS** |
| **Principle III: Secure Database Connection & Credential Protection** | Credential encryption, no plaintext leaks | No sensitive credentials or queries altered by tab navigation structure. | **PASS** |
| **Principle IV: High Performance & Thread Stewardship** | 60 FPS responsiveness, async execution | Tab switching uses lightweight binding; all operations execute without UI thread stalls. | **PASS** |
| **Principle V: English Technical Documentation Standard** | 100% US English XML doc comments | All new and modified classes, methods, properties, and RelayCommands documented in technical US English. | **PASS** |
| **Principle VI: Spec-Driven Development & Superpowers Discipline** | Spec-Kit + Superpowers discipline | Full SDD workflow: specify -> plan -> tasks -> bridge execute -> converge. | **PASS** |
| **Principle VII: Zero Hardcoded Strings & Decoupled Layout** | Zero hardcoded strings; TabView viewport decoupled | Connection tab title bound dynamically to `tab_connections_header`; viewport decoupled in Grid Row 1. | **PASS** |
| **Principle VIII: Visual UI Reproduction & Verification Gate** | Live UI testing on `WinSta0\default`, DirectComposition screenshots | Automated UI test script executes end-to-end scenarios on real desktop with genuine screen captures. | **PASS** |

## Project Structure

### Documentation (this feature)

```text
specs/014-database-tabstrip-header/
├── spec.md              # Feature specification & user scenarios
├── plan.md              # Implementation plan (this file)
├── research.md          # Architecture research & technical decisions
├── data-model.md        # Component model & state transitions
├── quickstart.md        # Runnable validation scenarios
├── contracts/
│   └── database-tabstrip-contract.md # XAML layout, ViewModel, and Theme contracts
└── checklists/
    └── requirements.md  # Quality validation checklist
```

### Source Code (repository root)

```text
DataSphere/
├── ViewModels/
│   └── Pages/
│       └── DatabaseGroup/
│           └── DatabaseViewModel.cs             # [MODIFIED] Manages ConnectionTab, IsConnectionSelected, dynamic InnerTabs
└── Views/
    └── Pages/
        └── DatabaseGroup/
            ├── DatabasePage.xaml                # [MODIFIED] InnerTabView TabStripHeader hosts ConnectionTab, CanReorderTabs=True, CanDragTabs=False
            └── DatabasePage.xaml.cs             # [MODIFIED] Wire Connection tab tap event, selection desynchronization guard
```

**Structure Decision**: Reuses the proven architecture from Feature 013 (`ShellWindow`), keeping `DatabaseViewModel` decoupled and clean while updating `DatabasePage.xaml` to leverage `InnerTabView.TabStripHeader`.

## Implementation Phases

### Phase 0: Outline & Research
- Completed and documented in [research.md](./research.md).
- Researched `TabView.TabStripHeader` hosting of `TabViewItem` with `PillTabViewItemStyle` in `DatabasePage`.
- Designed decoupled state management in `DatabaseViewModel` for `ConnectionTab` vs dynamic `InnerTabs`.
- Evaluated `CanReorderTabs="True"` and `CanDragTabs="False"` for in-page containment.
- Selected `\uE703` ("Connect") for connection catalog and `\uE8B7` ("Database") for database sessions.

### Phase 1: Design & Contracts
- Completed and documented in [data-model.md](./data-model.md), [contracts/database-tabstrip-contract.md](./contracts/database-tabstrip-contract.md), and [quickstart.md](./quickstart.md).
- Re-evaluated Constitution Check: **All 8 Principles PASS**.

## Complexity Tracking

| Component | Inherent Complexity | Justification |
|---|---|---|
| `DatabaseViewModel` Decoupled State | Low | Follows identical proven pattern from `ShellViewModel`. Minimal risk. |
| `InnerTabView.TabStripHeader` | Low | Uses existing `PillTabViewItemStyle` from `Themes/TabStyles.xaml`. |
| `CanReorderTabs="True"` | Low | Native WinUI 3 control capability for `TabView`. |
