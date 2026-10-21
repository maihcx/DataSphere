# Implementation Plan: High-Performance Data Pipeline, Server-Side Sorting, and In-Place Table Editor

**Branch**: `007-table-editor-and-query-pipeline` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/007-table-editor-and-query-pipeline/spec.md`

## Summary

Deliver a high-performance database table exploration and editing pipeline for DataSphere:
1. **Instant Query Cancellation**: Implement `CancellationToken` and server-side SQL command cancellation (`KILL QUERY`) to allow immediate table switching without blocking or connection starvation.
2. **High-Performance Pipeline**: Decouple row count calculation from initial record retrieval using dialect engine statistics (`TABLE_ROWS`), batch row allocations, and reuse `DataGrid` column definitions across page navigation.
3. **Cross-Database Server-Side SQL Sorting**: Introduce `IDatabaseDialect` with dialect-safe identifier quoting and parameterized `ORDER BY` execution across full table datasets.
4. **In-Place Grid Cell Editing & Viewport Toolbar Commit**: Enable direct cell editing on tables with primary keys, dirty state tracking, and Viewport Toolbar "Commit" and "Discard" actions powered by parameterized `UPDATE` statements.

## Technical Context

**Language/Version**: C# (LangVersion `preview`), .NET 10 (`net10.0-windows10.0.26100.0`), Windows App SDK 2.5.1  
**Primary Dependencies**: `CommunityToolkit.WinUI.UI.Controls.DataGrid` (7.1.2), `CommunityToolkit.Mvvm` (8.4.2), `MySqlConnector` (2.6.2), `Microsoft.WindowsAppSDK` (2.5.1)  
**Storage**: MySQL / MariaDB (via `MySqlConnector`), extensible via `IDatabaseDialect`  
**Testing**: PowerShell UIAutomation harness on `WinSta0\default`, DirectComposition window capture (`PW_RENDERFULLCONTENT`)  
**Target Platform**: Windows 10/11 x64 desktop  
**Project Type**: Windows Desktop Application (WinUI 3 / Clean MVVM)  
**Performance Goals**: $<50$ms table switch cancellation, $<150$ms initial 100-row render (regardless of total table size), $<200$ms server sort on 10k rows  
**Constraints**: Zero hardcoded user-facing strings (dynamic i18n via `TranslationSource`), Clean MVVM separation (UI events in View, domain orchestration in ViewModel), 100% US English XML doc comments  
**Scale/Scope**: Tables with 50+ columns and 1M+ rows  

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principle I: Clean MVVM & Type Safety**: PASS. View code-behind captures `DataGrid.Sorting` and `DataGrid.CellEditEnding` and delegates directly to ViewModel commands. ViewModel contains zero UI types.
- **Principle II: Modern Fluent UI / UX Standards**: PASS. Toolbar buttons use Segoe UI Fluent icons, tooltips, and theme-aware brushes.
- **Principle III: Secure Database Connection & Credential Protection**: PASS. All `UPDATE` queries use strictly parameterized `MySqlParameter` instances; column identifiers are safely escaped via dialect quoting.
- **Principle IV: High Performance & Thread Stewardship**: PASS. Query cancellation actively monitors `CancellationToken`; blocking `COUNT(*)` replaced with sub-millisecond metadata estimation.
- **Principle V: English Technical Documentation Standard**: PASS. 100% of newly added or modified methods and properties include standard US English XML doc comments.
- **Principle VI: Spec-Driven Development & Superpowers Discipline**: PASS. Proceeding through Spec-Kit plan phase before task generation and bridge handoff.
- **Principle VII: Zero Hardcoded User-Facing Strings & Dynamic i18n**: PASS. All toolbar buttons, notices, and tooltips are bound to `TranslationSource` via `.resx` resources.
- **Principle VIII: Visual UI Reproduction & Verification Gate**: PASS. All cancellation, sorting, and cell editing interactions are validated on `WinSta0\default` with DirectComposition screenshots.

## Project Structure

### Documentation (this feature)

```text
specs/007-table-editor-and-query-pipeline/
├── spec.md              # Feature specification
├── plan.md              # This implementation plan
├── research.md          # Technical research & decisions (Phase 0)
├── data-model.md        # Entities, types, and sequence flows (Phase 1)
├── quickstart.md        # Verification scenarios & commands (Phase 1)
├── contracts/           # Dialect and View contracts (Phase 1)
│   ├── dialect-contract.md
│   └── table-editor-contract.md
├── checklists/
│   └── requirements.md  # Quality checklist
└── tasks.md             # Sequential tasks (Phase 2 output via /speckit-tasks)
```

### Source Code (repository root)

```text
DataSphere/
├── Models/
│   └── TableDataPage.cs                                   # Enhanced TableRowData (dirty tracking) & TableDataPage
├── Resources/Locales/
│   ├── String.resx                                        # i18n keys for commit, discard, notices
│   ├── String.en.resx
│   └── String.vi.resx
├── Services/Database/
│   ├── Connection/
│   │   └── MySqlDatabaseConnection.cs                     # Integrated cancellation, batching, metadata row counts
│   ├── Dialect/                                           # NEW: Database dialect abstraction
│   │   ├── IDatabaseDialect.cs
│   │   └── MySqlDialect.cs
│   └── Interface/
│       └── IDatabaseConnection.cs                         # Extended with sort and update signatures
├── ViewModels/Pages/DatabaseGroup/
│   └── DataControlViewModel.cs                            # Commit/Discard commands, query cancellation, server sort
└── Views/Pages/DatabaseGroup/
    ├── DataViewControl.xaml                               # Toolbar Commit/Discard buttons, editable DataGrid
    └── DataViewControl.xaml.cs                            # Column recycling, CellEditEnding event dispatch
scripts/
└── verify-table-editor-real-desktop.ps1                   # UI Automation test script
```

## Planned Phases

### Phase 0: Outline & Research (Complete)
- Investigated `MySqlConnector` query cancellation protocol and `KILL QUERY` handling.
- Designed $O(1)$ row count estimation using MySQL `information_schema.TABLES.TABLE_ROWS`.
- Evaluated batching and column recycling strategies.
- Documented in [research.md](research.md).

### Phase 1: Design & Contracts (Complete)
- Defined `IDatabaseDialect` and `MySqlDialect` in [contracts/dialect-contract.md](contracts/dialect-contract.md).
- Designed in-place editing lifecycle, dirty state tracking, and Viewport Toolbar contracts in [contracts/table-editor-contract.md](contracts/table-editor-contract.md) and [data-model.md](data-model.md).
- Authored step-by-step verification plan in [quickstart.md](quickstart.md).
- Validated constitutional invariants.

### Phase 2: Tasks Breakdown (Next)
- Triggered via `/speckit-tasks` to generate ordered, dependency-tracked implementation tasks in `tasks.md`.
