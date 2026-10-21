# Implementation Plan: High-Performance WinUI 3 VirtualTable Control (TVirtualStringTree Architecture)

**Branch**: `008-virtual-table-control` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/008-virtual-table-control/spec.md`

## Summary

Build a custom WinUI 3 control named `VirtualTable` under `DataSphere/Controls/VirtualTable/` that recreates the architectural philosophy of Delphi's `TVirtualStringTree`. It replaces the retained-mode `DataGrid` with a fixed-pool row recycling canvas (~25 row containers in total memory regardless of whether the table has 100 or 1,000,000 rows). It achieves zero-allocation 60+ FPS scrolling, on-demand text callbacks, interactive column resizing, 3-state sorting, and in-place cell editing with full WinUI 3 Fluent Design 2 aesthetic.

## Technical Context

**Language/Version**: C# (LangVersion `preview`), .NET 10 (`net10.0-windows10.0.26100.0`), Windows App SDK 2.5.1  
**Primary Dependencies**: `Microsoft.WindowsAppSDK` (2.5.1), `CommunityToolkit.Mvvm` (8.4.2), `WinUIEx` (2.9.3)  
**Storage**: N/A (in-memory paginated slices via `IDatabaseConnection`)  
**Testing**: PowerShell UIAutomation harness on `WinSta0\default`, DirectComposition window capture (`PW_RENDERFULLCONTENT`)  
**Target Platform**: Windows 10/11 x64 desktop  
**Project Type**: Custom WinUI 3 Desktop Control & Page Integration  
**Performance Goals**: $<50$ms initial render, 0 bytes allocated on managed heap during scroll, 60–120 FPS fluid scrolling, $<15$ MB viewport RAM  
**Constraints**: Zero hardcoded strings (dynamic i18n via `TranslationSource`), Clean MVVM separation, 100% US English XML doc comments  
**Scale/Scope**: Reusable control supporting up to 100+ columns and 1,000,000+ virtual rows  

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principle I: Clean MVVM & Type Safety**: PASS. `VirtualTable` is a standalone reusable control in `Controls/`; `DataViewControl` acts as the view adapter; `DataControlViewModel` remains 100% UI-agnostic with zero visual tree dependencies.
- **Principle II: Modern Fluent UI / UX Standards**: PASS. Custom headers, resize splitters, sort arrows, and row hover/selected brushes adhere to WinUI 3 Fluent Design 2 tokens.
- **Principle III: Secure Database Connection & Credential Protection**: PASS. Operates exclusively on retrieved row data; in-place editing executes via parameterized queries.
- **Principle IV: High Performance & Thread Stewardship**: PASS. Fixed-pool row recycling strictly limits visual elements to $\approx 25$ rows; 0 bytes heap allocation during scrolling.
- **Principle V: English Technical Documentation Standard**: PASS. 100% of newly added or modified methods and properties include standard US English XML doc comments.
- **Principle VI: Spec-Driven Development & Superpowers Discipline**: PASS. Proceeding through Spec-Kit plan phase before task generation and bridge handoff.
- **Principle VII: Zero Hardcoded User-Facing Strings & Dynamic i18n**: PASS. All empty state labels, tooltips, and status notices bind to `TranslationSource`.
- **Principle VIII: Visual UI Reproduction & Verification Gate**: PASS. All rendering, scrolling, sorting, and editing interactions are validated on `WinSta0\default` with DirectComposition screenshots.

## Project Structure

### Documentation (this feature)

```text
specs/008-virtual-table-control/
├── spec.md              # Feature specification
├── plan.md              # This implementation plan
├── research.md          # Technical research & decisions (Phase 0)
├── data-model.md        # Entities, architecture, and sequence flows (Phase 1)
├── quickstart.md        # Verification scenarios & commands (Phase 1)
├── contracts/           # Control and View contracts (Phase 1)
│   └── virtual-table-contract.md
├── checklists/
│   └── requirements.md  # Quality checklist
└── tasks.md             # Sequential tasks (Phase 2 output via /speckit-tasks)
```

### Source Code (repository root)

```text
DataSphere/
├── Controls/
│   └── VirtualTable/                                      # NEW: Custom VirtualTable component
│       ├── IVirtualTableDataProvider.cs                   # On-demand cell callback contract
│       ├── VirtualTableColumn.cs                          # Column model (width, sort, resize)
│       ├── VirtualTableRow.cs                            # Pooled visual row container
│       ├── VirtualTableRowPool.cs                        # Viewport row recycler & allocator
│       ├── VirtualTableEvents.cs                         # Sorting and CellEdited event args
│       ├── VirtualTable.xaml                             # XAML layout (Headers, Canvas, ScrollBars)
│       └── VirtualTable.xaml.cs                          # Pointer, scroll, resize, and edit logic
├── Views/Pages/DatabaseGroup/
│   ├── DataViewControl.xaml                              # Replace DataGrid with VirtualTable
│   └── DataViewControl.xaml.cs                           # IVirtualTableDataProvider adapter
scripts/
└── verify-virtualtable-real-desktop.ps1                  # UI Automation test script
```

## Planned Phases

### Phase 0: Outline & Research (Complete)
- Analyzed `TVirtualStringTree` callback and fixed-pool recycling architecture.
- Evaluated WinUI 3 compositor layout, scrollbar synchronization, and floating overlay editor.
- Documented in [research.md](research.md).

### Phase 1: Design & Contracts (Complete)
- Defined `IVirtualTableDataProvider`, `VirtualTableColumn`, and `VirtualTableRowPool` in [data-model.md](data-model.md).
- Authored control public API and XAML integration contracts in [contracts/virtual-table-contract.md](contracts/virtual-table-contract.md).
- Created step-by-step verification guide in [quickstart.md](quickstart.md).
- Validated constitutional invariants.

### Phase 2: Tasks Breakdown (Next)
- Triggered via `/speckit-tasks` to generate ordered, dependency-tracked implementation tasks in `tasks.md`.
