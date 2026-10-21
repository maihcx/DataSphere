# Technical Research: Native CommunityToolkit DataGrid with Interactive Sorting

- **Feature**: `006-datagrid-table-view`
- **Date**: 2026-10-21
- **Status**: Complete

---

## 1. Control Library & Package Selection

### Decision
Utilize `CommunityToolkit.WinUI.UI.Controls.DataGrid` (Version 7.1.2) under namespace `CommunityToolkit.WinUI.UI.Controls`.

### Rationale
- The user explicitly requested integrating the Community Toolkit DataGrid per [Microsoft's DataGrid Group/Sort/Filter Documentation](https://learn.microsoft.com/en-us/windows/communitytoolkit/controls/datagrid_guidance/group_sort_filter#2-sorting).
- Provides first-class desktop table ergonomics: integrated column headers, sort direction indicators, resizable columns, grid lines, and native virtualization.
- Fully compatible with Windows App SDK 2.5+ and .NET 10 (`net10.0-windows10.0.26100.0`), compiling with 0 warnings and 0 errors.

### Alternatives Considered
- **Composite `ListView` + `ScrollViewer` (Current)**: Required manual horizontal scroll offset synchronization, suffered from placeholder grey boxes on fast drag, and lacked native column sorting indicators.
- **Third-Party Commercial Grids (Telerik, Syncfusion, DevExpress)**: Require commercial licenses, heavy runtime assemblies, and violate the project's zero-commercial-dependency baseline.

---

## 2. Dynamic Column Construction Pattern

### Decision
Dynamically construct `DataGridTextColumn` instances in `DataViewControl.xaml.cs` when `ViewModel.Columns` changes (or when `DataPage` updates), rather than relying solely on `AutoGenerateColumns="True"`.

### Rationale
- Database schemas are dynamic: a table might have 5 columns or 50 columns.
- `TableRowData` stores row records as `List<string> Cells` indexed by column ordinal. If `AutoGenerateColumns="True"` were used, the reflection engine would only see `RowIndex` and `Cells` (a list), unable to inspect individual schema fields.
- Programmatic column creation allows:
  1. Setting `Header` with column name and SQL type caption (`col.Name` and `col.DataType`).
  2. Setting `Binding = new Binding { Path = new PropertyPath($"Cells[{i}]"), Mode = BindingMode.OneWay }`.
  3. Setting `Tag = i` (the column ordinal) for direct $O(1)$ index access during sorting.
  4. Setting `CanUserSort = true` and `CanUserResize = true`.
  5. Configuring default widths (e.g., `DataGridLength.Auto` or `140px`).

### Alternatives Considered
- **`ExpandoObject` / Dynamic Dictionary rows**: Increases memory allocations and boxing overhead; slower than direct indexed access.
- **`AutoGeneratingColumn` event handling**: Still requires complex property extraction and custom template assignment; explicit column generation is cleaner and more deterministic.

---

## 3. Interactive Sorting Implementation Architecture

### Decision
Adhere strictly to [Microsoft's CommunityToolkit DataGrid Sorting Guidance](https://learn.microsoft.com/en-us/windows/communitytoolkit/controls/datagrid_guidance/group_sort_filter#2-sorting) combined with Clean MVVM:

```
[User clicks Column Header]
        │
        ▼
DataGrid.Sorting event (DataViewControl.xaml.cs)
        │
        ├─► Determine next direction: (null -> Ascending -> Descending -> null)
        ├─► Set e.Column.SortDirection
        ├─► Clear SortDirection on all other columns
        │
        ▼
ViewModel.SortByColumn(columnIndex, direction, dataType) (DataControlViewModel.cs)
        │
        ├─► If direction == null: Restore natural order (by RowIndex)
        ├─► If Ascending / Descending:
        │     Perform type-aware sort (int, double, DateTime, string)
        │     Handle NULL / empty string edge cases safely
        └─► Update DataPage.Rows
```

### Rationale
- **Clean MVVM Invariant (Constitution Principle I)**: The View captures UI events (`DataGrid.Sorting`) and updates UI visuals (`e.Column.SortDirection`), while delegating data sorting logic to the ViewModel.
- **Type-Aware Precision**: Lexicographical string sorting would incorrectly place `"10"` before `"2"`. By inspecting the column's SQL data type (`int`, `decimal`, `datetime`), the sorting algorithm parses values dynamically for correct natural ordering.
- **Reversible Sorting**: A 3-state toggle (Ascending ➔ Descending ➔ Natural) allows users to easily return to the database's original retrieved order without reloading the page.

---

## 4. Virtualization, Scrolling & Layout Decoupling

### Decision
1. Enable `EnableRowVirtualization="True"` and `EnableColumnVirtualization="True"` on `DataGrid`.
2. Remove the old `HeaderScrollViewer` and its manual scroll synchronization handler (`OnListViewChanged`) in `DataViewControl.xaml.cs`.
3. Set `GridLinesVisibility="All"`, `HeadersVisibility="Column"`, `IsReadOnly="True"`, and `SelectionMode="Extended"`.

### Rationale
- CommunityToolkit `DataGrid` manages its own internal scroll viewer, synchronizing headers and body columns at the compositor level.
- Eliminating manual scroll synchronization deletes ~50 lines of brittle code-behind and removes all potential cross-scroll lag or race conditions.
- Native column virtualization ensures that tables with 50+ columns remain performant without layout thrashing.
