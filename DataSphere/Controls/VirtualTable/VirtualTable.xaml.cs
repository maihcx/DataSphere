using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Collections.Specialized;
using System.Text;
using System.Windows.Input;
using Windows.ApplicationModel.DataTransfer;
using Windows.Foundation;
using Windows.System;
using Windows.UI;
using Windows.UI.Core;
using Microsoft.UI;
using Microsoft.UI.Input;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Hosting;

namespace DataSphere.Controls.VirtualTable
{
    /// <summary>
    /// Custom high-performance WinUI 3 tabular data control recreating the Delphi TVirtualStringTree architecture.
    /// Utilizes fixed-pool visual row recycling and direct text callbacks to achieve zero-allocation 60+ FPS scrolling.
    /// </summary>
    public sealed partial class VirtualTable : UserControl, IDisposable
    {
        private bool _disposed;
        private bool _isCompositorSyncConfigured;
        private double? _accumulatedTargetScrollX;
        private DateTime _lastHorizontalWheelTime;

        /// <summary>
        /// Identifies the <see cref="DataProvider"/> dependency property.
        /// </summary>
        public static readonly DependencyProperty DataProviderProperty =
            DependencyProperty.Register(
                nameof(DataProvider),
                typeof(IVirtualTableDataProvider),
                typeof(VirtualTable),
                new PropertyMetadata(null, OnDataProviderChanged));

        /// <summary>
        /// Identifies the <see cref="RowHeight"/> dependency property.
        /// </summary>
        public static readonly DependencyProperty RowHeightProperty =
            DependencyProperty.Register(
                nameof(RowHeight),
                typeof(double),
                typeof(VirtualTable),
                new PropertyMetadata(34.0, OnRowHeightChanged));

        /// <summary>
        /// Identifies the <see cref="SelectedRowIndex"/> dependency property.
        /// </summary>
        public static readonly DependencyProperty SelectedRowIndexProperty =
            DependencyProperty.Register(
                nameof(SelectedRowIndex),
                typeof(int),
                typeof(VirtualTable),
                new PropertyMetadata(-1, OnSelectionChanged));

        /// <summary>
        /// Identifies the <see cref="SelectedColumnIndex"/> dependency property.
        /// </summary>
        public static readonly DependencyProperty SelectedColumnIndexProperty =
            DependencyProperty.Register(
                nameof(SelectedColumnIndex),
                typeof(int),
                typeof(VirtualTable),
                new PropertyMetadata(-1, OnSelectionChanged));

        /// <summary>
        /// Identifies the <see cref="SortCommand"/> dependency property.
        /// </summary>
        public static readonly DependencyProperty SortCommandProperty =
            DependencyProperty.Register(
                nameof(SortCommand),
                typeof(ICommand),
                typeof(VirtualTable),
                new PropertyMetadata(null));

        /// <summary>
        /// Identifies the <see cref="SortCommandParameter"/> dependency property.
        /// </summary>
        public static readonly DependencyProperty SortCommandParameterProperty =
            DependencyProperty.Register(
                nameof(SortCommandParameter),
                typeof(object),
                typeof(VirtualTable),
                new PropertyMetadata(null));

        /// <summary>
        /// Identifies the <see cref="CellEditedCommand"/> dependency property.
        /// </summary>
        public static readonly DependencyProperty CellEditedCommandProperty =
            DependencyProperty.Register(
                nameof(CellEditedCommand),
                typeof(ICommand),
                typeof(VirtualTable),
                new PropertyMetadata(null));

        /// <summary>
        /// Identifies the <see cref="CellEditedCommandParameter"/> dependency property.
        /// </summary>
        public static readonly DependencyProperty CellEditedCommandParameterProperty =
            DependencyProperty.Register(
                nameof(CellEditedCommandParameter),
                typeof(object),
                typeof(VirtualTable),
                new PropertyMetadata(null));

        private readonly VirtualTableRowPool _rowPool = new();
        private readonly List<Border> _headerBorders = new();
        private readonly List<TextBlock> _headerSortGlyphs = new();
        private readonly List<SplitterHandle> _headerSplitters = new();

        private double _scrollOffsetY = 0.0;
        private double _scrollOffsetX = 0.0;
        private int _hoveredRowIndex = -1;

        // Splitter resize tracking
        private bool _isResizingColumn;
        private int _resizingColumnIndex = -1;
        private double _resizeStartPointerX;
        private double _resizeInitialWidth;
        private SplitterHandle? _activeSplitter;
        private readonly InputCursor _splitterCursor = InputSystemCursor.Create(InputSystemCursorShape.SizeWestEast);

        // In-place editing state
        private int _editingRowIndex = -1;
        private int _editingColumnIndex = -1;
        private DateTime _lastClickTime = DateTime.MinValue;
        private Point _lastClickPos = new(0, 0);

        /// <summary>
        /// Initializes a new instance of the <see cref="VirtualTable"/> class.
        /// </summary>
        public VirtualTable()
        {
            InitializeComponent();
            Columns = new ObservableCollection<VirtualTableColumn>();
            Columns.CollectionChanged += OnColumnsCollectionChanged;

            Loaded += OnLoaded;
            Unloaded += OnUnloaded;
            ActualThemeChanged += OnActualThemeChanged;
            SizeChanged += OnSizeChanged;

            TableScrollViewer.ViewChanged += OnScrollViewerViewChanged;

            VirtualCanvas.PointerPressed += OnViewportPointerPressed;
            VirtualCanvas.PointerMoved += OnViewportPointerMoved;
            VirtualCanvas.PointerExited += OnViewportPointerExited;
            VirtualScrollHost.PointerWheelChanged += OnViewportPointerWheelChanged;
            HeaderBorder.PointerWheelChanged += OnViewportPointerWheelChanged;

            HeaderBorder.PointerMoved += OnHeaderPointerMoved;
            HeaderBorder.PointerReleased += OnHeaderPointerReleased;
            HeaderBorder.PointerCaptureLost += OnHeaderPointerCaptureLost;
            PointerMoved += OnHeaderPointerMoved;
            PointerReleased += OnHeaderPointerReleased;
            PointerCaptureLost += OnHeaderPointerCaptureLost;

            KeyDown += OnTableKeyDown;
            CellEditorOverlay.KeyDown += OnCellEditorKeyDown;
            CellEditorOverlay.LostFocus += OnCellEditorLostFocus;
        }

