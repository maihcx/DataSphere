using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using DataSphere.Models.Database;

namespace DataSphere.Models
{
    /// <summary>
    /// Represents a paginated slice of table records retrieved from the database engine.
    /// </summary>
    public partial class TableDataPage : ObservableObject
    {
        /// <summary>
        /// Gets or sets the 1-based index of the currently displayed page.
        /// </summary>
        [ObservableProperty]
        public partial int CurrentPage { get; set; } = 1;

        /// <summary>
        /// Gets or sets the maximum number of rows retrieved per page (e.g. 100, 500, 1000).
        /// </summary>
        [ObservableProperty]
        public partial int PageSize { get; set; } = 100;

        /// <summary>
        /// Gets or sets the total number of records available in the queried table.
        /// </summary>
        [ObservableProperty]
        public partial long TotalRecords { get; set; }

        /// <summary>
        /// Gets or sets a value indicating whether the total record count is an engine-level estimate.
        /// </summary>
        [ObservableProperty]
        public partial bool IsEstimatedTotal { get; set; }

        /// <summary>
        /// Gets the total number of pages based on total records and page size.
        /// </summary>
        public int TotalPages => (int)Math.Ceiling((double)TotalRecords / Math.Max(1, PageSize));

        /// <summary>
        /// Gets the collection of column metadata definitions for the queried table.
        /// </summary>
        public ObservableCollection<Column> Columns { get; init; } = new();

        /// <summary>
        /// Gets the total calculated horizontal table width required to display all columns with spacing.
        /// </summary>
        public double TotalTableWidth => Math.Max(600, Columns.Count * (140 + 8) + 16);

        /// <summary>
        /// Gets the collection of row records retrieved for the current page slice.
        /// </summary>
        public ObservableCollection<TableRowData> Rows { get; init; } = new();

        /// <summary>
        /// Gets a value indicating whether any row in the current page contains uncommitted modifications.
        /// </summary>
        public bool HasDirtyRows => Rows.Any(r => r.IsDirty);
    }

    /// <summary>
    /// Represents an individual row record containing formatted string cells, original snapshot, and dirty state tracking.
    /// </summary>
    public class TableRowData
    {
        /// <summary>
        /// Gets or sets the sequential 1-based row index for visual display.
        /// </summary>
        public int RowIndex { get; set; }

        /// <summary>
        /// Gets or sets the ordered list of active cell values for this row.
        /// </summary>
        public List<string> Cells { get; set; } = new();

        /// <summary>
        /// Gets or sets the baseline cell values as retrieved from the database before any in-place modifications.
        /// </summary>
        public List<string> OriginalCells { get; set; } = new();

        /// <summary>
        /// Gets or sets a value indicating whether this row has uncommitted in-place modifications.
        /// </summary>
        public bool IsDirty { get; set; }

        /// <summary>
        /// Gets the collection of zero-based column indices that have been modified.
        /// </summary>
        public HashSet<int> ModifiedColumnIndices { get; } = new();

        /// <summary>
        /// Gets the formatted value of the cell at the specified column index.
        /// </summary>
        /// <param name="index">The zero-based column index.</param>
        /// <returns>The string representation of the cell value, or empty if index out of range.</returns>
        public string this[int index]
        {
            get
            {
                if (index >= 0 && index < Cells.Count)
                {
                    return Cells[index];
                }
                return string.Empty;
            }
        }

        /// <summary>
        /// Updates the cell value at the specified column index and updates the row's dirty state.
        /// </summary>
        /// <param name="columnIndex">The zero-based column index.</param>
        /// <param name="newValue">The updated cell value.</param>
        public void MarkCellModified(int columnIndex, string newValue)
        {
            if (columnIndex >= 0 && columnIndex < Cells.Count)
            {
                Cells[columnIndex] = newValue;
                string original = columnIndex < OriginalCells.Count ? OriginalCells[columnIndex] : string.Empty;
                if (!string.Equals(original, newValue, StringComparison.Ordinal))
                {
                    ModifiedColumnIndices.Add(columnIndex);
                    IsDirty = true;
                }
                else
                {
                    ModifiedColumnIndices.Remove(columnIndex);
                    IsDirty = ModifiedColumnIndices.Count > 0;
                }
            }
        }

        /// <summary>
        /// Reverts all active cell modifications back to their baseline database snapshot values.
        /// </summary>
        public void RevertChanges()
        {
            for (int i = 0; i < Math.Min(Cells.Count, OriginalCells.Count); i++)
            {
                Cells[i] = OriginalCells[i];
            }
            ModifiedColumnIndices.Clear();
            IsDirty = false;
        }

        /// <summary>
        /// Commits the active cell modifications into the baseline snapshot and clears the dirty flag.
        /// </summary>
        public void CommitChanges()
        {
            OriginalCells = Cells.ToList();
            ModifiedColumnIndices.Clear();
            IsDirty = false;
        }
    }

    /// <summary>
    /// Encapsulates a pending row update targeting the database engine.
    /// </summary>
    /// <param name="Row">The reference row data.</param>
    /// <param name="ChangedColumns">Dictionary mapping modified column names to their new values.</param>
    /// <param name="PrimaryKeyValues">Dictionary mapping primary key column names to their original values.</param>
    public record PendingRowUpdate(TableRowData Row, IReadOnlyDictionary<string, string> ChangedColumns, IReadOnlyDictionary<string, string> PrimaryKeyValues);

    /// <summary>
    /// Specifies the sort direction applied to a column in a tabular dataset.
    /// </summary>
    public enum ColumnSortDirection
    {
        /// <summary>
        /// No sorting applied; records preserve their natural retrieval order.
        /// </summary>
        None,

        /// <summary>
        /// Sort values in ascending order (smallest to largest, A to Z).
        /// </summary>
        Ascending,

        /// <summary>
        /// Sort values in descending order (largest to smallest, Z to A).
        /// </summary>
        Descending
    }

    /// <summary>
    /// Encapsulates active sorting criteria for a tabular dataset page.
    /// </summary>
    /// <param name="ColumnIndex">The zero-based index of the target column.</param>
    /// <param name="ColumnName">The display name of the target column.</param>
    /// <param name="Direction">The active sort direction.</param>
    /// <param name="DataType">The underlying SQL data type for type-aware comparisons.</param>
    public record ColumnSortDescriptor(int ColumnIndex, string ColumnName, ColumnSortDirection Direction, string DataType);
}
