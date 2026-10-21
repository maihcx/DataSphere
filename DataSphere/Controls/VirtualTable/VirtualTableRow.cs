using System;
using System.Collections.Generic;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Windows.UI;

namespace DataSphere.Controls.VirtualTable
{
    /// <summary>
    /// Represents a recycled visual row element within the <see cref="VirtualTable"/> control.
    /// Manages a fixed pool of cell containers matching only the visible viewport capacity,
    /// achieving bidirectional virtualization without allocating UI objects during scrolling.
    /// </summary>
    public sealed class VirtualTableRow
    {
        private static readonly SolidColorBrush DefaultBorderBrush = new(Color.FromArgb(25, 128, 128, 128));
        private static readonly SolidColorBrush DefaultHoverBrush = new(Color.FromArgb(20, 128, 128, 128));
        private static readonly SolidColorBrush DefaultSelectedBrush = new(Color.FromArgb(45, 0, 120, 215));
        private static readonly SolidColorBrush CellSelectedBorderBrush = new(Color.FromArgb(200, 0, 120, 215));
        private static readonly SolidColorBrush TransparentBrush = new(Colors.Transparent);
        private static readonly SolidColorBrush AlternatingBrush = new(Color.FromArgb(8, 128, 128, 128));

        private readonly Canvas _cellsCanvas;
        private readonly List<Border> _cellBorders = new();
        private readonly List<TextBlock> _cellTextBlocks = new();

        /// <summary>
        /// Initializes a new instance of the <see cref="VirtualTableRow"/> class.
        /// </summary>
        /// <param name="rowHeight">The fixed height in device-independent pixels for this row.</param>
        public VirtualTableRow(double rowHeight)
        {
            RowHeight = rowHeight;
            _cellsCanvas = new Canvas { Height = rowHeight };

            VisualBorder = new Border
            {
                Height = rowHeight,
                BorderThickness = new Thickness(0, 0, 0, 1),
                BorderBrush = ResolveThemeBrush("CardStrokeColorDefaultBrush", DefaultBorderBrush),
                Background = TransparentBrush,
                Child = _cellsCanvas
            };
        }

        /// <summary>
        /// Gets the root visual container element representing this row in the visual tree.
        /// </summary>
        public Border VisualBorder { get; }

        /// <summary>
        /// Gets or sets the fixed height of the row.
        /// </summary>
        public double RowHeight { get; set; }

        /// <summary>
        /// Gets or sets the 0-based index of the underlying data record represented by this visual row.
        /// </summary>
        public int DataRowIndex { get; set; } = -1;

        /// <summary>
        /// Gets or sets a value indicating whether this row is currently selected.
        /// </summary>
        public bool IsSelected { get; set; }

        /// <summary>
        /// Gets or sets a value indicating whether the pointer is currently hovering over this row.
        /// </summary>
        public bool IsHovered { get; set; }

        /// <summary>
        /// Gets or sets a value indicating whether this row has an even 0-based data index for alternating styling.
        /// </summary>
        public bool IsEven { get; set; }

        /// <summary>
        /// Ensures that the internal pool of visual cell controls can accommodate the maximum visible column capacity.
        /// </summary>
        /// <param name="visibleSlotCount">The required number of visual cell slots in this row.</param>
        public void EnsureColumns(int visibleSlotCount)
        {
            var gridlineBrush = ResolveThemeBrush("CardStrokeColorDefaultBrush", DefaultBorderBrush);
            var textBrush = ResolveThemeBrush("TextFillColorPrimaryBrush", new SolidColorBrush(Colors.White));

            while (_cellBorders.Count < visibleSlotCount)
            {
                var textBlock = new TextBlock
                {
                    VerticalAlignment = VerticalAlignment.Center,
                    Padding = new Thickness(10, 0, 10, 0),
                    TextTrimming = TextTrimming.CharacterEllipsis,
                    FontSize = 13,
                    Foreground = textBrush
                };

                var cellBorder = new Border
                {
                    Height = RowHeight,
                    BorderThickness = new Thickness(0, 0, 1, 0),
                    BorderBrush = gridlineBrush,
                    Child = textBlock
                };

                _cellsCanvas.Children.Add(cellBorder);
                _cellBorders.Add(cellBorder);
                _cellTextBlocks.Add(textBlock);
            }
        }

        /// <summary>
        /// Updates the text, layout dimensions, and visual selection for the specified recycled cell slot.
        /// </summary>
        /// <param name="slotIndex">The 0-based visual slot index in this row.</param>
        /// <param name="text">The string display text for the cell.</param>
        /// <param name="width">The width of the column.</param>
        /// <param name="left">The viewport-relative horizontal offset for the cell.</param>
        /// <param name="isCellSelected">Whether this specific cell has keyboard/cursor focus.</param>
        public void UpdateCell(int slotIndex, string text, double width, double left, bool isCellSelected)
        {
            if (slotIndex < 0 || slotIndex >= _cellBorders.Count) return;

            var border = _cellBorders[slotIndex];
            var textBlock = _cellTextBlocks[slotIndex];

            border.Visibility = Visibility.Visible;
            Canvas.SetLeft(border, left);
            border.Width = width;
            border.Height = RowHeight;

            // Direct string assignment avoids all XAML binding reflection overhead
            textBlock.Text = text;

            if (isCellSelected)
            {
                border.BorderBrush = CellSelectedBorderBrush;
                border.BorderThickness = new Thickness(1);
            }
            else
            {
                border.BorderBrush = ResolveThemeBrush("CardStrokeColorDefaultBrush", DefaultBorderBrush);
                border.BorderThickness = new Thickness(0, 0, 1, 0);
            }
        }

        /// <summary>
        /// Hides any visual cell controls beyond the specified active slot count.
        /// </summary>
        /// <param name="activeSlotCount">The number of active visible cell slots.</param>
        public void HideUnusedCells(int activeSlotCount)
        {
            for (int i = activeSlotCount; i < _cellBorders.Count; i++)
            {
                _cellBorders[i].Visibility = Visibility.Collapsed;
            }
        }

        /// <summary>
        /// Updates the background fill and border brushes of this row based on its current selection, hover, and alternating state.
        /// </summary>
        public void UpdateVisualState()
        {
            if (IsSelected)
            {
                VisualBorder.Background = ResolveThemeBrush("SubtleFillColorSecondaryBrush", DefaultSelectedBrush);
            }
            else if (IsHovered)
            {
                VisualBorder.Background = ResolveThemeBrush("SubtleFillColorTertiaryBrush", DefaultHoverBrush);
            }
            else
            {
                VisualBorder.Background = IsEven ? TransparentBrush : AlternatingBrush;
            }
        }

        private static Brush ResolveThemeBrush(string resourceKey, Brush fallback)
        {
            if (Application.Current != null && Application.Current.Resources.TryGetValue(resourceKey, out var res) && res is Brush brush)
            {
                return brush;
            }
            return fallback;
        }
    }
}
