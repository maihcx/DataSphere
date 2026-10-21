# Tasks: Native CommunityToolkit DataGrid with Interactive Sorting

**Input**: Design documents from `/specs/006-datagrid-table-view/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/datagrid-view-contract.md](contracts/datagrid-view-contract.md)

## Format: `- [ ] [TaskID] [P?] [Story?] Description with file path`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Maps to user stories from `spec.md` (`US1`, `US2`, `US3`, `US4`)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project dependency verification and XAML namespace registration

- [x] T001 Verify and configure `CommunityToolkit.WinUI.UI.Controls.DataGrid` (v7.1.2) dependency and XAML namespace in `DataSphere/DataSphere.csproj` and `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core data structures and type-aware sorting utilities that MUST be completed before UI wiring

- [x] T002 [P] Define `ColumnSortDescriptor` data model and sort direction representations in `DataSphere/Models/TableDataPage.cs`
- [x] T003 Implement type-aware value comparison utility (`CompareCellValues`) supporting integers, decimals, dates, and strings with null handling in `DataSphere/ViewModels/Pages/DatabaseGroup/DataControlViewModel.cs`

---

## Phase 3: User Story 1 - Native Tabular Data Presentation via DataGrid (Priority: P1) 🎯 MVP

**Goal**: Replace composite `ScrollViewer` + `ListView` + nested `ItemsControl` in `DataViewControl` with `controls:DataGrid`, auto-generating columns dynamically from `ViewModel.DataPage.Columns`.

**Independent Test**: Navigate to any table (e.g. `ngocthamcatalog.banggiada`), verify records render in native DataGrid with distinct headers, gridlines, and smooth virtualization.

- [x] T004 [US1] Replace composite `ScrollViewer` header and `ListView` with `CommunityToolkit.WinUI.UI.Controls.DataGrid` in `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml`
- [x] T005 [US1] Implement dynamic column generation logic in `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs` to instantiate `DataGridTextColumn` for each column in `DataPage.Columns` with indexed binding `Cells[{i}]` and schema metadata headers
- [x] T006 [US1] Bind `TableDataGrid.ItemsSource` to `ViewModel.DataPage.Rows` and wire data load change notifications in `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs`

**Checkpoint**: At this point, User Story 1 is functional: DataGrid renders all table rows and columns cleanly.

---

## Phase 4: User Story 2 - Interactive Column Header Sorting (Priority: P1)

**Goal**: Implement interactive 3-state column sorting on header clicks (Ascending ➔ Descending ➔ Clear) with visual glyphs matching Microsoft guidance.

**Independent Test**: Click column header `id` to sort Ascending (up arrow); click again to sort Descending (down arrow); click third time to restore natural order.

- [x] T007 [US2] Implement `SortByColumn(int columnIndex, DataGridSortDirection? direction, string dataType)` in `DataSphere/ViewModels/Pages/DatabaseGroup/DataControlViewModel.cs` to reorder `DataPage.Rows` in-place and support natural order restoration
- [x] T008 [US2] Wire `DataGrid.Sorting` event handler in `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs` to toggle `e.Column.SortDirection`, clear other columns' sort directions, and delegate sorting to `ViewModel.SortByColumn`

**Checkpoint**: At this point, User Stories 1 AND 2 are functional: DataGrid renders and sorts interactively.

---

## Phase 5: User Story 3 - Interactive Column Width Resizing & Layout Adaptation (Priority: P2)

**Goal**: Enable drag-to-resize on column headers and optimize width layout for wide tables.

**Independent Test**: Hover over column header divider and drag to resize column width fluidly without layout desynchronization.

- [x] T009 [US3] Configure `CanUserResizeColumns="True"`, horizontal scrollbar visibility, and default column widths (`DataGridLength`) in `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml` and `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs`

---

## Phase 6: User Story 4 - Cell Selection, Keyboard Navigation & Clipboard Export (Priority: P3)

**Goal**: Support arrow key cell navigation, extended row/cell selection, and clipboard copy.

**Independent Test**: Select cells with mouse or arrow keys, press Ctrl+C, paste into text editor to verify copied content.

- [x] T010 [US4] Configure `SelectionMode="Extended"`, `IsReadOnly="True"`, and keyboard navigation settings on `TableDataGrid` in `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml`

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Cleanup obsolete synchronization code, enforce documentation standards, and perform live UI verification.

- [x] T011 [P] Remove obsolete manual scroll synchronization methods (`AttachScrollSynchronization`, `DetachScrollSynchronization`, `OnListViewChanged`) from `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs`
- [x] T012 [P] Verify 100% US English XML doc comments on all new and modified methods across `DataControlViewModel.cs` and `DataViewControl.xaml.cs`
- [x] T013 Validate clean compilation with `dotnet build DataSphere\DataSphere.csproj -c Debug` (0 Warnings, 0 Errors)
- [x] T014 Execute end-to-end live UI verification on `WinSta0\default` via `scripts/verify-real-end-to-end.ps1`, capturing DirectComposition screenshots of DataGrid rendering, sorting, and resizing

---

## Dependencies & Execution Order

### Phase Dependencies
- **Setup (Phase 1)**: Can start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1; blocks User Stories.
- **User Story 1 (Phase 3)**: Depends on Phase 2.
- **User Story 2 (Phase 4)**: Depends on Phase 3 (needs DataGrid columns rendered).
- **User Story 3 (Phase 5)**: Depends on Phase 3.
- **User Story 4 (Phase 6)**: Depends on Phase 3.
- **Polish (Phase 7)**: Depends on all user stories completed.

### Parallel Opportunities
- Tasks `T002` (data model) and `T003` (comparison utility) can be developed in parallel.
- Tasks `T011` (cleanup) and `T012` (XML doc verification) can run in parallel during Polish.

---

## Implementation Strategy

### MVP First (User Story 1 Only)
1. Complete Phase 1 (Setup) and Phase 2 (Foundational).
2. Complete Phase 3 (User Story 1).
3. Validate independent test: DataGrid renders table data.
4. Deliver MVP increment.

### Incremental Delivery
1. Add User Story 2 (Sorting) ➔ Test sorting independently.
2. Add User Story 3 (Column resizing) ➔ Test resizing independently.
3. Add User Story 4 (Selection & keyboard navigation) ➔ Test navigation independently.
4. Complete Polish (clean up obsolete scroll code, full live verification).