        /// <summary>
        /// Gets or sets the data provider driving on-demand cell display and updates.
        /// </summary>
        public IVirtualTableDataProvider? DataProvider
        {
            get => (IVirtualTableDataProvider?)GetValue(DataProviderProperty);
            set => SetValue(DataProviderProperty, value);
        }

        /// <summary>
        /// Gets or sets the fixed height in device-independent pixels for each row (default = 34.0).
        /// </summary>
        public double RowHeight
        {
            get => (double)GetValue(RowHeightProperty);
            set => SetValue(RowHeightProperty, value);
        }

        /// <summary>
        /// Gets or sets the currently selected 0-based data row index (-1 for no selection).
        /// </summary>
        public int SelectedRowIndex
        {
            get => (int)GetValue(SelectedRowIndexProperty);
            set => SetValue(SelectedRowIndexProperty, value);
        }

        /// <summary>
        /// Gets or sets the currently selected 0-based column index (-1 for full row selection).
        /// </summary>
        public int SelectedColumnIndex
        {
            get => (int)GetValue(SelectedColumnIndexProperty);
            set => SetValue(SelectedColumnIndexProperty, value);
        }

        /// <summary>
        /// Gets or sets the command executed when a column header sort is clicked.
        /// </summary>
        public ICommand? SortCommand
        {
            get => (ICommand?)GetValue(SortCommandProperty);
            set => SetValue(SortCommandProperty, value);
        }

        /// <summary>
        /// Gets or sets an optional custom parameter for <see cref="SortCommand"/>.
        /// When null, defaults to the active <see cref="VirtualTableSortEventArgs"/>.
        /// </summary>
        public object? SortCommandParameter
        {
            get => GetValue(SortCommandParameterProperty);
            set => SetValue(SortCommandParameterProperty, value);
        }

        /// <summary>
        /// Gets or sets the command executed when an in-place cell edit is committed.
        /// </summary>
        public ICommand? CellEditedCommand
        {
            get => (ICommand?)GetValue(CellEditedCommandProperty);
            set => SetValue(CellEditedCommandProperty, value);
        }

        /// <summary>
        /// Gets or sets an optional custom parameter for <see cref="CellEditedCommand"/>.
        /// When null, defaults to the active <see cref="VirtualTableCellEditEventArgs"/>.
        /// </summary>
        public object? CellEditedCommandParameter
        {
            get => GetValue(CellEditedCommandParameterProperty);
            set => SetValue(CellEditedCommandParameterProperty, value);
        }

        /// <summary>
        /// Gets the observable collection of column definitions for this table.
        /// </summary>
        public ObservableCollection<VirtualTableColumn> Columns { get; }

        /// <summary>
        /// Occurs when a column header is clicked to request 3-state sorting.
        /// </summary>
        public event EventHandler<VirtualTableSortEventArgs>? Sorting;

        /// <summary>
        /// Occurs when an in-place cell edit has been committed.
        /// </summary>
        public event EventHandler<VirtualTableCellEditEventArgs>? CellEdited;

        /// <summary>
        /// Forces an immediate visual refresh and row recycling of the visible viewport.
        /// </summary>
        public void Refresh()
        {
            SyncColumnsFromDataProvider();
            BuildHeaderElements();
            UpdateScrollExtent();
            double vpWidth = TableScrollViewer.ViewportWidth > 0 ? TableScrollViewer.ViewportWidth : TableScrollViewer.ActualWidth;
            double vpHeight = TableScrollViewer.ViewportHeight > 0 ? TableScrollViewer.ViewportHeight : TableScrollViewer.ActualHeight;
            _rowPool.EnsurePoolSize(VirtualCanvas, vpWidth, vpHeight, RowHeight, Columns.Count);
            Recycle();
        }

        /// <summary>
        /// Scrolls the viewport smoothly to ensure the specified data row is visible using native WinUI 3 animation.
        /// </summary>
        /// <param name="rowIndex">The 0-based data row index.</param>
        public void ScrollToRow(int rowIndex)
        {
            if (rowIndex < 0) return;
            double targetTop = rowIndex * RowHeight;
            TableScrollViewer.ChangeView(null, targetTop, null, disableAnimation: false);
        }

