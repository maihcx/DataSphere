using System.Collections.Generic;

namespace DataSphere.Controls.VirtualTable
{
    /// <summary>
    /// Contract defining on-demand data delivery for the <see cref="VirtualTable"/> control.
    /// Eliminates per-cell reflection, boxing, and XAML data binding by serving text via index-based callbacks.
    /// </summary>
    public interface IVirtualTableDataProvider
    {
        /// <summary>
        /// Gets the total number of records available in the active dataset.
        /// </summary>
        int RowCount { get; }

        /// <summary>
        /// Gets the list of column definitions for the active dataset.
        /// </summary>
        IReadOnlyList<VirtualTableColumn> Columns { get; }

        /// <summary>
        /// Retrieves the formatted string display value for the specified cell coordinates.
        /// </summary>
        /// <param name="rowIndex">The 0-based data row index.</param>
        /// <param name="columnIndex">The 0-based column index.</param>
        /// <returns>The string representation of the cell value.</returns>
        string GetCellText(int rowIndex, int columnIndex);

        /// <summary>
        /// Updates the cell value at the specified coordinates.
        /// </summary>
        /// <param name="rowIndex">The 0-based data row index.</param>
        /// <param name="columnIndex">The 0-based column index.</param>
        /// <param name="value">The new text value to assign.</param>
        void SetCellText(int rowIndex, int columnIndex, string value);

        /// <summary>
        /// Determines whether the cell at the specified coordinates is editable in-place.
        /// </summary>
        /// <param name="rowIndex">The 0-based data row index.</param>
        /// <param name="columnIndex">The 0-based column index.</param>
        /// <returns><c>true</c> if the cell can be edited; otherwise, <c>false</c>.</returns>
        bool IsCellEditable(int rowIndex, int columnIndex);
    }
}
