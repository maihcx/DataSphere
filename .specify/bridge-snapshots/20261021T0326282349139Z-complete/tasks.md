# Tasks: High-Performance Data Pipeline, Server-Side Sorting, and In-Place Table Editor

**Input**: Design documents from `/specs/007-table-editor-and-query-pipeline/`  
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/)  

## Format: `- [ ] [TaskID] [P?] [Story?] Description with file path`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Maps to user stories from `spec.md` (`US1`, `US2`, `US3`, `US4`)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Resource localization and dialect interface infrastructure

- [x] T001 Add localization resource keys (`btn_commit_changes`, `btn_discard_changes`, `tooltip_commit_changes`, `tooltip_discard_changes`, `msg_commit_success`, `msg_no_primary_key_edit_disabled`, `dialog_uncommitted_changes_title`, `dialog_uncommitted_changes_message`) in UTF-8 without BOM to `DataSphere/Resources/Locales/String.resx`, `DataSphere/Resources/Locales/String.en.resx`, and `DataSphere/Resources/Locales/String.vi.resx`
- [x] T002 Create database dialect interface `IDatabaseDialect` in `DataSphere/Services/Database/Dialect/IDatabaseDialect.cs` defining `QuoteIdentifier`, `BuildSelectPageQuery`, `BuildUpdateRowQuery`, and `BuildRowCountEstimateQuery`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core dialect implementation, enhanced data models, and connection service contract extensions

- [x] T003 [P] Implement `MySqlDialect` in `DataSphere/Services/Database/Dialect/MySqlDialect.cs` with backtick identifier escaping, parameterized `LIMIT/OFFSET`, `ORDER BY` query building, and `TABLE_ROWS` estimation
- [x] T004 [P] Enhance `TableRowData` and `TableDataPage` models in `DataSphere/Models/TableDataPage.cs` with `OriginalCells` snapshot storage, `IsDirty`, `ModifiedColumnIndices`, `MarkCellModified`, `RevertChanges`, and `CommitChanges`
- [x] T005 Extend `IDatabaseConnection` in `DataSphere/Services/Database/Interface/IDatabaseConnection.cs` with updated signatures for `GetTableDataPageAsync` (accepting `ColumnSortDescriptor?` and `CancellationToken`) and new method `ExecuteUpdateRowsAsync`

**Checkpoint**: Core models and dialect abstractions ready — user story implementation can proceed.

---

## Phase 3: User Story 1 - Instant Table Switching & Fast Query Cancellation (Priority: P1) 🎯 MVP

**Goal**: Cancel active database queries immediately when switching tables or views to prevent UI freezing and connection starvation.

**Independent Test**: Rapidly click between multiple tables within 100ms; verify that prior queries abort cleanly via `CancellationToken` and the final table loads without delay.

- [x] T006 [US1] Update `DataControlViewModel` in `DataSphere/ViewModels/Pages/DatabaseGroup/DataControlViewModel.cs` to manage an active `CancellationTokenSource`, cancelling any in-flight task and SQL command when `LoadPageAsync` is invoked or when disposed
- [x] T007 [US1] Update `MySqlDatabaseConnection.GetTableDataPageAsync` in `DataSphere/Services/Database/Connection/MySqlDatabaseConnection.cs` to pass `CancellationToken` to `MySqlCommand.ExecuteReaderAsync` and handle `OperationCanceledException` gracefully without leaking connection state

**Checkpoint**: User Story 1 functional: In-flight table queries cancel immediately upon navigation.

---

## Phase 4: User Story 2 - High-Performance Table Loading & Non-Blocking Row Estimation (Priority: P1)

**Goal**: Accelerate initial table display to sub-150ms by replacing synchronous `SELECT COUNT(*)` with metadata row estimation and optimizing memory batching.

**Independent Test**: Open a table with $>50,000$ rows; verify first page displays in $<150$ms with estimated row count.

- [x] T008 [US2] Refactor `MySqlDatabaseConnection.GetTableDataPageAsync` in `DataSphere/Services/Database/Connection/MySqlDatabaseConnection.cs` to retrieve instant row count estimates via `MySqlDialect.BuildRowCountEstimateQuery` (`TABLE_ROWS`) and eliminate synchronous blocking `SELECT COUNT(*)`
- [x] T009 [US2] Optimize row data allocation in `MySqlDatabaseConnection.GetTableDataPageAsync` by pre-allocating `List<TableRowData>` and batch-populating `TableDataPage.Rows` to avoid per-row collection change notifications
- [x] T010 [US2] Implement column recycling in `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs` to skip `Columns.Clear()` and preserve existing `DataGridTextColumn` instances when navigating pages of the same table

**Checkpoint**: User Story 2 functional: Large tables load with instant sub-150ms responsiveness.

