using System;
using DataSphere.Models;

namespace DataSphere.Controls.VirtualTable
{
    /// <summary>
    /// Provides event data for the <see cref="VirtualTable.Sorting"/> event.
    /// </summary>
    public sealed class VirtualTableSortEventArgs : EventArgs
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="VirtualTableSortEventArgs"/> class.
        /// </summary>
        /// <param name="column">The column being sorted.</param>
        /// <param name="direction">The sort direction requested.</param>
        public VirtualTableSortEventArgs(VirtualTableColumn column, ColumnSortDirection direction)
        {
            Column = column ?? throw new ArgumentNullException(nameof(column));
            Direction = direction;
        }

        /// <summary>
        /// Gets the column on which sorting was triggered.
        /// </summary>
        public VirtualTableColumn Column { get; }

        /// <summary>
        /// Gets the requested sorting direction.
        /// </summary>
        public ColumnSortDirection Direction { get; }
    }

    /// <summary>
    /// Provides event data for the <see cref="VirtualTable.CellEdited"/> event.
    /// </summary>
    public sealed class VirtualTableCellEditEventArgs : EventArgs
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="VirtualTableCellEditEventArgs"/> class.
        /// </summary>
        /// <param name="rowIndex">The 0-based data row index.</param>
        /// <param name="columnIndex">The 0-based column index.</param>
        /// <param name="originalValue">The value of the cell before editing.</param>
        /// <param name="newValue">The updated value of the cell.</param>
        public VirtualTableCellEditEventArgs(int rowIndex, int columnIndex, string originalValue, string newValue)
        {
            RowIndex = rowIndex;
            ColumnIndex = columnIndex;
            OriginalValue = originalValue ?? string.Empty;
            NewValue = newValue ?? string.Empty;
        }

        /// <summary>
        /// Gets the 0-based data row index of the edited cell.
        /// </summary>
        public int RowIndex { get; }

        /// <summary>
        /// Gets the 0-based column index of the edited cell.
        /// </summary>
        public int ColumnIndex { get; }

        /// <summary>
        /// Gets the original text value of the cell prior to editing.
        /// </summary>
        public string OriginalValue { get; }

        /// <summary>
        /// Gets the newly committed text value of the cell.
        /// </summary>
        public string NewValue { get; }
    }
}
