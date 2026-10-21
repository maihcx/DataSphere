# Feature Specification: VirtualTable MVVM Command & Data Binding Architecture

**Feature Branch**: `009-virtual-table-mvvm-binding`

**Created**: 2026-10-21

**Status**: Draft

**Input**: User description: "theo quy tắc hạn chế code behind thì DataViewControl.xaml.cs lẽ ra phải ít code nhưng bây giờ tôi thấy nó có quá nhiều code xử lý cho bảng. Thay vì dùng Sorting=OnVirtualTableSorting, CellEdited=OnVirtualTableCellEdited thì có cách nào dùng binding cho nó không? Ý tôi là cố gắng để phần xử lý cho control để dùng lại control đó tốt hơn, hoặc sau này tôi muốn tách control này thành lib thì cũng dễ hơn"

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Declarative MVVM Command Binding on VirtualTable (Priority: P1)

As a desktop application developer using `VirtualTable`, I want to bind `SortCommand` and `CellEditedCommand` directly in XAML using standard `ICommand` binding so that I do not have to write boilerplate event-handling methods in the View's code-behind (`*.xaml.cs`).

**Why this priority**: Eliminates code-behind event plumbing across all views consuming `VirtualTable`, adhering to Clean MVVM (Constitution Principle I) and paving the way for extracting `VirtualTable` into a standalone reusable UI library.

**Independent Test**: Can be independently tested by binding an `AsyncRelayCommand<VirtualTableSortEventArgs>` and a `RelayCommand<VirtualTableCellEditEventArgs>` to `VirtualTable` in XAML and verifying that clicking a column header or editing a cell dispatches execution directly to the ViewModel commands.

**Acceptance Scenarios**:

1. **Given** a `VirtualTable` instance with `SortCommand` bound to a ViewModel `ICommand`, **When** the user clicks any sortable column header, **Then** `VirtualTable` checks `SortCommand.CanExecute()` and invokes `SortCommand.Execute(args)` with the `VirtualTableSortEventArgs` payload.
2. **Given** a `VirtualTable` instance with `CellEditedCommand` bound to a ViewModel `ICommand`, **When** the user modifies a cell value and commits the edit (via Enter, click outside, or navigation), **Then** `VirtualTable` checks `CellEditedCommand.CanExecute()` and invokes `CellEditedCommand.Execute(args)` with the `VirtualTableCellEditEventArgs` payload.
3. **Given** a consumer utilizing standard .NET events (`Sorting`, `CellEdited`), **When** an action occurs, **Then** both the event is raised and the bound command is executed, preserving 100% backward compatibility for non-MVVM or code-behind consumers.

---

### User Story 2 - Observable DataProvider Binding & Decoupled Adapter (Priority: P1)

As a software architect, I want `VirtualTable.DataProvider` to be fully bindable via OneWay XAML binding from the ViewModel, and the database-specific data adapter (`TableDataPageAdapter`) to be encapsulated within the ViewModel/Model layer rather than embedded in View code-behind.

**Why this priority**: Removes over 80 lines of nested adapter classes and manual `PropertyChanged` event wiring from `DataViewControl.xaml.cs`, ensuring the View has zero knowledge of database pagination or adapter instantiation.

**Independent Test**: Can be tested by binding `DataProvider="{x:Bind ViewModel.TableDataProvider, Mode=OneWay}"` and verifying that switching pages, filtering data, or altering sort criteria automatically updates the table records without touching any code-behind methods.

**Acceptance Scenarios**:

1. **Given** `DataControlViewModel` with a loaded `TableDataPage`, **When** data is refreshed or page changes, **Then** `ViewModel.TableDataProvider` automatically updates and emits `PropertyChanged`, causing `VirtualTable` to re-render records via XAML binding.
2. **Given** a table with no primary keys, **When** `TableDataPage` is loaded, **Then** `ViewModel.TableDataProvider` provides read-only column configurations and disallows cell modification, without View code-behind intervention.

---

### User Story 3 - Ultra-Thin View Code-Behind (Zero Business Logic) (Priority: P2)

As a maintenance engineer, I want `DataViewControl.xaml.cs` to contain strictly zero business, event-routing, or data-adaptation logic, reducing its footprint from over 200 lines to a minimal lifecycle shell.

**Why this priority**: Guarantees strict compliance with Constitution Principle I (Zero Business Logic in Code-Behind) and prevents architectural regression during future feature additions.

**Independent Test**: Code inspection verifying `DataViewControl.xaml.cs` contains only the constructor and `IDisposable` delegation, with zero private event-handling methods, zero UI thread dispatcher calls, and zero nested classes.

**Acceptance Scenarios**:

1. **Given** `DataViewControl.xaml`, **When** inspecting its code-behind `DataViewControl.xaml.cs`, **Then** the file contains fewer than 35 lines of code, containing only constructor initialization and `IDisposable` disposal.
2. **Given** the application running on `WinSta0\default`, **When** the user loads a table, sorts columns, and edits cell values, **Then** all functionality operates identically to previous versions with zero regression.

---

### User Story 4 - Reusable Library-Grade Control Architecture (Priority: P3)

As a library author, I want `VirtualTable` to have zero dependencies on `DataSphere` business models or database engines so that the control can be compiled or packaged as a standalone WinUI 3 control library.

**Why this priority**: Enables code reuse across different projects and allows `VirtualTable` to serve as a general-purpose, high-performance virtualized grid for any structured dataset.

