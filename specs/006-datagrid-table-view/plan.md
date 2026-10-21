# Implementation Plan: Native CommunityToolkit DataGrid with Interactive Sorting

**Branch**: `006-datagrid-table-view` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/006-datagrid-table-view/spec.md`

## Summary

Replace the composite `ScrollViewer` + `ListView` + nested `ItemsControl` in `DataViewControl` with the official Windows Community Toolkit `DataGrid` (`CommunityToolkit.WinUI.UI.Controls.DataGrid` v7.1.2) per Microsoft's sorting guidance. This enables integrated column headers, native sort glyph indicators (Ascending, Descending, Clear), type-aware in-memory sorting, interactive column resizing, standard grid lines, and high-performance row/column virtualization without manual scroll synchronization hacks.

## Technical Context

**Language/Version**: C# (LangVersion `preview`), .NET 10 (`net10.0-windows10.0.26100.0`), Windows App SDK 2.5.1
**Primary Dependencies**: `CommunityToolkit.WinUI.UI.Controls.DataGrid` (7.1.2), `CommunityToolkit.Mvvm` (8.4.2), `Microsoft.WindowsAppSDK` (2.5.1)
**Storage**: N/A (in-memory paginated slices retrieved via MySQL/MariaDB connections)
**Testing**: PowerShell UIAutomation scripts on `WinSta0\default`, DirectComposition window capture (`PW_RENDERFULLCONTENT`)
**Target Platform**: Windows 10/11 x64 desktop
**Project Type**: Windows Desktop Application (WinUI 3 / Modern Fluent Design 2)
**Performance Goals**: <250ms page load (100 rows x 15 columns), <100ms sort reorder, 60 FPS continuous vertical/horizontal scrolling
**Constraints**: Zero hardcoded user-facing strings (dynamic i18n via `TranslationSource`), Clean MVVM separation (UI events in View, sorting algorithm in ViewModel), 100% US English XML doc comments
**Scale/Scope**: Table views supporting up to 50+ columns and page sizes of 100, 500, 1000 rows

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principle I: Clean MVVM & Type Safety**: PASS. `DataGrid.Sorting` event is captured in View code-behind and immediately delegates to `ViewModel.SortByColumn`. ViewModel contains zero UI types.
- **Principle II: Modern Fluent UI / UX Standards**: PASS. DataGrid styling adheres to Fluent Design 2 with integrated grid lines, Segoe UI typography, and native sort direction glyphs.
- **Principle III: Secure Database Connection & Credential Protection**: PASS. No database credentials touched; operates exclusively on retrieved in-memory `TableDataPage` models.
- **Principle IV: High Performance & Thread Stewardship**: PASS. Leverages DataGrid's native row and column virtualization; in-memory sorting executes efficiently on loaded page slices without blocking UI thread.
- **Principle V: English Technical Documentation Standard**: PASS. 100% of newly added or modified methods and properties include standard US English XML doc comments.
- **Principle VI: Spec-Driven Development & Superpowers Discipline**: PASS. Proceeding through Spec-Kit plan phase before task generation and bridge handoff.
- **Principle VII: Zero Hardcoded User-Facing Strings & Dynamic Internationalization (i18n)**: PASS. All column captions, empty states, and pagination text use `TranslationSource` resource keys.
- **Principle VIII: Visual UI Reproduction & Verification Gate**: PASS. All sorting, resizing, and scrolling behaviors are verified on real desktop station `WinSta0\default` with DirectComposition screenshots.

## Project Structure

### Documentation (this feature)

```text
specs/006-datagrid-table-view/
├── spec.md              # Feature specification
├── plan.md              # This implementation plan
├── research.md          # Technical research & decisions (Phase 0)
├── data-model.md        # Entities, types, and sort strategy (Phase 1)
├── quickstart.md        # Validation scenarios & commands (Phase 1)
├── contracts/           # Interface and XAML contracts (Phase 1)
│   └── datagrid-view-contract.md
├── checklists/
│   └── requirements.md  # Quality checklist
└── tasks.md             # Sequential tasks (Phase 2 output via /speckit-tasks)
```

### Source Code (repository root)

```text
DataSphere/
├── DataSphere.csproj                                      # PackageReference: CommunityToolkit.WinUI.UI.Controls.DataGrid
├── Models/
│   └── TableDataPage.cs                                   # TableDataPage & TableRowData models
├── ViewModels/Pages/DatabaseGroup/
│   └── DataControlViewModel.cs                            # SortByColumn implementation & sort state management
├── Views/Pages/DatabaseGroup/
│   ├── DataViewControl.xaml                               # CommunityToolkit DataGrid replacement for ListView
│   └── DataViewControl.xaml.cs                            # Dynamic column generation & Sorting event dispatch
scripts/
└── verify-real-end-to-end.ps1                             # UI Automation test script for DataGrid sorting & resizing
```

## Planned Phases

### Phase 0: Outline & Research (Complete)
- Evaluated `CommunityToolkit.WinUI.UI.Controls.DataGrid` (7.1.2) compatibility with .NET 10 / Windows App SDK 2.5.1.
- Established dynamic programmatic column generation strategy with indexed bindings to `Cells[{i}]`.
- Formalized Clean MVVM sorting delegation pattern matching Microsoft guidance.
- Documented findings in [research.md](research.md).

### Phase 1: Design & Contracts (Complete)
- Defined data models and type-aware comparison rules in [data-model.md](data-model.md).
- Authored XAML and ViewModel sorting contracts in [contracts/datagrid-view-contract.md](contracts/datagrid-view-contract.md).
- Created step-by-step verification guide in [quickstart.md](quickstart.md).
- Validated constitutional invariants across all design artifacts.

### Phase 2: Tasks Breakdown (Next)
- Triggered via `/speckit-tasks` to generate ordered, dependency-tracked implementation tasks in `tasks.md`.
