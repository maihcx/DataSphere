# Tasks: High-Performance WinUI 3 VirtualTable Control (TVirtualStringTree Architecture)

**Input**: Design documents from `/specs/008-virtual-table-control/`  
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/)  

## Format: `- [ ] [TaskID] [P?] [Story?] Description with file path`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Maps to user stories from `spec.md` (`US1`, `US2`, `US3`, `US4`)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Control folder setup, data models, and event contracts

- [x] T001 Create control directory `DataSphere/Controls/VirtualTable/` and define event argument types `VirtualTableSortEventArgs` and `VirtualTableCellEditEventArgs` in `DataSphere/Controls/VirtualTable/VirtualTableEvents.cs`
- [x] T002 [P] Define `VirtualTableColumn` model in `DataSphere/Controls/VirtualTable/VirtualTableColumn.cs` with column width, header, sort direction, and data type properties
- [x] T003 [P] Define `IVirtualTableDataProvider` interface in `DataSphere/Controls/VirtualTable/IVirtualTableDataProvider.cs` specifying on-demand data delivery contracts (`RowCount`, `Columns`, `GetCellText`, `SetCellText`, `IsCellEditable`)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Visual row container and row pool recycling engine

- [x] T004 Implement visual row container `VirtualTableRow` in `DataSphere/Controls/VirtualTable/VirtualTableRow.cs` hosting recycled cell TextBlocks, hover/selected visual states, and crisp 1px gridlines
- [x] T005 Implement `VirtualTableRowPool` in `DataSphere/Controls/VirtualTable/VirtualTableRowPool.cs` managing the fixed pool of ~25 visual rows, calculating `PoolSize = (ViewportHeight / RowHeight) + 2`, and recycling rows during vertical scrolling without heap allocations

**Checkpoint**: Foundational row recycling engine ready — control layout and user story implementation can proceed.

---

## Phase 3: User Story 1 - Ultra-High-Performance Virtual Row Recycling Canvas (Priority: P1) 🎯 MVP

**Goal**: Render table records using a fixed pool of visual row elements with on-demand text callbacks, achieving zero-allocation 60+ FPS scrolling.

**Independent Test**: Load a 100,000-row table into `VirtualTable`; verify that only ~25 row containers exist in memory, scrolling operates smoothly at 60 FPS, and memory allocation during scroll is 0 bytes.

- [x] T006 [US1] Create `VirtualTable.xaml` in `DataSphere/Controls/VirtualTable/VirtualTable.xaml` with root layout: Row 0 HeaderCanvas, Row 1 ViewportBorder with VirtualCanvas, Vertical ScrollBar, and Horizontal ScrollBar
- [x] T007 [US1] Implement core virtualization engine in `DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`: row pool initialization, pointer wheel handling, vertical scrollbar synchronization, and zero-allocation recycling via `DataProvider.GetCellText`
- [x] T008 [US1] Implement `TableDataPageAdapter` in `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs` to bridge `TableDataPage` into `IVirtualTableDataProvider`
- [x] T009 [US1] Replace `CommunityToolkit.WinUI.UI.Controls.DataGrid` with `vt:VirtualTable` in `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml`

**Checkpoint**: User Story 1 functional: DataSphere displays table records using the ultra-fast `VirtualTable` control.

---

## Phase 4: User Story 2 - Fluent Design 2 Column Headers, Resizing & 3-State Sorting (Priority: P1)

**Goal**: Modern column headers with interactive drag-to-resize dividers and 3-state sorting indicators.

**Independent Test**: Drag a column divider to widen a column and observe smooth real-time cell resizing; click a header to verify 3-state sorting cycling (`↑`, `↓`, Clear).

- [x] T010 [US2] Implement column header rendering and dragging splitter resize logic in `DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs` to dynamically adjust column widths and synchronize cell widths in real time
- [x] T011 [US2] Implement 3-state sorting event dispatch in `DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`, rendering native sort arrow glyphs (Ascending `↑`, Descending `↓`, Clear) and firing `Sorting` event
- [x] T012 [US2] Wire `Sorting` event in `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs` to invoke `ViewModel.SortByServerColumnAsync`