**Independent Test**: Verifying that `VirtualTable` project or namespace references only standard Windows App SDK and .NET runtime assemblies (`Microsoft.UI.Xaml`, `System.Windows.Input`, `System.Collections.ObjectModel`).

**Acceptance Scenarios**:

1. **Given** `DataSphere.Controls.VirtualTable`, **When** auditing project imports, **Then** the control references zero types from `DataSphere.Services`, `DataSphere.ViewModels`, or database connectors.

---

### Edge Cases

- **Null or Unbound Commands**: What happens when `SortCommand` or `CellEditedCommand` is null? The control safely skips command invocation and continues normal UI rendering without throwing `NullReferenceException`.
- **Command `CanExecute` Returning False**: What happens if `SortCommand.CanExecute(e)` returns `false`? The control does not execute the command, and header sort glyph is not updated to reflect an invalid sort state.
- **Async Execution Exceptions**: How does the control handle exceptions thrown inside asynchronous command execution? The command encapsulates async error handling inside the ViewModel using standard MVVM exception handling patterns, keeping the UI compositor uninterrupted.
- **Rapid Re-binding of DataProvider**: What happens if `DataProvider` is set to `null` while records are being rendered or edited? In-place editing is immediately committed or cancelled, pooled visual rows are safely collapsed, and extent is reset to zero.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `VirtualTable` MUST expose a DependencyProperty `SortCommand` of type `System.Windows.Input.ICommand` (default `null`).
- **FR-002**: `VirtualTable` MUST expose a DependencyProperty `SortCommandParameter` of type `object?` (default `null`), passing the parameter or defaulting to `VirtualTableSortEventArgs` when executed.
- **FR-003**: `VirtualTable` MUST expose a DependencyProperty `CellEditedCommand` of type `System.Windows.Input.ICommand` (default `null`).
- **FR-004**: `VirtualTable` MUST expose a DependencyProperty `CellEditedCommandParameter` of type `object?` (default `null`), passing the parameter or defaulting to `VirtualTableCellEditEventArgs` when executed.
- **FR-005**: When sorting occurs, `VirtualTable` MUST check `SortCommand?.CanExecute(args)` and execute `SortCommand?.Execute(args)`.
- **FR-006**: When cell editing is committed, `VirtualTable` MUST check `CellEditedCommand?.CanExecute(args)` and execute `CellEditedCommand?.Execute(args)`.
- **FR-007**: `VirtualTable` MUST maintain existing `Sorting` and `CellEdited` .NET routed/standard events alongside command execution.
- **FR-008**: `DataControlViewModel` MUST expose an observable property `IVirtualTableDataProvider? TableDataProvider` (or `DataProvider`) that encapsulates data adaptation for `TableDataPage`.
- **FR-009**: `DataControlViewModel` MUST expose `IRelayCommand<VirtualTableSortEventArgs>` for server-side column sorting.
- **FR-010**: `DataControlViewModel` MUST expose `IRelayCommand<VirtualTableCellEditEventArgs>` for cell modification change tracking.
- **FR-011**: `DataViewControl.xaml` MUST bind `VirtualTable` properties exclusively via declarative `{x:Bind}` syntax.
- **FR-012**: `DataViewControl.xaml.cs` MUST NOT contain `TableDataPageAdapter`, manual `PropertyChanged` event handlers, or sorting/editing event logic.
- **FR-013**: `VirtualTable` MUST remain 100% agnostic of application domain models and database connection services.

---

### Key Entities

- **`IVirtualTableDataProvider`**: Abstract data supplier interface exposing column metadata, row counts, and indexed cell accessors.
- **`VirtualTableSortEventArgs`**: Event/Command parameter carrying the clicked `VirtualTableColumn` and target `ColumnSortDirection`.
- **`VirtualTableCellEditEventArgs`**: Event/Command parameter carrying row index, column index, original value, and updated value.
- **`TableDataPageAdapter`**: Concrete implementation of `IVirtualTableDataProvider` bridging database page records into virtual table cells.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Lines of code in `DataViewControl.xaml.cs` is reduced by at least 75% (from 208 lines to under 40 lines).
- **SC-002**: Zero code-behind event handler methods (`OnVirtualTableSorting`, `OnVirtualTableCellEdited`, `UpdateTableDataSource`) in `DataViewControl.xaml.cs`.
- **SC-003**: 100% of column sorting and in-place cell editing interactions continue to function with zero functional or visual regressions.
- **SC-004**: `VirtualTable` compiles as an independent subsystem without referencing any business, ViewModel, or database namespaces.
- **SC-005**: C# compilation completes with 0 warnings and 0 errors under .NET 10 preview.
- **SC-006**: End-to-end desktop UI automation verification on `WinSta0\default` passes with photographic proof.

---

## Assumptions

- `VirtualTable` is designed for Windows App SDK (WinUI 3) Fluent Design environments.
- Commands adhere to the standard `System.Windows.Input.ICommand` contract supported by `CommunityToolkit.Mvvm`.
- ViewModel commands receive the strongly typed event arguments (`VirtualTableSortEventArgs`, `VirtualTableCellEditEventArgs`) as command parameters by default when no explicit parameter is configured.
- Existing performance metrics (60 FPS scrolling, sub-16ms compositor latency, pooled row recycling) will be strictly maintained with zero overhead introduced by command dispatching.
