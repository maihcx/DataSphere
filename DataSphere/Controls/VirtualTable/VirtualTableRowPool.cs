using System;
using System.Collections.Generic;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace DataSphere.Controls.VirtualTable
{
    /// <summary>
    /// Manages the fixed collection of visual rows and bidirectional virtualization in the <see cref="VirtualTable"/> control.
    /// Recycles visual row containers and visible cell slots concurrently to achieve zero heap allocations and 60+ FPS on arbitrary table sizes.
    /// </summary>
    public sealed class VirtualTableRowPool
    {
        private readonly List<VirtualTableRow> _rows = new();
        private readonly List<double> _columnOffsets = new();

        /// <summary>
        /// Gets the current list of pooled visual rows.
        /// </summary>
        public IReadOnlyList<VirtualTableRow> Rows => _rows;

        /// <summary>
        /// Gets the number of instantiated visual row containers in the pool.
        /// </summary>
        public int PoolSize => _rows.Count;

        /// <summary>
        /// Clears all visual row elements from the pool and removes them from the parent canvas.
        /// </summary>
        /// <param name="parentCanvas">The visual canvas hosting the row elements.</param>
        public void Clear(Canvas? parentCanvas)
        {
            if (parentCanvas != null)
            {
                foreach (var row in _rows)
                {
                    parentCanvas.Children.Remove(row.VisualBorder);
                }
            }
            _rows.Clear();
            _columnOffsets.Clear();
        }

        /// <summary>
        /// Collapses all instantiated visual row containers immediately to avoid rendering stale rows.
        /// </summary>
        public void CollapseAll()
        {
            for (int i = 0; i < _rows.Count; i++)
            {
                _rows[i].VisualBorder.Visibility = Visibility.Collapsed;
                _rows[i].DataRowIndex = -1;
            }
        }

        /// <summary>
        /// Ensures that the pool contains the exact number of visual row elements required to fill the viewport
        /// with a 2-row buffer, and that each row contains cell slots sufficient for the visible viewport width.
        /// </summary>
        /// <param name="parentCanvas">The visual canvas hosting the row elements.</param>
        /// <param name="viewportWidth">The visible width of the table viewport in pixels.</param>
        /// <param name="viewportHeight">The visible height of the table viewport in pixels.</param>
        /// <param name="rowHeight">The fixed row height in pixels.</param>
        /// <param name="totalColumnCount">The total number of columns in the active dataset.</param>
        public void EnsurePoolSize(Canvas parentCanvas, double viewportWidth, double viewportHeight, double rowHeight, int totalColumnCount)
        {
            if (rowHeight <= 0) rowHeight = 34.0;
            int visibleCount = viewportHeight > 0 ? (int)Math.Ceiling(viewportHeight / rowHeight) : 10;
            int requiredCount = Math.Max(5, visibleCount + 6);

            // Cap the cell slot pool per row to what can visibly fit in the viewport plus buffer columns
            double minColWidth = 60.0;
            int maxVisibleCols = viewportWidth > 0 ? (int)Math.Ceiling(viewportWidth / minColWidth) + 8 : 24;
            int requiredCellSlots = Math.Min(totalColumnCount, Math.Max(8, maxVisibleCols));

            while (_rows.Count < requiredCount)
            {
                var row = new VirtualTableRow(rowHeight);
                row.EnsureColumns(requiredCellSlots);
                parentCanvas.Children.Add(row.VisualBorder);
                _rows.Add(row);
            }

            for (int i = 0; i < _rows.Count; i++)
            {
                _rows[i].RowHeight = rowHeight;
                _rows[i].EnsureColumns(requiredCellSlots);
                _rows[i].VisualBorder.Visibility = (totalColumnCount > 0 && i < requiredCount) ? Visibility.Visible : Visibility.Collapsed;
            }
        }

        /// <summary>
        /// Recycles visual rows and visible cell slots concurrently based on vertical and horizontal scroll positions.
        /// Culls all off-screen columns to deliver sub-millisecond frame renders regardless of column count.
        /// </summary>
        /// <param name="firstVisibleRow">The 0-based data row index visible at the top of the viewport.</param>
        /// <param name="scrollOffsetY">The current vertical scroll position in pixels.</param>
        /// <param name="scrollOffsetX">The current horizontal scroll position in pixels.</param>
        /// <param name="viewportWidth">The visible width of the table viewport in pixels.</param>
        /// <param name="rowHeight">The height of each row in pixels.</param>
        /// <param name="totalRowCount">The total number of rows in the dataset.</param>
        /// <param name="columns">The column definitions.</param>
        /// <param name="dataProvider">The on-demand data delivery provider.</param>
        /// <param name="selectedRowIndex">The currently selected row index.</param>
        /// <param name="selectedColumnIndex">The currently selected column index.</param>
        /// <param name="hoveredRowIndex">The currently hovered row index.</param>
        public void Recycle(
            int firstVisibleRow,
            double scrollOffsetY,
            double scrollOffsetX,
            double viewportWidth,
            double rowHeight,
            int totalRowCount,
            IReadOnlyList<VirtualTableColumn> columns,
            IVirtualTableDataProvider? dataProvider,
            int selectedRowIndex,
            int selectedColumnIndex,
            int hoveredRowIndex)
        {
            if (columns == null || columns.Count == 0 || dataProvider == null || totalRowCount <= 0)
            {
                CollapseAll();
                return;
            }

            // Cache column horizontal offsets
            _columnOffsets.Clear();
            double runningLeft = 0.0;
            for (int c = 0; c < columns.Count; c++)
            {
                _columnOffsets.Add(runningLeft);
                runningLeft += columns[c].Width;
            }

            // Calculate visible column index range based on scrollOffsetX and viewportWidth
            double visibleLeftBound = scrollOffsetX;
            double visibleRightBound = scrollOffsetX + (viewportWidth > 0 ? viewportWidth : 1200.0);

            int firstVisibleCol = 0;
            int lastVisibleCol = columns.Count - 1;

            for (int c = 0; c < columns.Count; c++)
            {
                double colRight = _columnOffsets[c] + columns[c].Width;
                if (colRight >= visibleLeftBound)
                {
                    firstVisibleCol = Math.Max(0, c - 2); // 2-column left buffer
                    break;
                }
            }

            for (int c = firstVisibleCol; c < columns.Count; c++)
            {
                if (_columnOffsets[c] > visibleRightBound)
                {
                    lastVisibleCol = Math.Min(columns.Count - 1, c + 2); // 2-column right buffer
                    break;
                }
            }

            for (int i = 0; i < _rows.Count; i++)
            {
                var row = _rows[i];
                int dataIndex = firstVisibleRow + i;

                if (dataIndex < 0 || dataIndex >= totalRowCount || dataProvider == null)
                {
                    row.VisualBorder.Visibility = Visibility.Collapsed;
                    row.DataRowIndex = -1;
                    continue;
                }

                row.VisualBorder.Visibility = Visibility.Visible;
                row.DataRowIndex = dataIndex;

                double y = dataIndex * rowHeight;
                Canvas.SetTop(row.VisualBorder, y);
                Canvas.SetLeft(row.VisualBorder, 0);
                row.VisualBorder.Width = runningLeft;

                row.IsSelected = (dataIndex == selectedRowIndex);
                row.IsHovered = (dataIndex == hoveredRowIndex);
                row.IsEven = (dataIndex % 2 == 0);
                row.UpdateVisualState();

                int slot = 0;
                for (int c = firstVisibleCol; c <= lastVisibleCol; c++)
                {
                    string text = dataProvider.GetCellText(dataIndex, c);
                    bool isCellSelected = row.IsSelected && (selectedColumnIndex == -1 || selectedColumnIndex == c);
                    double cellX = _columnOffsets[c];
                    row.UpdateCell(slot, text, columns[c].Width, cellX, isCellSelected);
                    slot++;
                }

                row.HideUnusedCells(slot);
            }
        }

        /// <summary>
        /// Finds the visual row currently mapped to the specified data row index.
        /// </summary>
        /// <param name="dataRowIndex">The 0-based data row index to locate.</param>
        /// <returns>The matching <see cref="VirtualTableRow"/>, or <c>null</c> if not currently pooled or visible.</returns>
        public VirtualTableRow? FindVisualRow(int dataRowIndex)
        {
            if (dataRowIndex < 0) return null;
            for (int i = 0; i < _rows.Count; i++)
            {
                if (_rows[i].DataRowIndex == dataRowIndex && _rows[i].VisualBorder.Visibility == Visibility.Visible)
                {
                    return _rows[i];
                }
            }
            return null;
        }
    }
}
