using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using DataSphere.Controls.VirtualTable;
using DataSphere.Models;
using DataSphere.Models.Database;
using DataSphere.Services.Database.Interface;
using DataSphere.Utils;

namespace DataSphere.ViewModels.Pages.DatabaseGroup
{
    /// <summary>
    /// ViewModel managing paginated table record exploration, server-side sorting, query cancellation, and in-place cell editing.
    /// </summary>
    public partial class DataControlViewModel : ObservableObject, IDisposable
    {
        private bool _disposed;
        private readonly IDatabaseConnection _connection;
        private readonly DatabaseInfo _database;
        private readonly Table _table;
        private CancellationTokenSource? _queryCts;

        /// <summary>
        /// Gets or sets the active paginated table records and columns model.
        /// </summary>
        [ObservableProperty]
        public partial TableDataPage? DataPage { get; set; }

        /// <summary>
        /// Gets or sets the active virtual table data provider adapter for declarative XAML binding.
        /// </summary>
        [ObservableProperty]
        public partial IVirtualTableDataProvider? TableDataProvider { get; set; }

        /// <summary>
        /// Gets or sets the active 1-based page index.
        /// </summary>
        [ObservableProperty]
        public partial int CurrentPage { get; set; } = 1;

        /// <summary>
        /// Gets the available page size options for selection.
        /// </summary>
        public ObservableCollection<int> PageSizes { get; } = new() { 100, 500, 1000 };

        /// <summary>
        /// Gets or sets the maximum row count per page.
        /// </summary>
        [ObservableProperty]
        public partial int PageSize { get; set; } = 100;

        /// <summary>
        /// Gets or sets a value indicating whether records are currently being fetched.
        /// </summary>
        [ObservableProperty]
        public partial bool IsLoading { get; set; }

