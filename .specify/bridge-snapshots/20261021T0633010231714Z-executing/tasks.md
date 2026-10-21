# Tasks: VirtualTable MVVM Command & Data Binding Architecture

**Input**: Design documents from `specs/009-virtual-table-mvvm-binding/` (`spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/`)

**Prerequisites**: `plan.md` (required), `spec.md` (required for user stories), `data-model.md`, `contracts/`

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify clean project build baseline prior to MVVM binding refactoring.

- [ ] T001 Verify project build baseline with 0 warnings and 0 errors via `dotnet build DataSphere/DataSphere.csproj -c Debug`.

---

## Phase 2: Foundational (Decoupled Adapter Model)

**Purpose**: Core model infrastructure that MUST be complete before View and ViewModel can be decoupled.

- [ ] T002 Extract `TableDataPageAdapter` from `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs` into a dedicated class in `DataSphere/Models/Database/TableDataPageAdapter.cs` implementing `IVirtualTableDataProvider` with full US English XML documentation comments.

**Checkpoint**: Foundation ready — user story implementation can now begin.

---

## Phase 3: User Story 1 - Declarative MVVM Command Binding on VirtualTable (Priority: P1) 🎯 MVP

**Goal**: Expose standard `ICommand` DependencyProperties (`SortCommand`, `CellEditedCommand`) on `VirtualTable` with dual dispatching (events + commands).

**Independent Test**: Can be tested by binding sample `ICommand` instances to `VirtualTable` in XAML and verifying that clicking a column header or committing a cell edit invokes the commands with strongly typed event arguments.

### Implementation for User Story 1

- [ ] T003 [US1] Register `SortCommand`, `SortCommandParameter`, `CellEditedCommand`, and `CellEditedCommandParameter` `DependencyProperty` definitions in `DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`.
- [ ] T004 [US1] Implement dual dispatching in `DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`: invoke `SortCommand` in `OnHeaderClicked()` and `CellEditedCommand` in `CommitCellEdit()` while preserving existing `Sorting` and `CellEdited` .NET event invocations.

**Checkpoint**: At this point, User Story 1 is fully functional and `VirtualTable` can be driven entirely through standard MVVM commands.

---

## Phase 4: User Story 2 - Observable DataProvider Binding & Decoupled Adapter in ViewModel (Priority: P1)

**Goal**: Wire `TableDataPageAdapter` and sorting/editing commands into `DataControlViewModel` so the ViewModel completely controls data presentation.

**Independent Test**: Can be tested by invoking ViewModel commands and verifying that `TableDataProvider` updates automatically upon page/sort transitions without View code-behind intervention.

### Implementation for User Story 2

- [ ] T005 [US2] Add `[ObservableProperty] private IVirtualTableDataProvider? _tableDataProvider;` to `DataSphere/ViewModels/Pages/DatabaseGroup/DataControlViewModel.cs`, updating it when `DataPage` loads or sort/primary key states change.
- [ ] T006 [US2] Add `[RelayCommand] private async Task SortAsync(VirtualTableSortEventArgs? e)` and `[RelayCommand] private void CellEdited(VirtualTableCellEditEventArgs? e)` to `DataSphere/ViewModels/Pages/DatabaseGroup/DataControlViewModel.cs`.

**Checkpoint**: At this point, `DataControlViewModel` completely exposes all data and commands required by `VirtualTable`.

---

## Phase 5: User Story 3 - Ultra-Thin View Code-Behind (Zero Business Logic) (Priority: P2)

**Goal**: Eliminate all event handlers, manual `PropertyChanged` subscriptions, and code-behind plumbing in `DataViewControl.xaml` and `DataViewControl.xaml.cs`.

**Independent Test**: Code inspection verifying `DataViewControl.xaml.cs` contains <35 lines of code (constructor + `IDisposable` only), and automated UI test verifying normal table interaction.

### Implementation for User Story 3

- [ ] T007 [US3] Update `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml` to bind `VirtualTable` properties via `{x:Bind ViewModel.TableDataProvider, Mode=OneWay}`, `{x:Bind ViewModel.SortCommand, Mode=OneWay}`, and `{x:Bind ViewModel.CellEditedCommand, Mode=OneWay}`.
- [ ] T008 [US3] Refactor `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs` to remove `TableDataPageAdapter`, `OnVirtualTableSorting`, `OnVirtualTableCellEdited`, `UpdateTableDataSource`, and `OnViewModelPropertyChanged`, reducing the file to <35 lines of pure lifecycle code.

**Checkpoint**: `DataViewControl.xaml.cs` is now 100% compliant with Constitution Principle I (Zero Business Logic in Code-Behind).

---

## Phase 6: User Story 4 - Reusable Library-Grade Control Architecture (Priority: P3)

**Goal**: Verify architectural decoupling of `VirtualTable` and enforce 100% US English XML doc comment standards.

**Independent Test**: Architecture audit verifying zero dependencies on database services or domain models in `DataSphere/Controls/VirtualTable/`.

### Implementation for User Story 4

- [ ] T009 [US4] Audit `DataSphere/Controls/VirtualTable/` to ensure 0 references to database namespaces (`DataSphere.Services.Database`, `DataSphere.Models.Database`) and 100% US English XML doc comments (Constitution Principle V).

---

## Phase 7: Polish & Verification

**Purpose**: Build verification and real desktop UI automation validation.

- [ ] T010 Compile project via `dotnet build DataSphere/DataSphere.csproj -c Debug` ensuring 0 warnings and 0 errors.
- [ ] T011 Create and execute automated UI verification script `scripts/verify-virtualtable-mvvm-binding.ps1` on `WinSta0\default` validating sorting, editing, and layout with DirectComposition screenshots.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 completion.
- **User Story 1 & 2 (Phase 3 & 4)**: Depend on Phase 2 completion. Can proceed in sequence.
- **User Story 3 (Phase 5)**: Depends on Phase 3 and Phase 4 completion (needs both control commands and ViewModel properties in place).
- **User Story 4 (Phase 6)**: Depends on Phase 5 completion.
- **Polish & Verification (Phase 7)**: Depends on all prior phases being complete.

---

## Implementation Strategy

### MVP First (Phases 1-5)
1. Complete Setup (T001) & Foundational (T002).
2. Implement `VirtualTable` commands (T003, T004).
3. Implement `DataControlViewModel` commands & provider (T005, T006).
4. Connect XAML and clean code-behind (T007, T008).
5. Verify build and desktop UI automation (T010, T011).
