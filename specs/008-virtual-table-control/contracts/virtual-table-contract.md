# Contract: VirtualTable Custom Control (`VirtualTable`)

**Feature**: `008-virtual-table-control`  
**Date**: 2026-10-21  

---

## 1. Control Public API Contract

```csharp
namespace DataSphere.Controls.VirtualTable
{
    /// <summary>
    /// Custom high-performance WinUI 3 tabular data control based on the TVirtualStringTree architecture.
    /// Uses fixed-pool row recycling and direct callbacks to achieve zero-allocation scrolling and instant rendering.
    /// </summary>
    public sealed partial class VirtualTable : Control
    {
        // Dependency Properties
        public static readonly DependencyProperty DataProviderProperty;
        public static readonly DependencyProperty RowHeightProperty;
        public static readonly DependencyProperty SelectedRowIndexProperty;
        public static readonly DependencyProperty SelectedColumnIndexProperty;

        /// <summary>
        /// Gets or sets the data provider driving on-demand cell display.
        /// </summary>
        public IVirtualTableDataProvider? DataProvider { get; set; }

        /// <summary>
        /// Gets or sets the height in device-independent pixels for each row (default = 32.0).
        /// </summary>
        public double RowHeight { get; set; }

        /// <summary>
        /// Gets or sets the currently selected 0-based data row index (-1 for no selection).
        /// </summary>
        public int SelectedRowIndex { get; set; }

        /// <summary>
        /// Gets or sets the currently selected 0-based column index (-1 for full row selection).
        /// </summary>
        public int SelectedColumnIndex { get; set; }

        /// <summary>
        /// Gets the observable collection of column definitions.
        /// </summary>
        public ObservableCollection<VirtualTableColumn> Columns { get; }

        /// <summary>
        /// Occurs when a column header is clicked to request sorting.
        /// </summary>
        public event EventHandler<VirtualTableSortEventArgs>? Sorting;

        /// <summary>
        /// Occurs when a cell edit has been committed in-place.
        /// </summary>
        public event EventHandler<VirtualTableCellEditEventArgs>? CellEdited;

        /// <summary>
        /// Forces an immediate visual refresh of all pooled row elements.
        /// </summary>
        public void Refresh();

        /// <summary>
        /// Scrolls the viewport smoothly to bring the specified data row into view.
        /// </summary>
        /// <param name="rowIndex">The 0-based data row index.</param>
        public void ScrollToRow(int rowIndex);
    }
}
```

---

## 2. XAML Usage Contract (`DataViewControl.xaml`)

```xml
<!-- Table Records Viewport via High-Performance VirtualTable Control -->
<Border Grid.Row="1" Background="{ThemeResource ApplicationPageBackgroundThemeBrush}">
    <vt:VirtualTable
        x:Name="TableView"
        RowHeight="34"
        Sorting="OnVirtualTableSorting"
        CellEdited="OnVirtualTableCellEdited" />
</Border>
```

---

## 3. DataViewControl Adapter Contract

In `DataViewControl.xaml.cs`:
```csharp
private class TableDataPageAdapter : IVirtualTableDataProvider
{
    private readonly TableDataPage _page;
    private readonly bool _isEditable;
    private readonly List<VirtualTableColumn> _columns;

    public int RowCount => _page?.Rows.Count ?? 0;
    public IReadOnlyList<VirtualTableColumn> Columns => _columns;

    public string GetCellText(int rowIndex, int columnIndex)
    {
        if (rowIndex >= 0 && rowIndex < _page.Rows.Count)
        {
            return _page.Rows[rowIndex][columnIndex];
        }
        return string.Empty;
    }

    public void SetCellText(int rowIndex, int columnIndex, string value)
    {
        if (rowIndex >= 0 && rowIndex < _page.Rows.Count)
        {
            _page.Rows[rowIndex].MarkCellModified(columnIndex, value);
        }
    }

    public bool IsCellEditable(int rowIndex, int columnIndex) => _isEditable;
}
```