        private static void OnDataProviderChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is VirtualTable table)
            {
                table.ResetViewportState();
                table.Refresh();
            }
        }

        /// <summary>
        /// Immediately clears all visual rows, headers, and scroll state from the viewport.
        /// Ensures no stale table data remains rendered while switching datasets.
        /// </summary>
        public void Clear()
        {
            ResetViewportState();
            _rowPool.Clear(VirtualCanvas);
            Columns.CollectionChanged -= OnColumnsCollectionChanged;
            try
            {
                Columns.Clear();
            }
            finally
            {
                Columns.CollectionChanged += OnColumnsCollectionChanged;
            }
            BuildHeaderElements();
            UpdateScrollExtent();
        }

        /// <summary>
        /// Resets the internal scroll and selection coordinates when switching datasets.
        /// </summary>
        private void ResetViewportState()
        {
            CancelCellEdit();
            SelectedRowIndex = -1;
            SelectedColumnIndex = -1;
            _hoveredRowIndex = -1;
            _scrollOffsetX = 0.0;
            _scrollOffsetY = 0.0;
            _accumulatedTargetScrollX = null;
            TableScrollViewer?.ChangeView(0.0, 0.0, null, disableAnimation: true);
            _rowPool.CollapseAll();
        }

        private static void OnRowHeightChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is VirtualTable table)
            {
                table.Refresh();
            }
        }

        private static void OnSelectionChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is VirtualTable table)
            {
                table.Recycle();
            }
        }

        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            SetupHeaderCompositorSync();
            Refresh();
        }

        private void OnUnloaded(object sender, RoutedEventArgs e)
        {
            Dispose();
        }

        private void OnActualThemeChanged(FrameworkElement sender, object args)
        {
            Recycle();
        }

        /// <summary>
        /// Configures high-performance 144Hz compositor-driven scroll synchronization between TableScrollViewer and HeaderCanvas
        /// using Windows DirectComposition ExpressionAnimation.
        /// </summary>
        private void SetupHeaderCompositorSync()
        {
            if (_isCompositorSyncConfigured || TableScrollViewer == null || HeaderCanvas == null) return;

            try
            {
                var scrollPropSet = ElementCompositionPreview.GetScrollViewerManipulationPropertySet(TableScrollViewer);
                if (scrollPropSet == null) return;

                var compositor = scrollPropSet.Compositor;
                var headerVisual = ElementCompositionPreview.GetElementVisual(HeaderCanvas);
                if (headerVisual == null) return;

                var expr = compositor.CreateExpressionAnimation("scrollPropSet.Translation.X");
                expr.SetReferenceParameter("scrollPropSet", scrollPropSet);
                headerVisual.StartAnimation("Offset.X", expr);

                HeaderCanvas.RenderTransform = null;
                _isCompositorSyncConfigured = true;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to configure compositor header sync: {ex.Message}");
            }
        }

        /// <summary>
        /// Stops the DirectComposition expression animation linking the header canvas to the scroll viewer.
        /// </summary>
        private void TeardownHeaderCompositorSync()
        {
            if (!_isCompositorSyncConfigured) return;

            try
            {
                if (HeaderCanvas != null)
                {
                    var headerVisual = ElementCompositionPreview.GetElementVisual(HeaderCanvas);
                    headerVisual?.StopAnimation("Offset.X");
                }
            }
            catch
            {
                // Ignored during visual tree teardown
            }
            finally
            {
                _isCompositorSyncConfigured = false;
            }
        }

        /// <inheritdoc/>
        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;

            CancelCellEdit();
            TeardownHeaderCompositorSync();

            Loaded -= OnLoaded;
            Unloaded -= OnUnloaded;
            ActualThemeChanged -= OnActualThemeChanged;
            SizeChanged -= OnSizeChanged;

            Columns.CollectionChanged -= OnColumnsCollectionChanged;

            if (TableScrollViewer != null)
            {
                TableScrollViewer.ViewChanged -= OnScrollViewerViewChanged;
            }

            if (VirtualCanvas != null)
            {
                VirtualCanvas.PointerPressed -= OnViewportPointerPressed;
                VirtualCanvas.PointerMoved -= OnViewportPointerMoved;
                VirtualCanvas.PointerExited -= OnViewportPointerExited;
                _rowPool.Clear(VirtualCanvas);
            }

            if (VirtualScrollHost != null)
            {
                VirtualScrollHost.PointerWheelChanged -= OnViewportPointerWheelChanged;
            }

            if (HeaderBorder != null)
            {
                HeaderBorder.PointerWheelChanged -= OnViewportPointerWheelChanged;
                HeaderBorder.PointerMoved -= OnHeaderPointerMoved;
                HeaderBorder.PointerReleased -= OnHeaderPointerReleased;
                HeaderBorder.PointerCaptureLost -= OnHeaderPointerCaptureLost;
            }

            PointerMoved -= OnHeaderPointerMoved;
            PointerReleased -= OnHeaderPointerReleased;
            PointerCaptureLost -= OnHeaderPointerCaptureLost;

            KeyDown -= OnTableKeyDown;
            if (CellEditorOverlay != null)
            {
                CellEditorOverlay.KeyDown -= OnCellEditorKeyDown;
                CellEditorOverlay.LostFocus -= OnCellEditorLostFocus;
            }

            _headerBorders.Clear();
            _headerSortGlyphs.Clear();
            _headerSplitters.Clear();
            HeaderCanvas?.Children.Clear();

            Columns.Clear();
            DataProvider = null;
        }

        private void OnSizeChanged(object sender, SizeChangedEventArgs e)
        {
            if (HeaderBorder.ActualWidth > 0 && HeaderBorder.ActualHeight > 0)
            {
                HeaderBorder.Clip = new RectangleGeometry
                {
                    Rect = new Rect(0, 0, HeaderBorder.ActualWidth, HeaderBorder.ActualHeight)
                };
            }

            UpdateScrollExtent();
            double vpWidth = TableScrollViewer.ViewportWidth > 0 ? TableScrollViewer.ViewportWidth : TableScrollViewer.ActualWidth;
            double vpHeight = TableScrollViewer.ViewportHeight > 0 ? TableScrollViewer.ViewportHeight : TableScrollViewer.ActualHeight;
            _rowPool.EnsurePoolSize(VirtualCanvas, vpWidth, vpHeight, RowHeight, Columns.Count);
            Recycle();
        }

        private void OnColumnsCollectionChanged(object? sender, NotifyCollectionChangedEventArgs e)
        {
            BuildHeaderElements();
            UpdateScrollExtent();
            double vpWidth = TableScrollViewer.ViewportWidth > 0 ? TableScrollViewer.ViewportWidth : TableScrollViewer.ActualWidth;
            double vpHeight = TableScrollViewer.ViewportHeight > 0 ? TableScrollViewer.ViewportHeight : TableScrollViewer.ActualHeight;
            _rowPool.EnsurePoolSize(VirtualCanvas, vpWidth, vpHeight, RowHeight, Columns.Count);
            Recycle();
        }

        private void SyncColumnsFromDataProvider()
        {
            if (DataProvider == null)
            {
                if (Columns.Count > 0)
                {
                    Columns.CollectionChanged -= OnColumnsCollectionChanged;
                    try
                    {
                        Columns.Clear();
                    }
                    finally
                    {
                        Columns.CollectionChanged += OnColumnsCollectionChanged;
                    }
                }
                return;
            }

            var providerCols = DataProvider.Columns;
            if (providerCols == null) return;

            // Check if column schemas match
            bool match = Columns.Count == providerCols.Count;
            if (match)
            {
                for (int i = 0; i < Columns.Count; i++)
                {
                    if (Columns[i].Key != providerCols[i].Key)
                    {
                        match = false;
                        break;
                    }
                }
            }

            if (!match)
            {
                Columns.CollectionChanged -= OnColumnsCollectionChanged;
                try
                {
                    Columns.Clear();
                    foreach (var col in providerCols)
                    {
                        Columns.Add(col);
                    }
                }
                finally
                {
                    Columns.CollectionChanged += OnColumnsCollectionChanged;
                }
            }
        }

        #region Column Headers & Drag Resizing

        private void BuildHeaderElements()
        {
            HeaderCanvas.Children.Clear();
            _headerBorders.Clear();
            _headerSortGlyphs.Clear();
            _headerSplitters.Clear();
            UpdateHeaderScrollTransform();

            var accentBrush = ResolveThemeBrush("AccentFillColorDefaultBrush", new SolidColorBrush(Color.FromArgb(255, 0, 120, 215)));
            var splitterCursor = InputSystemCursor.Create(InputSystemCursorShape.SizeWestEast);

            double left = 0.0;
            for (int i = 0; i < Columns.Count; i++)
            {
                int colIdx = i;
                var col = Columns[i];

                var headerGrid = new Grid
                {
                    Height = 36,
                    Margin = new Thickness(10, 0, 14, 0)
                };
                headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

                var titleBlock = new TextBlock
                {
                    Text = col.Header,
                    FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
                    FontSize = 13,
                    VerticalAlignment = VerticalAlignment.Center,
                    TextTrimming = TextTrimming.CharacterEllipsis
                };
                Grid.SetColumn(titleBlock, 0);
                headerGrid.Children.Add(titleBlock);

                var sortGlyph = new TextBlock
                {
                    Text = GetSortGlyph(col.SortDirection),
                    FontSize = 11,
                    FontWeight = Microsoft.UI.Text.FontWeights.Bold,
                    Foreground = accentBrush,
                    VerticalAlignment = VerticalAlignment.Center,
                    Margin = new Thickness(4, 0, 0, 0),
                    Visibility = col.SortDirection != Models.ColumnSortDirection.None ? Visibility.Visible : Visibility.Collapsed
                };
                Grid.SetColumn(sortGlyph, 1);
                headerGrid.Children.Add(sortGlyph);

                var headerBorder = new Border
                {
                    Height = 36,
                    Width = col.Width,
                    Background = new SolidColorBrush(Colors.Transparent),
                    BorderThickness = new Thickness(0, 0, 1, 0),
                    BorderBrush = ResolveThemeBrush("CardStrokeColorDefaultBrush", new SolidColorBrush(Color.FromArgb(30, 128, 128, 128))),
                    Child = headerGrid
                };
                Canvas.SetLeft(headerBorder, left);
                Canvas.SetZIndex(headerBorder, 10);

                // Clicking header requests 3-state sorting
                headerBorder.PointerPressed += (s, e) =>
                {
                    if (!_isResizingColumn)
                    {
                        OnHeaderClicked(colIdx);
                    }
                };

                // Splitter grip for interactive drag resizing
                var splitter = new SplitterHandle
                {
                    Width = 12,
                    Height = 36
                };
                splitter.SetCursor(splitterCursor);
                Canvas.SetZIndex(splitter, 2000);
                Canvas.SetLeft(splitter, left + col.Width - 6);

                splitter.PointerPressed += (s, e) =>
                {
                    if (!col.CanResize) return;
                    _isResizingColumn = true;
                    _resizingColumnIndex = colIdx;
                    _resizeStartPointerX = e.GetCurrentPoint(this).Position.X;
                    _resizeInitialWidth = col.Width;
                    _activeSplitter = splitter;

                    // Ensure cursor stays SizeWestEast continuously during drag
                    ProtectedCursor = _splitterCursor;
                    try
                    {
                        splitter.CapturePointer(e.Pointer);
                    }
                    catch
                    {
                        // Fallback if direct capture unavailable
                    }
                    e.Handled = true;
                };

                splitter.PointerMoved += OnHeaderPointerMoved;
                splitter.PointerReleased += OnHeaderPointerReleased;
                splitter.PointerCaptureLost += OnHeaderPointerCaptureLost;
                splitter.PointerCanceled += OnHeaderPointerCaptureLost;

                _headerBorders.Add(headerBorder);
                _headerSortGlyphs.Add(sortGlyph);
                _headerSplitters.Add(splitter);

                left += col.Width;
            }

            // Add all header borders first, then all splitters on top to guarantee unobstructed hit-testing
            foreach (var border in _headerBorders)
            {
                HeaderCanvas.Children.Add(border);
            }

            foreach (var splitter in _headerSplitters)
            {
                HeaderCanvas.Children.Add(splitter);
            }
        }

        private void UpdateHeaderLayouts()
        {
            double left = 0.0;
            for (int i = 0; i < Columns.Count; i++)
            {
                if (i < _headerBorders.Count)
                {
                    _headerBorders[i].Width = Columns[i].Width;
                    Canvas.SetLeft(_headerBorders[i], left);
                }
                if (i < _headerSplitters.Count)
                {
                    Canvas.SetLeft(_headerSplitters[i], left + Columns[i].Width - 6);
                }
                left += Columns[i].Width;
            }
            UpdateScrollExtent();
        }

        /// <summary>
        /// Handles pointer movement for active column splitter resizing across the header and table.
        /// </summary>
        /// <param name="sender">The event source.</param>
        /// <param name="e">The pointer event arguments.</param>
        private void OnHeaderPointerMoved(object sender, PointerRoutedEventArgs e)
        {
            if (_isResizingColumn && _resizingColumnIndex >= 0 && _resizingColumnIndex < Columns.Count)
            {
                ProtectedCursor = _splitterCursor;
                var col = Columns[_resizingColumnIndex];
                double currentX = e.GetCurrentPoint(this).Position.X;
                double delta = currentX - _resizeStartPointerX;
                double newWidth = Math.Max(col.MinWidth, _resizeInitialWidth + delta);
                if (Math.Abs(col.Width - newWidth) > 0.5)
                {
                    col.Width = newWidth;
                    UpdateHeaderLayouts();
                    Recycle();
                }
                e.Handled = true;
            }
        }

        /// <summary>
        /// Handles pointer release to complete column splitter resizing.
        /// </summary>
        /// <param name="sender">The event source.</param>
        /// <param name="e">The pointer event arguments.</param>
        private void OnHeaderPointerReleased(object sender, PointerRoutedEventArgs e)
        {
            if (_isResizingColumn)
            {
                _isResizingColumn = false;
                _resizingColumnIndex = -1;
                ProtectedCursor = null;
                try
                {
                    _activeSplitter?.ReleasePointerCapture(e.Pointer);
                }
                catch
                {
                    // Ignore release errors if capture already relinquished
                }
                try
                {
                    ReleasePointerCapture(e.Pointer);
                }
                catch
                {
                    // Ignore release errors if capture already relinquished
                }
                _activeSplitter = null;
                e.Handled = true;
            }
        }

        /// <summary>
        /// Handles pointer capture loss during column splitter resizing.
        /// </summary>
        /// <param name="sender">The event source.</param>
        /// <param name="e">The pointer event arguments.</param>
        private void OnHeaderPointerCaptureLost(object sender, PointerRoutedEventArgs e)
        {
            _isResizingColumn = false;
            _resizingColumnIndex = -1;
            ProtectedCursor = null;
            _activeSplitter = null;
        }

        private static string GetSortGlyph(Models.ColumnSortDirection direction) => direction switch
        {
            Models.ColumnSortDirection.Ascending => "▲",
            Models.ColumnSortDirection.Descending => "▼",
            _ => string.Empty
        };

        private void OnHeaderClicked(int colIndex)
        {
            if (colIndex < 0 || colIndex >= Columns.Count) return;

            var col = Columns[colIndex];
            if (!col.CanSort) return;

            // Cycle: None -> Ascending -> Descending -> None
            var nextDir = col.SortDirection switch
            {
                Models.ColumnSortDirection.None => Models.ColumnSortDirection.Ascending,
                Models.ColumnSortDirection.Ascending => Models.ColumnSortDirection.Descending,
                _ => Models.ColumnSortDirection.None
            };

            for (int i = 0; i < Columns.Count; i++)
            {
                Columns[i].SortDirection = (i == colIndex) ? nextDir : Models.ColumnSortDirection.None;
                if (i < _headerSortGlyphs.Count)
                {
                    _headerSortGlyphs[i].Text = GetSortGlyph(Columns[i].SortDirection);
                    _headerSortGlyphs[i].Visibility = Columns[i].SortDirection != Models.ColumnSortDirection.None ? Visibility.Visible : Visibility.Collapsed;
                }
            }

            var sortArgs = new VirtualTableSortEventArgs(col, nextDir);
            Sorting?.Invoke(this, sortArgs);

            var sortParam = SortCommandParameter ?? sortArgs;
            if (SortCommand != null && SortCommand.CanExecute(sortParam))
            {
                SortCommand.Execute(sortParam);
            }
        }

        #endregion

        #region Viewport Recycling & Scrolling

        /// <summary>
        /// Updates the total virtual scroll extent on the host grid and canvases to match total rows and column widths.
        /// </summary>
        private void UpdateScrollExtent()
        {
            int totalRows = DataProvider?.RowCount ?? 0;
            double totalHeight = Math.Max(0, totalRows * RowHeight);

            double totalWidth = 0.0;
            foreach (var col in Columns) totalWidth += col.Width;

            // Ensure row pool is sized to the TableScrollViewer's viewport
            double vpWidth = TableScrollViewer.ViewportWidth > 0 ? TableScrollViewer.ViewportWidth : TableScrollViewer.ActualWidth;
            double vpHeight = TableScrollViewer.ViewportHeight > 0 ? TableScrollViewer.ViewportHeight : TableScrollViewer.ActualHeight;

            double hostWidth = Math.Max(totalWidth, vpWidth);
            double hostHeight = Math.Max(totalHeight, vpHeight);

            VirtualScrollHost.Width = hostWidth;
            VirtualScrollHost.Height = hostHeight;
            VirtualCanvas.Width = hostWidth;
            VirtualCanvas.Height = hostHeight;
            EditorCanvas.Width = hostWidth;
            EditorCanvas.Height = hostHeight;

            _rowPool.EnsurePoolSize(VirtualCanvas, vpWidth, vpHeight, RowHeight, Columns.Count);
        }

        /// <summary>
        /// Updates the horizontal translation transform of the column header canvas to synchronize with the viewport scroll position.
        /// When DirectComposition compositor sync is active, visual translation is evaluated at display refresh rate on the GPU.
        /// </summary>
        private void UpdateHeaderScrollTransform()
        {
            if (_isCompositorSyncConfigured)
            {
                return;
            }

            if (HeaderCanvas.RenderTransform is not TranslateTransform tt)
            {
                HeaderCanvas.RenderTransform = new TranslateTransform { X = -_scrollOffsetX };
            }
            else
            {
                tt.X = -_scrollOffsetX;
            }
        }

        /// <summary>
        /// Handles ViewChanged events from the native ScrollViewer, updating offsets and recycling visible rows.
        /// </summary>
        private void OnScrollViewerViewChanged(object? sender, ScrollViewerViewChangedEventArgs e)
        {
            _scrollOffsetY = TableScrollViewer.VerticalOffset;
            _scrollOffsetX = TableScrollViewer.HorizontalOffset;

            UpdateHeaderScrollTransform();
            Recycle();
        }

        /// <summary>
        /// Handles mouse wheel events on the table viewport and headers, translating Shift + wheel gestures into horizontal scrolling.
        /// </summary>
        /// <param name="sender">The source of the pointer event.</param>
        /// <param name="e">The pointer routed event arguments containing wheel delta and pointer properties.</param>
        private void OnViewportPointerWheelChanged(object sender, PointerRoutedEventArgs e)
        {
            var props = e.GetCurrentPoint(TableScrollViewer).Properties;
            if (props.IsHorizontalMouseWheel)
            {
                return;
            }

            bool isShift = (InputKeyboardSource.GetKeyStateForCurrentThread(VirtualKey.Shift) & CoreVirtualKeyStates.Down) == CoreVirtualKeyStates.Down;
            if (isShift)
            {
                int delta = props.MouseWheelDelta;
                if (delta != 0)
                {
                    double vpWidth = TableScrollViewer.ViewportWidth > 0 ? TableScrollViewer.ViewportWidth : TableScrollViewer.ActualWidth;
                    double maxScrollX = Math.Max(0, VirtualScrollHost.Width - vpWidth);
                    if (maxScrollX > 0)
                    {
                        var now = DateTime.UtcNow;
                        double baseOffset = (_accumulatedTargetScrollX.HasValue && (now - _lastHorizontalWheelTime).TotalMilliseconds < 350)
                            ? _accumulatedTargetScrollX.Value
                            : TableScrollViewer.HorizontalOffset;

                        double step = (delta / 120.0) * 150.0;
                        double targetX = Math.Clamp(baseOffset - step, 0, maxScrollX);
                        _accumulatedTargetScrollX = targetX;
                        _lastHorizontalWheelTime = now;

                        TableScrollViewer.ChangeView(targetX, null, null, disableAnimation: false);
                    }
                    e.Handled = true;
                }
            }
        }

        /// <summary>
        /// Sets the vertical scroll offset directly and updates the ScrollViewer view.
        /// </summary>
        /// <param name="offset">The target vertical offset in pixels.</param>
        private void SetScrollOffsetY(double offset)
        {
            _scrollOffsetY = Math.Clamp(offset, 0, Math.Max(0, VirtualScrollHost.Height - TableScrollViewer.ViewportHeight));
            TableScrollViewer.ChangeView(null, _scrollOffsetY, null, disableAnimation: false);
        }

        /// <summary>
        /// Sets the horizontal scroll offset directly, updating the ScrollViewer and header transform.
        /// </summary>
        /// <param name="offset">The target horizontal offset in pixels.</param>
        private void SetScrollOffsetX(double offset)
        {
            _scrollOffsetX = Math.Clamp(offset, 0, Math.Max(0, VirtualScrollHost.Width - TableScrollViewer.ViewportWidth));
            TableScrollViewer.ChangeView(_scrollOffsetX, null, null, disableAnimation: false);
            UpdateHeaderScrollTransform();
        }

        /// <summary>
        /// Recycles pooled rows and column cells to reflect the current viewport view window.
        /// </summary>
        private void Recycle()
        {
            int totalRows = DataProvider?.RowCount ?? 0;
            int firstVisibleRow = RowHeight > 0 ? Math.Max(0, (int)(_scrollOffsetY / RowHeight) - 2) : 0;
            double vpWidth = TableScrollViewer.ViewportWidth > 0 ? TableScrollViewer.ViewportWidth : TableScrollViewer.ActualWidth;

            _rowPool.Recycle(
                firstVisibleRow,
                _scrollOffsetY,
                _scrollOffsetX,
                vpWidth,
                RowHeight,
                totalRows,
                Columns,
                DataProvider,
                SelectedRowIndex,
                SelectedColumnIndex,
                _hoveredRowIndex);

            CullHeaders();
        }

        /// <summary>
        /// Culls off-screen header borders and splitters to minimize layout computation during horizontal scroll.
        /// </summary>
        private void CullHeaders()
        {
            double visibleLeft = _scrollOffsetX;
            double visibleRight = _scrollOffsetX + (HeaderBorder.ActualWidth > 0 ? HeaderBorder.ActualWidth : 1200.0);

            double runningLeft = 0.0;
            for (int i = 0; i < Columns.Count; i++)
            {
                double colWidth = Columns[i].Width;
                double colRight = runningLeft + colWidth;
                bool isVisible = (colRight >= visibleLeft - 60) && (runningLeft <= visibleRight + 60);

                if (i < _headerBorders.Count)
                {
                    _headerBorders[i].Visibility = isVisible ? Visibility.Visible : Visibility.Collapsed;
                }
                if (i < _headerSplitters.Count)
                {
                    _headerSplitters[i].Visibility = isVisible ? Visibility.Visible : Visibility.Collapsed;
                }

                runningLeft += colWidth;
            }
        }

        #endregion

        #region Pointer Selection & In-Place Editing

        /// <summary>
        /// Handles pointer press events on the virtual canvas to select rows/cells and initiate double-click cell editing.
        /// </summary>
        private void OnViewportPointerPressed(object sender, PointerRoutedEventArgs e)
        {
            var point = e.GetCurrentPoint(VirtualCanvas).Position;
            int totalRows = DataProvider?.RowCount ?? 0;
            int hitRow = RowHeight > 0 ? (int)(point.Y / RowHeight) : -1;

            if (hitRow >= 0 && hitRow < totalRows)
            {
                int hitCol = HitTestColumn(point.X);
                SelectedRowIndex = hitRow;
                SelectedColumnIndex = hitCol;
                Focus(FocusState.Programmatic);

                // Detect double-click for in-place editing
                var now = DateTime.UtcNow;
                var dist = Math.Abs(point.X - _lastClickPos.X) + Math.Abs(point.Y - _lastClickPos.Y);
                if ((now - _lastClickTime).TotalMilliseconds < 450 && dist < 6)
                {
                    BeginCellEdit(hitRow, hitCol);
                    _lastClickTime = DateTime.MinValue;
                }
                else
                {
                    _lastClickTime = now;
                    _lastClickPos = point;
                }
            }
            else
            {
                SelectedRowIndex = -1;
                SelectedColumnIndex = -1;
            }

            Recycle();
        }

        /// <summary>
        /// Tracks pointer hover states over visible table rows.
        /// </summary>
        private void OnViewportPointerMoved(object sender, PointerRoutedEventArgs e)
        {
            var point = e.GetCurrentPoint(VirtualCanvas).Position;
            int totalRows = DataProvider?.RowCount ?? 0;
            int hitRow = RowHeight > 0 ? (int)(point.Y / RowHeight) : -1;

            if (hitRow >= 0 && hitRow < totalRows)
            {
                if (_hoveredRowIndex != hitRow)
                {
                    _hoveredRowIndex = hitRow;
                    Recycle();
                }
            }
            else if (_hoveredRowIndex != -1)
            {
                _hoveredRowIndex = -1;
                Recycle();
            }
        }

        /// <summary>
        /// Clears row hover states when the pointer exits the table canvas bounds.
        /// </summary>
        private void OnViewportPointerExited(object sender, PointerRoutedEventArgs e)
        {
            if (_hoveredRowIndex != -1)
            {
                _hoveredRowIndex = -1;
                Recycle();
            }
        }

        /// <summary>
        /// Determines the 0-based column index matching the specified visual horizontal position.
        /// </summary>
        /// <param name="visualX">The horizontal X coordinate relative to the table virtual content.</param>
        /// <returns>The matching column index, or -1 if outside bounds.</returns>
        private int HitTestColumn(double visualX)
        {
            double runningLeft = 0.0;
            for (int i = 0; i < Columns.Count; i++)
            {
                if (visualX >= runningLeft && visualX < runningLeft + Columns[i].Width)
                {
                    return i;
                }
                runningLeft += Columns[i].Width;
            }
            return -1;
        }

        /// <summary>
        /// Calculates the left offset in pixels for the column at the specified index.
        /// </summary>
        /// <param name="colIndex">The 0-based column index.</param>
        /// <returns>The cumulative horizontal offset from the start of the table.</returns>
        private double GetColumnOffset(int colIndex)
        {
            double runningLeft = 0.0;
            for (int i = 0; i < colIndex && i < Columns.Count; i++)
            {
                runningLeft += Columns[i].Width;
            }
            return runningLeft;
        }

        /// <summary>
        /// Opens the in-place cell editor overlay at the specified row and column coordinates.
        /// </summary>
        /// <param name="rowIndex">The 0-based data row index.</param>
        /// <param name="colIndex">The 0-based column index.</param>
        private void BeginCellEdit(int rowIndex, int colIndex)
        {
            if (DataProvider == null || rowIndex < 0 || colIndex < 0 || colIndex >= Columns.Count) return;
            if (!DataProvider.IsCellEditable(rowIndex, colIndex)) return;

            _editingRowIndex = rowIndex;
            _editingColumnIndex = colIndex;

            double cellTop = rowIndex * RowHeight;
            double cellLeft = GetColumnOffset(colIndex);

            Canvas.SetTop(CellEditorOverlay, cellTop);
            Canvas.SetLeft(CellEditorOverlay, cellLeft);
            CellEditorOverlay.Width = Columns[colIndex].Width;
            CellEditorOverlay.Height = RowHeight;

            CellEditorOverlay.Text = DataProvider.GetCellText(rowIndex, colIndex);
            CellEditorOverlay.Visibility = Visibility.Visible;
            CellEditorOverlay.Focus(FocusState.Programmatic);
            CellEditorOverlay.SelectAll();
        }

        /// <summary>
        /// Commits modifications from the in-place editor to the active data provider.
        /// </summary>
        private void CommitCellEdit()
        {
            if (_editingRowIndex < 0 || _editingColumnIndex < 0 || DataProvider == null)
            {
                CellEditorOverlay.Visibility = Visibility.Collapsed;
                return;
            }

            int r = _editingRowIndex;
            int c = _editingColumnIndex;
            string original = DataProvider.GetCellText(r, c);
            string updated = CellEditorOverlay.Text;

            _editingRowIndex = -1;
            _editingColumnIndex = -1;
            CellEditorOverlay.Visibility = Visibility.Collapsed;

            if (!string.Equals(original, updated, StringComparison.Ordinal))
            {
                DataProvider.SetCellText(r, c, updated);
                var editArgs = new VirtualTableCellEditEventArgs(r, c, original, updated);
                CellEdited?.Invoke(this, editArgs);

                var editParam = CellEditedCommandParameter ?? editArgs;
                if (CellEditedCommand != null && CellEditedCommand.CanExecute(editParam))
                {
                    CellEditedCommand.Execute(editParam);
                }
            }

            Focus(FocusState.Programmatic);
            Recycle();
        }

        /// <summary>
        /// Cancels the current in-place editing session without modifying the data provider.
        /// </summary>
        private void CancelCellEdit()
        {
            _editingRowIndex = -1;
            _editingColumnIndex = -1;
            CellEditorOverlay.Visibility = Visibility.Collapsed;
            Focus(FocusState.Programmatic);
            Recycle();
        }

        /// <summary>
        /// Handles Enter and Escape keys on the active cell editor overlay.
        /// </summary>
        private void OnCellEditorKeyDown(object sender, KeyRoutedEventArgs e)
        {
            if (e.Key == VirtualKey.Enter)
            {
                CommitCellEdit();
                e.Handled = true;
            }
            else if (e.Key == VirtualKey.Escape)
            {
                CancelCellEdit();
                e.Handled = true;
            }
        }

        /// <summary>
        /// Automatically commits pending cell edits when the editor overlay loses focus.
        /// </summary>
        private void OnCellEditorLostFocus(object sender, RoutedEventArgs e)
        {
            if (CellEditorOverlay.Visibility == Visibility.Visible)
            {
                CommitCellEdit();
            }
        }

        #endregion

        #region Keyboard Navigation & Clipboard

        /// <summary>
        /// Handles keyboard navigation (Arrow keys, PageUp/Down, Home, End, Enter, Ctrl+C) on the table.
        /// </summary>
        private void OnTableKeyDown(object sender, KeyRoutedEventArgs e)
        {
            int totalRows = DataProvider?.RowCount ?? 0;
            if (totalRows == 0) return;

            int visibleRows = TableScrollViewer.ViewportHeight > 0 && RowHeight > 0 ? (int)(TableScrollViewer.ViewportHeight / RowHeight) : 10;

            switch (e.Key)
            {
                case VirtualKey.Up:
                    SelectedRowIndex = Math.Max(0, SelectedRowIndex - 1);
                    ScrollToRow(SelectedRowIndex);
                    e.Handled = true;
                    break;

                case VirtualKey.Down:
                    SelectedRowIndex = Math.Min(totalRows - 1, SelectedRowIndex + 1);
                    ScrollToRow(SelectedRowIndex);
                    e.Handled = true;
                    break;

                case VirtualKey.Left:
                    if (SelectedColumnIndex > 0)
                    {
                        SelectedColumnIndex--;
                    }
                    e.Handled = true;
                    break;

                case VirtualKey.Right:
                    if (SelectedColumnIndex < Columns.Count - 1)
                    {
                        SelectedColumnIndex++;
                    }
                    e.Handled = true;
                    break;

                case VirtualKey.PageUp:
                    SelectedRowIndex = Math.Max(0, SelectedRowIndex - visibleRows);
                    ScrollToRow(SelectedRowIndex);
                    e.Handled = true;
                    break;

                case VirtualKey.PageDown:
                    SelectedRowIndex = Math.Min(totalRows - 1, SelectedRowIndex + visibleRows);
                    ScrollToRow(SelectedRowIndex);
                    e.Handled = true;
                    break;

                case VirtualKey.Home:
                    SelectedRowIndex = 0;
                    ScrollToRow(0);
                    e.Handled = true;
                    break;

                case VirtualKey.End:
                    SelectedRowIndex = totalRows - 1;
                    ScrollToRow(totalRows - 1);
                    e.Handled = true;
                    break;

                case VirtualKey.Enter:
                    if (SelectedRowIndex >= 0 && SelectedColumnIndex >= 0)
                    {
                        BeginCellEdit(SelectedRowIndex, SelectedColumnIndex);
                        e.Handled = true;
                    }
                    break;

                case VirtualKey.C:
                    if ((InputKeyboardSource.GetKeyStateForCurrentThread(VirtualKey.Control) & CoreVirtualKeyStates.Down) == CoreVirtualKeyStates.Down)
                    {
                        CopySelectionToClipboard();
                        e.Handled = true;
                    }
                    break;
            }

            Recycle();
        }

        /// <summary>
        /// Copies the currently selected cell or full row text formatted as tab-separated values to the Windows clipboard.
        /// </summary>
        private void CopySelectionToClipboard()
        {
            if (DataProvider == null || SelectedRowIndex < 0 || SelectedRowIndex >= DataProvider.RowCount) return;

            string textToCopy;
            if (SelectedColumnIndex >= 0 && SelectedColumnIndex < Columns.Count)
            {
                textToCopy = DataProvider.GetCellText(SelectedRowIndex, SelectedColumnIndex);
            }
            else
            {
                var sb = new StringBuilder();
                for (int c = 0; c < Columns.Count; c++)
                {
                    if (c > 0) sb.Append('\t');
                    sb.Append(DataProvider.GetCellText(SelectedRowIndex, c));
                }
                textToCopy = sb.ToString();
            }

            var package = new DataPackage();
            package.SetText(textToCopy);
            Clipboard.SetContent(package);
        }

        #endregion

        /// <summary>
        /// Resolves a theme brush from the application resource dictionary with a fallback.
        /// </summary>
        /// <param name="resourceKey">The key of the resource to lookup.</param>
        /// <param name="fallback">The fallback brush if not found.</param>
        /// <returns>The resolved or fallback brush.</returns>
        private static Brush ResolveThemeBrush(string resourceKey, Brush fallback)
        {
            if (Application.Current != null && Application.Current.Resources.TryGetValue(resourceKey, out var res) && res is Brush brush)
            {
                return brush;
            }
            return fallback;
        }

        /// <summary>
        /// Specialized handle element allowing protected cursor assignment for column splitter handles.
        /// Derives from <see cref="Grid"/> to ensure a hit-testable DirectComposition visual surface without requiring a ControlTemplate.
        /// </summary>
        private sealed class SplitterHandle : Grid
        {
            /// <summary>
            /// Initializes a new instance of the <see cref="SplitterHandle"/> class with a transparent hit-testable background.
            /// </summary>
            public SplitterHandle()
            {
                Background = new SolidColorBrush(Colors.Transparent);
            }

            /// <summary>
            /// Sets the protected system cursor for this splitter handle.
            /// </summary>
            /// <param name="cursor">The system cursor to display on hover.</param>
            public void SetCursor(InputCursor cursor)
            {
                ProtectedCursor = cursor;
            }
        }
    }
}
