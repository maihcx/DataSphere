using System;
using System.Collections.Generic;
using DataSphere.Controls.VirtualTable;

namespace DataSphere.Models.Database
{
    /// <summary>
    /// Adapter bridging a database <see cref="TableDataPage"/> into the high-performance <see cref="IVirtualTableDataProvider"/> interface.
    /// Provides column schema mapping, row count reporting, and cell read/write access for virtualized data presentation.
    /// </summary>
    public sealed class TableDataPageAdapter : IVirtualTableDataProvider
    {
        private readonly TableDataPage _page;
        private readonly bool _isEditable;
        private readonly List<VirtualTableColumn> _columns;

        /// <summary>
        /// Initializes a new instance of the <see cref="TableDataPageAdapter"/> class.
        /// </summary>
        /// <param name="page">The table data page holding records and column definitions.</param>
        /// <param name="isEditable">Whether primary keys exist on the table to allow row editing.</param>
        /// <param name="activeSort">The currently active column sort descriptor, if any.</param>
        public TableDataPageAdapter(TableDataPage page, bool isEditable, ColumnSortDescriptor? activeSort)
        {
            _page = page;
            _isEditable = isEditable;
            _columns = new List<VirtualTableColumn>();

            if (page?.Columns != null)
            {
                for (int i = 0; i < page.Columns.Count; i++)
                {
                    var col = page.Columns[i];
                    var dir = (activeSort != null && activeSort.ColumnIndex == i)
                        ? activeSort.Direction
                        : ColumnSortDirection.None;

                    _columns.Add(new VirtualTableColumn
                    {
                        Key = col.Name,
                        Header = col.Name,
                        DataType = col.DataType,
                        Width = 140.0,
                        MinWidth = 60.0,
                        CanSort = true,
                        CanResize = true,
                        IsReadOnly = !isEditable,
                        SortDirection = dir
                    });
                }
            }
        }

        /// <inheritdoc/>
        public int RowCount => _page?.Rows?.Count ?? 0;

        /// <inheritdoc/>
        public IReadOnlyList<VirtualTableColumn> Columns => _columns;

        /// <inheritdoc/>
        public string GetCellText(int rowIndex, int columnIndex)
        {
            if (_page?.Rows != null && rowIndex >= 0 && rowIndex < _page.Rows.Count)
            {
                var row = _page.Rows[rowIndex];
                if (row != null && columnIndex >= 0 && columnIndex < row.Cells.Count)
                {
                    return row.Cells[columnIndex]?.ToString() ?? string.Empty;
                }
            }
            return string.Empty;
        }

        /// <inheritdoc/>
        public void SetCellText(int rowIndex, int columnIndex, string value)
        {
            if (_page?.Rows != null && rowIndex >= 0 && rowIndex < _page.Rows.Count)
            {
                var row = _page.Rows[rowIndex];
                if (row != null && columnIndex >= 0 && columnIndex < row.Cells.Count)
                {
                    row.MarkCellModified(columnIndex, value);
                }
            }
        }

        /// <inheritdoc/>
        public bool IsCellEditable(int rowIndex, int columnIndex) => _isEditable;
    }
}