---

## Phase 5: User Story 3 - Cross-Database Server-Side SQL Sorting (Priority: P1)

**Goal**: Sort full table datasets on the database server using dialect-safe parameterized `ORDER BY` queries.

**Independent Test**: Click column header `id` to sort server-side Ascending; click again for Descending; verify true global sorting across pagination boundaries.

- [x] T011 [US3] Update `MySqlDatabaseConnection.GetTableDataPageAsync` in `DataSphere/Services/Database/Connection/MySqlDatabaseConnection.cs` to incorporate `sort` parameter using `MySqlDialect.BuildSelectPageQuery` with parameterized `ORDER BY`
- [x] T012 [US3] Implement `SortByServerColumnAsync` in `DataSphere/ViewModels/Pages/DatabaseGroup/DataControlViewModel.cs` to update `ActiveSort`, cycle 3 states (Ascending ➔ Descending ➔ Clear), and re-query page 1 from the database engine
- [x] T013 [US3] Update `OnDataGridSorting` in `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs` to delegate column header clicks to `ViewModel.SortByServerColumnAsync`

**Checkpoint**: User Story 3 functional: Server-side SQL sorting operates across the entire table dataset.

---

## Phase 6: User Story 4 - In-Place Grid Cell Editing & Viewport Toolbar Commit (Priority: P2)

**Goal**: Enable direct grid cell editing on tables with primary keys, dirty state tracking, and Viewport Toolbar "Commit" and "Discard" actions.

**Independent Test**: Double-click a cell to edit value, verify dirty highlighting and enabled toolbar buttons, click "Commit", and verify record is updated in the database.

- [x] T014 [US4] Implement `ExecuteUpdateRowsAsync` in `DataSphere/Services/Database/Connection/MySqlDatabaseConnection.cs` generating and executing parameterized `UPDATE` queries using `MySqlDialect.BuildUpdateRowQuery` within a database transaction
- [x] T015 [US4] Add `CommitChangesAsync` and `DiscardChanges` RelayCommands and `CanCommit`/`CanDiscard` properties in `DataSphere/ViewModels/Pages/DatabaseGroup/DataControlViewModel.cs`
- [x] T016 [US4] Add Commit and Discard buttons bound to `ViewModel.CommitChangesCommand` and `ViewModel.DiscardChangesCommand` in `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml`
- [x] T017 [US4] Configure `IsReadOnly="False"` on `TableDataGrid` and wire `CellEditEnding="OnDataGridCellEditEnding"` in `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs` to mark edited rows as dirty

**Checkpoint**: User Story 4 functional: In-place editing and Viewport Toolbar commit/discard are fully operational.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation compliance, compilation verification, and live desktop UI testing.

- [x] T018 [P] Verify 100% US English XML doc comments on all new and modified classes, interfaces, methods, and properties across `DataControlViewModel.cs`, `DataViewControl.xaml.cs`, `MySqlDatabaseConnection.cs`, and `MySqlDialect.cs`
- [x] T019 Validate clean compilation with `dotnet build DataSphere\DataSphere.csproj -c Debug` (0 Warnings, 0 Errors)
- [x] T020 Execute end-to-end automated UI verification on `WinSta0\default` via `scripts/verify-table-editor-real-desktop.ps1`, capturing DirectComposition screenshots of cancellation, server sorting, in-place editing, and commit

---

## Dependencies & Execution Order

### Phase Dependencies
- **Setup (Phase 1)**: Can start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1; blocks User Stories.
- **User Story 1 (Phase 3)**: Depends on Phase 2.
- **User Story 2 (Phase 4)**: Depends on Phase 2 & US1.
- **User Story 3 (Phase 5)**: Depends on Phase 2.
- **User Story 4 (Phase 6)**: Depends on Phase 2 & US2.
- **Polish (Phase 7)**: Depends on all user stories completed.

### Parallel Opportunities
- `T003` (MySqlDialect) and `T004` (enhanced models) can run in parallel.
- `T018` (XML docs) can run in parallel during Polish.

---

## Implementation Strategy

### MVP First (User Story 1 Only)
1. Complete Phase 1 (Setup) and Phase 2 (Foundational).
2. Complete Phase 3 (User Story 1 - Fast Cancellation).
3. Validate independent test: Fast table switching cancels prior queries cleanly.
4. Deliver MVP increment.

### Incremental Delivery
1. Add User Story 2 (High-Performance Loading) ➔ Test non-blocking row estimation independently.
2. Add User Story 3 (Server-Side SQL Sorting) ➔ Test SQL sorting independently.
3. Add User Story 4 (In-Place Editing & Commit) ➔ Test editing and commit independently.
4. Complete Polish (clean compilation, full live UI verification).