**Checkpoint**: User Story 2 functional: Column resizing and visual 3-state sorting are fully operational.

---

## Phase 5: User Story 3 - Row/Cell Selection & Keyboard Navigation (Priority: P2)

**Goal**: Full arrow key navigation, row/cell hover highlights, and clipboard copying.

**Independent Test**: Navigate across cells with arrow keys; press Ctrl+C; paste into text editor to verify copied content.

- [x] T013 [US3] Implement pointer selection and row hover highlights in `DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs` using WinUI 3 Fluent Design brushes (`SubtleFillColorSecondaryBrush`, `ControlOnImageFillColorDefaultBrush`)
- [x] T014 [US3] Implement keyboard navigation in `DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs` supporting Up, Down, Left, Right, PageUp, PageDown, Home, End with automatic viewport scrolling
- [x] T015 [US3] Implement clipboard copying (`Ctrl+C`) in `DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs` to copy selected cell or row data to the Windows clipboard

**Checkpoint**: User Story 3 functional: Keyboard navigation, cell selection, and clipboard export work seamlessly.

---

## Phase 6: User Story 4 - In-Place Cell Editing with Overlay Editor (Priority: P2)

**Goal**: Double-click in-place `TextBox` overlay for direct cell editing with Enter to commit and Escape to cancel.

**Independent Test**: Double-click a cell; edit text; press Enter; verify cell updates and marks row as dirty; confirm toolbar Commit button enables.

- [x] T016 [US4] Add floating in-place `TextBox` overlay in `DataSphere/Controls/VirtualTable/VirtualTable.xaml` and implement double-click / Enter activation positioned precisely at cell coordinates in `DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`
- [x] T017 [US4] Implement commit (Enter / LostFocus) and cancel (Escape) logic for the in-place editor, firing `CellEdited` event and updating underlying row dirty state in `DataViewControl.xaml.cs`

**Checkpoint**: User Story 4 functional: In-place cell editing with toolbar commit integration is complete.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation compliance, compilation verification, and live desktop UI testing.

- [x] T018 [P] Verify 100% US English XML doc comments on all new and modified classes, interfaces, methods, and properties in `DataSphere/Controls/VirtualTable/`
- [x] T019 Validate clean compilation with `dotnet build DataSphere\DataSphere.csproj -c Debug` (0 Warnings, 0 Errors)
- [x] T020 Execute end-to-end automated UI verification on `WinSta0\default` via `scripts/verify-virtualtable-real-desktop.ps1`, capturing DirectComposition screenshots of initial rendering, fast scrolling, column resizing, server sorting, and in-place editing

---

## Dependencies & Execution Order

### Phase Dependencies
- **Setup (Phase 1)**: Can start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1; blocks User Stories.
- **User Story 1 (Phase 3)**: Depends on Phase 2.
- **User Story 2 (Phase 4)**: Depends on Phase 3 (needs VirtualTable canvas).
- **User Story 3 (Phase 5)**: Depends on Phase 3.
- **User Story 4 (Phase 6)**: Depends on Phase 3 & US2.
- **Polish (Phase 7)**: Depends on all user stories completed.

### Parallel Opportunities
- `T002` (VirtualTableColumn) and `T003` (IVirtualTableDataProvider) can run in parallel.
- `T018` (XML docs) can run in parallel during Polish.

---

## Implementation Strategy

### MVP First (User Story 1 Only)
1. Complete Phase 1 (Setup) and Phase 2 (Foundational row pool).
2. Complete Phase 3 (User Story 1 - VirtualTable canvas & adapter).
3. Validate independent test: Table renders instantly with ~25 pooled rows and zero-allocation scrolling.
4. Deliver MVP increment.

### Incremental Delivery
1. Add User Story 2 (Column resizing & 3-state sorting) ➔ Test independently.
2. Add User Story 3 (Selection & keyboard navigation) ➔ Test independently.
3. Add User Story 4 (In-place editing & toolbar commit) ➔ Test independently.
4. Complete Polish (clean build, full live verification on `WinSta0\default`).
