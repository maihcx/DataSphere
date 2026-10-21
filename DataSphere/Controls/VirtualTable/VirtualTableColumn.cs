using DataSphere.Models;

namespace DataSphere.Controls.VirtualTable
{
    /// <summary>
    /// Represents a column definition for the <see cref="VirtualTable"/> control.
    /// </summary>
    public class VirtualTableColumn
    {
        /// <summary>
        /// Gets or sets the unique key identifying the column.
        /// </summary>
        public string Key { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the visual display title of the column header.
        /// </summary>
        public string Header { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the current width of the column in device-independent pixels.
        /// </summary>
        public double Width { get; set; } = 140.0;

        /// <summary>
        /// Gets or sets the minimum allowed width of the column during drag-resizing.
        /// </summary>
        public double MinWidth { get; set; } = 60.0;

        /// <summary>
        /// Gets or sets the data type name of the column values (e.g., "int", "varchar", "datetime").
        /// </summary>
        public string DataType { get; set; } = "string";

        /// <summary>
        /// Gets or sets the current visual and logical sort direction of the column.
        /// </summary>
        public ColumnSortDirection SortDirection { get; set; } = ColumnSortDirection.None;

        /// <summary>
        /// Gets or sets a value indicating whether this column supports user-triggered sorting.
        /// </summary>
        public bool CanSort { get; set; } = true;

        /// <summary>
        /// Gets or sets a value indicating whether this column can be resized interactively by the user.
        /// </summary>
        public bool CanResize { get; set; } = true;

        /// <summary>
        /// Gets or sets a value indicating whether cells in this column are read-only.
        /// </summary>
        public bool IsReadOnly { get; set; } = false;
    }
}