        /// <summary>
        /// Gets or sets the pagination status summary text (e.g. "Page 1 of 42").
        /// </summary>
        [ObservableProperty]
        public partial string PageSummaryText { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets an informational notice regarding in-place editing status.
        /// </summary>
        [ObservableProperty]
        public partial string EditingNoticeText { get; set; } = string.Empty;

        /// <summary>
        /// Gets a value indicating whether the user can navigate to the previous page.
        /// </summary>
        public bool CanGoPrevious => CurrentPage > 1 && !IsLoading;

        /// <summary>
        /// Gets a value indicating whether the user can navigate to the next page.
        /// </summary>
        public bool CanGoNext => DataPage != null && CurrentPage < DataPage.TotalPages && !IsLoading;

        /// <summary>
        /// Gets a value indicating whether the underlying table has defined primary keys.
        /// </summary>
        public bool HasPrimaryKeys => _table.PrimaryKeys != null && _table.PrimaryKeys.Count > 0;

        /// <summary>
        /// Gets a value indicating whether there are staged modifications that can be committed to the database.
        /// </summary>
        public bool CanCommit => !IsLoading && HasPrimaryKeys && (DataPage?.HasDirtyRows ?? false);

        /// <summary>
        /// Gets a value indicating whether there are staged modifications that can be reverted.
        /// </summary>
        public bool CanDiscard => !IsLoading && (DataPage?.HasDirtyRows ?? false);

        /// <summary>
        /// Gets or sets the active column sort descriptor, or <c>null</c> if natural ordering is active.
        /// </summary>
        [ObservableProperty]
        public partial ColumnSortDescriptor? ActiveSort { get; set; }

        /// <summary>
        /// Initializes a new instance of the <see cref="DataControlViewModel"/> class.
        /// </summary>
        /// <param name="connection">The active database connection session.</param>
        /// <param name="database">The parent database schema.</param>
        /// <param name="table">The target table definition.</param>
        public DataControlViewModel(IDatabaseConnection connection, DatabaseInfo database, Table table)
        {
            _connection = connection ?? throw new ArgumentNullException(nameof(connection));
            _database = database ?? throw new ArgumentNullException(nameof(database));
            _table = table ?? throw new ArgumentNullException(nameof(table));

            _ = LoadPageAsync(1);
        }

        partial void OnPageSizeChanged(int value)
        {
            CurrentPage = 1;
            _ = LoadPageAsync(1);
        }

        partial void OnDataPageChanged(TableDataPage? value)
        {
            UpdateTableDataProvider();
        }

        /// <summary>
        /// Updates the virtual table data provider adapter based on current data page, primary key, and sort state.
        /// </summary>
        private void UpdateTableDataProvider()
        {
            if (DataPage != null)
            {
                TableDataProvider = new TableDataPageAdapter(DataPage, HasPrimaryKeys, ActiveSort);
            }
            else
            {
                TableDataProvider = null;
            }
        }

        partial void OnCurrentPageChanged(int value)
        {
            OnPropertyChanged(nameof(CanGoPrevious));
            OnPropertyChanged(nameof(CanGoNext));
        }

        partial void OnIsLoadingChanged(bool value)
        {
            OnPropertyChanged(nameof(CanGoPrevious));
            OnPropertyChanged(nameof(CanGoNext));
            OnPropertyChanged(nameof(CanCommit));
            OnPropertyChanged(nameof(CanDiscard));
        }

        /// <summary>
        /// Notifies the UI and commands that in-place editing dirty states have changed.
        /// </summary>
        public void NotifyDirtyStateChanged()
        {
            OnPropertyChanged(nameof(CanCommit));
            OnPropertyChanged(nameof(CanDiscard));
            CommitChangesCommand.NotifyCanExecuteChanged();
            DiscardChangesCommand.NotifyCanExecuteChanged();
        }

        /// <summary>
        /// Cancels any active in-flight database query immediately.
        /// </summary>
        public void CancelActiveQuery()
        {
            if (_queryCts != null && !_queryCts.IsCancellationRequested)
            {
                _queryCts.Cancel();
            }
        }

        /// <summary>
        /// Asynchronously queries and loads the specified page slice from the database engine with cancellation support.
        /// </summary>
        /// <param name="page">The 1-based page number.</param>
        public async Task LoadPageAsync(int page)
        {
            if (IsLoading)
            {
                CancelActiveQuery();
            }

            _queryCts?.Dispose();
            _queryCts = new CancellationTokenSource();
            var token = _queryCts.Token;

            IsLoading = true;

            try
            {
                if (_table.PrimaryKeys == null || _table.PrimaryKeys.Count == 0)
                {
                    try
                    {
                        var pks = await _connection.GetPrimaryKeysAsync(_database.Name, _table.Name, token).ConfigureAwait(true);
                        if (pks != null && pks.Count > 0)
                        {
                            _table.PrimaryKeys = pks.ToList();
                        }
                    }
                    catch
                    {
                        // Non-fatal schema introspection failure
                    }
                }

                OnPropertyChanged(nameof(HasPrimaryKeys));
                OnPropertyChanged(nameof(CanCommit));

                if (!HasPrimaryKeys)
                {
                    EditingNoticeText = LanguageBase.GetLangValue("msg_no_primary_key_edit_disabled");
                }
                else
                {
                    EditingNoticeText = string.Empty;
                }

                var result = await _connection.GetTableDataPageAsync(_database.Name, _table.Name, page, PageSize, ActiveSort, token);
                if (token.IsCancellationRequested) return;

                DataPage = result;
                CurrentPage = result.CurrentPage;

                string prefix = result.IsEstimatedTotal ? "~" : string.Empty;
                PageSummaryText = LanguageBase.GetLangValue(
                    "pagination_page_info",
                    result.CurrentPage,
                    Math.Max(1, result.TotalPages),
                    $"{prefix}{result.TotalRecords:N0}");

                NotifyDirtyStateChanged();
            }
            catch (OperationCanceledException)
            {
                // Query was cancelled by user navigation or rapid switching; exit cleanly
            }
            catch (Exception ex)
            {
                if (!token.IsCancellationRequested)
                {
                    PageSummaryText = $"Error: {ex.Message}";
                }
            }
            finally
            {
                if (!token.IsCancellationRequested)
                {
                    IsLoading = false;
                }
            }
        }

        /// <summary>
        /// Command to navigate to the previous page slice.
        /// </summary>
        [RelayCommand]
        public async Task PreviousPageAsync()
        {
            if (CanGoPrevious)
            {
                await LoadPageAsync(CurrentPage - 1);
            }
        }

        /// <summary>
        /// Command to navigate to the next page slice.
        /// </summary>
        [RelayCommand]
        public async Task NextPageAsync()
        {
            if (CanGoNext)
            {
                await LoadPageAsync(CurrentPage + 1);
            }
        }

        /// <summary>
        /// Command to refresh the current table page slice.
        /// </summary>
        [RelayCommand]
        public async Task RefreshAsync()
        {
            await LoadPageAsync(CurrentPage);
        }

        /// <summary>
        /// Asynchronously sorts the entire database table via server-side SQL query (ORDER BY) and resets to page 1.
        /// </summary>
        /// <param name="columnIndex">The zero-based column index.</param>
        /// <param name="direction">The desired sort direction.</param>
        /// <param name="columnName">The column name.</param>
        /// <param name="dataType">The SQL data type of the column.</param>
        public async Task SortByServerColumnAsync(int columnIndex, ColumnSortDirection direction, string columnName, string dataType)
        {
            ActiveSort = direction == ColumnSortDirection.None
                ? null
                : new ColumnSortDescriptor(columnIndex, columnName, direction, dataType);

            await LoadPageAsync(1);
        }

        /// <summary>
        /// Commits all staged row modifications to the database engine via parameterized UPDATE statements.
        /// </summary>
        [RelayCommand(CanExecute = nameof(CanCommit))]
        public async Task CommitChangesAsync()
        {
            if (!CanCommit || DataPage == null) return;
            IsLoading = true;

            try
            {
                var updates = new List<PendingRowUpdate>();
                foreach (var row in DataPage.Rows.Where(r => r.IsDirty))
                {
                    var changed = new Dictionary<string, string>();
                    foreach (int colIdx in row.ModifiedColumnIndices)
                    {
                        if (colIdx >= 0 && colIdx < DataPage.Columns.Count)
                        {
                            changed[DataPage.Columns[colIdx].Name] = row[colIdx];
                        }
                    }

                    var pkValues = new Dictionary<string, string>();
                    foreach (var pk in _table.PrimaryKeys)
                    {
                        int pkColIdx = -1;
                        for (int c = 0; c < DataPage.Columns.Count; c++)
                        {
                            if (string.Equals(DataPage.Columns[c].Name, pk, StringComparison.OrdinalIgnoreCase))
                            {
                                pkColIdx = c;
                                break;
                            }
                        }
                        if (pkColIdx != -1)
                        {
                            string origPkVal = pkColIdx < row.OriginalCells.Count ? row.OriginalCells[pkColIdx] : row[pkColIdx];
                            pkValues[pk] = origPkVal;
                        }
                    }

                    if (changed.Count > 0 && pkValues.Count > 0)
                    {
                        updates.Add(new PendingRowUpdate(row, changed, pkValues));
                    }
                }

                if (updates.Count > 0)
                {
                    await _connection.ExecuteUpdateRowsAsync(_database.Name, _table.Name, updates);
                    PageSummaryText = LanguageBase.GetLangValue("msg_commit_success");
                }
            }
            catch (Exception ex)
            {
                PageSummaryText = $"Error: {ex.Message}";
            }
            finally
            {
                IsLoading = false;
                NotifyDirtyStateChanged();
            }
        }

        /// <summary>
        /// Discards all staged modifications in the current view and restores original baseline values.
        /// </summary>
        [RelayCommand(CanExecute = nameof(CanDiscard))]
        public void DiscardChanges()
        {
            if (DataPage == null) return;
            foreach (var row in DataPage.Rows.Where(r => r.IsDirty))
            {
                row.RevertChanges();
            }
            UpdateTableDataProvider();
            NotifyDirtyStateChanged();
        }

        /// <summary>
        /// Command executed when user triggers a column sort on the virtual table.
        /// </summary>
        /// <param name="e">Event arguments containing the clicked column and requested sort direction.</param>
        /// <returns>A task representing the asynchronous sorting operation.</returns>
        [RelayCommand]
        private async Task SortAsync(VirtualTableSortEventArgs? e)
        {
            if (e == null || DataPage?.Columns == null) return;

            int colIndex = -1;
            for (int i = 0; i < DataPage.Columns.Count; i++)
            {
                if (string.Equals(DataPage.Columns[i].Name, e.Column.Header, StringComparison.Ordinal))
                {
                    colIndex = i;
                    break;
                }
            }

            if (colIndex < 0) return;

            var colMetadata = DataPage.Columns[colIndex];
            await SortByServerColumnAsync(colIndex, e.Direction, colMetadata.Name, colMetadata.DataType);
        }

        /// <summary>
        /// Command executed when user completes a cell modification in the virtual table.
        /// </summary>
        /// <param name="e">Event arguments containing cell coordinate and modified value details.</param>
        [RelayCommand]
        private void CellEdited(VirtualTableCellEditEventArgs? e)
        {
            NotifyDirtyStateChanged();
        }

        /// <inheritdoc/>
        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;

            CancelActiveQuery();
            _queryCts?.Dispose();
            _queryCts = null;

            DataPage?.Rows.Clear();
            DataPage?.Columns.Clear();
            DataPage = null;

            GC.SuppressFinalize(this);
        }
    }
}
