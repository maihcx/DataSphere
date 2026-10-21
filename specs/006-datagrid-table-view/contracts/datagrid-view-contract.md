# Contract: CommunityToolkit DataGrid View & Sorting Interface

- **Feature**: `006-datagrid-table-view`
- **Date**: 2026-10-21
- **Status**: Complete

---

## 1. ViewModel Sorting Contract

`DataControlViewModel` exposes the sorting API to decouple business sorting logic from UI events:

```csharp
namespace DataSphere.ViewModels.Pages.DatabaseGroup
{
    public partial class DataControlViewModel : ObservableObject, IDisposable
    {
        /// <summary>
        /// Sorts the active page rows by the specified column and direction using type-aware comparisons.
        /// If direction is null, restores the original natural order of the page.
        /// </summary>
        /// <param name="columnIndex">The zero-based column index.</param>
        /// <param name="direction">The desired sort direction (Ascending, Descending, or null to clear).</param>
        /// <param name="dataType">The SQL data type of the column for type parsing.</param>
        public void SortByColumn(int columnIndex, CommunityToolkit.WinUI.UI.Controls.DataGridSortDirection? direction, string dataType);
    }
}
```

---

## 2. View XAML Contract (`DataViewControl.xaml`)

```xaml
<controls:DataGrid
    x:Name="TableDataGrid"
    Grid.Row="1"
    ItemsSource="{x:Bind ViewModel.DataPage.Rows, Mode=OneWay}"
    AutoGenerateColumns="False"
    CanUserSortColumns="True"
    CanUserResizeColumns="True"
    CanUserReorderColumns="False"
    IsReadOnly="True"
    SelectionMode="Extended"
    GridLinesVisibility="All"
    HeadersVisibility="Column"
    HorizontalScrollBarVisibility="Auto"
    VerticalScrollBarVisibility="Auto"
    Sorting="OnDataGridSorting">
    <!-- Columns populated dynamically from ViewModel.DataPage.Columns -->
</controls:DataGrid>
```

---

## 3. Dynamic Column Generation Contract

When `ViewModel.DataPage` is loaded or replaced:
1. `TableDataGrid.Columns.Clear()` is invoked.
2. For each `Column` in `DataPage.Columns`:
   - Instantiate `DataGridTextColumn`.
   - Set `Header` = `col.Name` (with `Caption` subtitle or custom header template showing `col.DataType`).
   - Set `Binding` = `new Binding { Path = new PropertyPath($"Cells[{i}]"), Mode = BindingMode.OneWay }`.
   - Set `Tag` = `i` (column index).
   - Set `CanUserSort` = `true`.
   - Set `CanUserResize` = `true`.
   - Set `Width` = `new DataGridLength(140)`.
   - Add to `TableDataGrid.Columns`.
