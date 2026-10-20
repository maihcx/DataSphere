using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using DataSphere.Models;
using DataSphere.Models.Database;
using DataSphere.Services.Database.Interface;
using DataSphere.Utils;

namespace DataSphere.ViewModels.Pages.DatabaseGroup
{
    /// <summary>
    /// ViewModel managing paginated table record exploration, page size selection, and queries.
    /// </summary>
    public partial class DataControlViewModel : ObservableObject, IDisposable
    {
        private bool _disposed;
        private readonly IDatabaseConnection _connection;
        private readonly DatabaseInfo _database;
        private readonly Table _table;

        /// <summary>
        /// Gets or sets the active paginated table records and columns model.
        /// </summary>
        [ObservableProperty]
        public partial TableDataPage? DataPage { get; set; }

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
        /// Gets a value indicating whether the user can navigate to the previous page.
        /// </summary>
        public bool CanGoPrevious => CurrentPage > 1 && !IsLoading;

        /// <summary>
        /// Gets a value indicating whether the user can navigate to the next page.
        /// </summary>
        public bool CanGoNext => DataPage != null && CurrentPage < DataPage.TotalPages && !IsLoading;

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

        partial void OnCurrentPageChanged(int value)
        {
            OnPropertyChanged(nameof(CanGoPrevious));
            OnPropertyChanged(nameof(CanGoNext));
        }

        partial void OnIsLoadingChanged(bool value)
        {
            OnPropertyChanged(nameof(CanGoPrevious));
            OnPropertyChanged(nameof(CanGoNext));
        }

        /// <summary>
        /// Asynchronously queries and loads the specified page slice from the database engine.
        /// </summary>
        /// <param name="page">The 1-based page number.</param>
        public async Task LoadPageAsync(int page)
        {
            if (IsLoading) return;
            IsLoading = true;

            try
            {
                var result = await _connection.GetTableDataPageAsync(_database.Name, _table.Name, page, PageSize);
                DataPage = result;
                CurrentPage = result.CurrentPage;

                PageSummaryText = LanguageBase.GetLangValue(
                    "pagination_page_info",
                    result.CurrentPage,
                    Math.Max(1, result.TotalPages),
                    result.TotalRecords);
            }
            catch (Exception ex)
            {
                PageSummaryText = $"Error: {ex.Message}";
            }
            finally
            {
                IsLoading = false;
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

        /// <inheritdoc/>
        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;

            DataPage?.Rows.Clear();
            DataPage?.Columns.Clear();
            DataPage = null;

            GC.SuppressFinalize(this);
        }
    }
}
