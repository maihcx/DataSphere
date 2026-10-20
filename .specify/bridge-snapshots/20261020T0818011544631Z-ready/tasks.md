---
description: "Task list for Data Table & Schema Tree UI Virtualization"
---

# Tasks: Data Table & Schema Tree UI Virtualization

**Input**: Design documents from `/specs/005-data-and-tree-virtualization/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup & Baseline Infrastructure

**Purpose**: Verify clean build baseline and initialize testing harness

- [ ] T001 Verify project compilation baseline via `dotnet build DataSphere\DataSphere.csproj -c Debug` with 0 warnings and 0 errors
- [ ] T002 [P] Extend verification suite in `scratch/VerifyDatabaseView/Program.cs` with virtualization and layout assertions

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core model properties and invariants required before UI virtualization refactoring

- [ ] T003 [P] Add `TotalTableWidth` calculation and column metrics to `DataSphere/Models/TableDataPage.cs`
- [ ] T004 [P] Validate pure POCO contracts in `DataSphere/Models/Database/DatabaseTreeNode.cs` and `DataSphere/Models/TableRowData.cs`

**Checkpoint**: Foundation ready - UI virtualization implementation can proceed

---

## Phase 3: User Story 1 - High-Performance Virtualized Table Record Browsing (Priority: P1) 🎯 MVP

**Goal**: Restore true row virtualization in `DataViewControl.xaml` by constraining `ListView` in a dedicated Grid row with `ItemsStackPanel`, materializing only visible rows at 60 FPS.

**Independent Test**: Load a table with 1,000 records on the active page, scroll through rows rapidly using mouse wheel. Frame rate must maintain 60 FPS with bounded memory.

- [ ] T005 [US1] Refactor `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml` into a two-tier virtualized grid: remove outer vertical `ScrollViewer` and place `ListView` directly in constrained `Grid.Row="1"` with `ItemsStackPanel.CacheLength="2.0"`
- [ ] T006 [US1] Preserve row selection (`SelectionMode="Single"`) and cell text selection (`IsTextSelectionEnabled="True"`) on virtualized item containers in `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml`
- [ ] T007 [US1] Verify table virtualization layout hierarchy assertions pass in `scratch/VerifyDatabaseView/Program.cs`

**Checkpoint**: User Story 1 functional and independently testable

---

## Phase 4: User Story 2 - Smooth Virtualized Schema Tree for Extensive Catalogs (Priority: P2)

**Goal**: Ensure `TreeView` in `DatabaseViewControl.xaml` leverages virtualization efficiently for extensive database catalogs with zero container recycling crashes (`0xC000027B`).

**Independent Test**: Expand schemas with hundreds of tables, scroll through tree nodes rapidly, and verify zero crashes, no duplicate nodes, and smooth scrolling.

- [ ] T008 [US2] Verify and fine-tune `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml` schema tree `ItemsStackPanel` cache and container recycling properties
- [ ] T009 [US2] Review and verify `DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseControlViewModel.cs` asynchronous lazy expansion and `_loadingDatabases` lock
- [ ] T010 [US2] Verify treeview virtualization and pure POCO payload assertions pass in `scratch/VerifyDatabaseView/Program.cs`

**Checkpoint**: User Stories 1 AND 2 both functional and independently testable

---

## Phase 5: User Story 3 - Synchronized Column Layout & Horizontal Virtualization (Priority: P3)

**Goal**: Synchronize column header and data row scrolling across tables with many columns (30+ fields) with zero offset drift.

**Independent Test**: Open a wide table with 20+ columns, scroll horizontally, and verify column headers and row cells stay aligned with zero drift.

- [ ] T011 [US3] Wrap table header bar and virtualized `ListView` inside an outer horizontal-only `ScrollViewer` (`HorizontalScrollBarVisibility="Auto"`, `VerticalScrollBarVisibility="Disabled"`) in `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml`
- [ ] T012 [US3] Verify horizontal synchronized scrolling and column width alignment assertions pass in `scratch/VerifyDatabaseView/Program.cs`

**Checkpoint**: All user stories functional and independently testable

---

## Phase 6: Polish, Verification Gate & Live Desktop Testing

**Purpose**: Verification against Constitution v1.5.0 gates and live desktop execution

- [ ] T013 Verify clean project compilation with 0 warnings and 0 errors via `dotnet build DataSphere\DataSphere.csproj -c Debug`
- [ ] T014 Execute full automated regression suite via `dotnet run --project scratch\VerifyDatabaseView\VerifyDatabaseView.csproj` (all assertions pass)
- [ ] T015 Execute live end-to-end desktop automation script `scripts/verify-real-end-to-end.ps1` on `WinSta0\default` to physically verify table selection, row/cell interaction, and 10 stress cycles with DirectComposition screen capture
- [ ] T016 Verify adherence to Constitution v1.5.0 **Zero-Speculation Live UI Verification Gate** with visual artifacts embedded in test report

---

## Dependencies & Execution Order

### Phase Dependencies
- **Phase 1 (Setup)**: Baseline check, can start immediately.
- **Phase 2 (Foundational)**: Depends on Phase 1 - BLOCKS all User Stories.
- **Phase 3 (User Story 1 - P1)**: Core table virtualization MVP.
- **Phase 4 (User Story 2 - P2)**: Schema treeview virtualization.
- **Phase 5 (User Story 3 - P3)**: Synchronized horizontal column layout.
- **Phase 6 (Polish & Verification)**: Final end-to-end testing gate on `WinSta0\default`.

### Implementation Strategy
1. **MVP First**: Complete Phase 1, Phase 2, and Phase 3 (User Story 1 - Table Viewport Virtualization).
2. **Incremental Delivery**: Add Phase 4 (TreeView Virtualization) and Phase 5 (Horizontal Scroll Synchronization).
3. **Zero-Speculation Verification**: Phase 6 executes real-desktop automation on `WinSta0\default` with DirectComposition capture before any handoff.
