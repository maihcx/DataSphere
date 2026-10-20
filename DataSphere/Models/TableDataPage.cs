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
    }

    /// <summary>
    /// Represents an individual row record containing formatted string cells.
    /// </summary>
    public class TableRowData
    {
        /// <summary>
        /// Gets or sets the sequential 1-based row index for visual display.
        /// </summary>
        public int RowIndex { get; set; }

        /// <summary>
        /// Gets or sets the ordered list of cell values for this row.
        /// </summary>
        public List<string> Cells { get; set; } = new();

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
    }
}
