# Implementation Plan: Data Table & Schema Tree UI Virtualization

**Branch**: `005-data-and-tree-virtualization` | **Date**: 2026-10-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/005-data-and-tree-virtualization/spec.md`

## Summary

Implement high-performance UI virtualization for the table data record viewport and schema explorer treeview in DataSphere. By eliminating unconstrained scroll containers and enforcing a two-tier virtualized grid architecture (outer horizontal scroll container + constrained vertical `ItemsStackPanel`), row and cell materialization is bounded to the visible viewport ($O(\text{viewport})$ instead of $O(N)$), restoring 60 FPS scrolling and decreasing memory overhead by >= 60% for tables with 1,000+ records. For the schema tree, pure POCO item modeling (`DatabaseTreeNode`) and guarded lazy realization ensure zero container recycling crashes (`0xC000027B`) across large database catalogs.

## Technical Context

**Language/Version**: C# (Language Version `preview`), .NET 10 (`net10.0-windows10.0.26100.0`)

**Primary Dependencies**: `Microsoft.WindowsAppSDK` (WinUI 3 Fluent Design 2, `ListView`, `TreeView`, `ScrollViewer`, `ItemsStackPanel`), `WinUIEx` 2.5+, `CommunityToolkit.Mvvm` 8.4+

**Storage**: MySQL / MariaDB via `MySqlConnector` (asynchronous, non-blocking connection pool)

**Testing**: Real Desktop UI Automation (`System.Windows.Automation`, Win32 `WinSta0\default`, `PW_RENDERFULLCONTENT` DirectComposition capture), C# Invariant Tests (`scratch/VerifyDatabaseView`)

**Target Platform**: Windows 11 / Windows 10 (64-bit desktop workstation)

**Project Type**: Desktop Client Application (Single-process architecture with Multi-Instance IPC)

**Performance Goals**: Solid 60 FPS frame rate (<16ms per frame) during active scrolling through 1,000+ records; initial viewport load time < 150ms; catalog schema expansion < 200ms

**Constraints**: Bounded visual memory overhead (< 30 MB for 1,000+ rows); 100% Clean MVVM decoupling; Zero hardcoded user-facing strings (dynamic i18n via `TranslationSource` / `.resx`); Zero `AutomationProperties.AutomationId` in production XAML

**Scale/Scope**: Data pages with up to 5,000 rows and 50+ columns; database servers hosting 50+ databases and 1,000+ schema objects

## Constitution Check

*GATE: Evaluated against DataSphere Constitution v1.5.0. Must pass before Phase 2 task generation.*

| Constitution Principle | Compliance Assessment | Gate Status |
|---|---|---|
| **Principle I: Clean MVVM & Type Safety** | Virtualization models (`TableRowData`, `DatabaseTreeNode`, `Column`, `TableDataPage`) are pure POCO classes. ViewModels remain completely UI-agnostic without references to visual controls (`FrameworkElement`, `Window`). | **PASS** |
| **Principle II: Modern Fluent UI / UX Standards** | Native WinUI 3 `ListView`, `TreeView`, and `ItemsStackPanel` controls preserve Fluent Design 2 visual aesthetics, system theme synchronization, and smooth DirectComposition scrolling. | **PASS** |
| **Principle III: Credential Protection** | No credential storage or connection parameters are touched; existing `PasswordEncryptor` and parameterized queries are preserved. | **PASS** |
| **Principle IV: Performance & Thread Stewardship** | Resolves the primary UI thread bottleneck by eliminating unconstrained visual tree instantiation. UI stays at 60 FPS; asynchronous data loading preserves `CancellationToken`. | **PASS** |
| **Principle V: English Technical Documentation** | 100% of all public/internal classes, methods, and properties contain standard US English XML doc comments (`/// <summary>`, `<param>`, `<returns>`). | **PASS** |
| **Principle VI: Spec-Driven Development** | Follows the full Spec-Kit + Superpowers pipeline through `speckit-superpowers-bridge`. | **PASS** |
| **Principle VII: Zero Hardcoded Strings & Dynamic i18n** | All column headers, empty state placeholders, and pagination descriptions use `TranslationSource` and `.resx` localization with verified UTF-8 without BOM encoding. | **PASS** |
| **Principle VIII: Zero-Speculation Live UI Verification Gate** | Delivery requires live execution of `scripts/verify-real-end-to-end.ps1` on `WinSta0\default`, verifying physical mouse click geometry, row/cell interaction, and capturing `PW_RENDERFULLCONTENT` screenshots. No speculative sign-off permitted. | **PASS** |

## Project Structure

### Documentation (this feature)

```text
specs/005-data-and-tree-virtualization/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output: WinUI 3 virtualization mechanics & two-tier architecture
├── data-model.md        # Phase 1 output: Data models, entities, and visual layout specifications
├── quickstart.md        # Phase 1 output: Developer verification guide & testing workflow
├── contracts/           # Phase 1 output: Architectural and behavioral contracts
│   ├── ITableViewportControl.md
│   └── ISchemaTreeVirtualization.md
└── checklists/
    └── requirements.md  # Spec quality checklist
```

### Source Code (repository root)

```text
DataSphere/
├── Models/
│   ├── TableDataPage.cs                      # Paginated data container & column layout metrics
│   ├── TableRowData.cs                       # Pure POCO immutable row representation
│   └── Database/
│       ├── Column.cs                         # Schema column layout definitions
│       └── DatabaseTreeNode.cs               # Pure POCO TreeView payload (Zero-UIElement invariant)
├── ViewModels/Pages/DatabaseGroup/
│   ├── DataControlViewModel.cs               # Driving ViewModel for paginated virtualized table viewport
│   └── DatabaseControlViewModel.cs           # Driving ViewModel for schema explorer session & locks
├── Views/Pages/DatabaseGroup/
│   ├── DataViewControl.xaml                  # Two-tier virtualized grid (Outer horizontal ScrollViewer + inner ListView)
│   ├── DataViewControl.xaml.cs               # Interaction events & disposable lifecycle
│   ├── DatabaseViewControl.xaml              # Virtualized SchemaTree with pure POCO ItemTemplate
│   └── DatabaseViewControl.xaml.cs           # Guarded lazy expansion & context menus
└── Helpers/
    └── Converters.cs                         # Type-safe NullToVisibilityConverter & NotNullToVisibilityConverter
```

## Implementation Phases

### Phase 0: Research & Feasibility (Completed)
- Diagnosed root cause of infinite-height measuring in `DataViewControl.xaml`.
- Designed two-tier virtualized grid architecture with synchronized horizontal scroll.
- Validated WinUI 3 `TreeView` container virtualization and POCO payload safety.
- Documented findings in [research.md](./research.md).

### Phase 1: Data Models, Contracts & Quickstart (Completed)
- Formalized `TableRowData`, `TableDataPage`, and `DatabaseTreeNode` specifications in [data-model.md](./data-model.md).
- Authored contracts for table viewport and schema tree virtualization in [contracts/](./contracts/).
- Provided automated testing procedures and verification blueprint in [quickstart.md](./quickstart.md).

### Phase 2: Implementation & Tasks (Next Step: `/speckit-tasks`)
- Task 1: Refactor `DataViewControl.xaml` to two-tier virtualized layout:
  - Constrain inner `ListView` height in a dedicated Grid row.
  - Wrap content in horizontal-only `ScrollViewer` (`VerticalScrollMode="Disabled"`).
  - Configure `ItemsStackPanel.CacheLength="2.0"` for smooth scrolling.
- Task 2: Ensure synchronized horizontal scrolling between column headers and rows.
- Task 3: Verify and fine-tune `DatabaseViewControl.xaml` treeview virtualization and lazy loading.
- Task 4: Expand unit test suite in `scratch/VerifyDatabaseView` covering layout constraints and virtualization flags.
- Task 5: Execute live desktop UI verification runner (`verify-real-end-to-end.ps1`) on `WinSta0\default`, capturing DirectComposition visual evidence.

## Complexity Tracking

No constitutional violations. All implementations adhere strictly to .NET 10, Windows App SDK, Clean MVVM, and Constitution v1.5.0 principles.
