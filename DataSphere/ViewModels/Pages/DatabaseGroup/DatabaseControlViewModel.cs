using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using DataSphere.Models;
using DataSphere.Models.Database;
using DataSphere.Services.Contracts;
using DataSphere.Services.Database;
using DataSphere.Services.Database.Interface;
using DataSphere.Views.Pages.DatabaseGroup;

namespace DataSphere.ViewModels.Pages.DatabaseGroup
{
    /// <summary>
    /// ViewModel managing an active database server session, schema discovery, and object explorer actions.
    /// </summary>
    public partial class DatabaseControlViewModel : ObservableObject, IDisposable
    {
        private bool _disposed;
        private readonly HashSet<string> _loadingDatabases = new(StringComparer.OrdinalIgnoreCase);
        private readonly ConnectionModel _connectionModel;
        private readonly IDialogService _dialogService;

        /// <summary>
        /// Gets the underlying active database connection driver.
        /// </summary>
        public IDatabaseConnection? Connection { get; private set; }

        /// <summary>
        /// Gets the collection of root connection nodes for the schema tree.
        /// </summary>
        [ObservableProperty]
        public partial ObservableCollection<ConnectionRoot> RootConnections { get; set; } = new();

        /// <summary>
        /// Gets or sets the content element rendered in the right-hand inspection panel (e.g. DataViewControl).
        /// </summary>
        [ObservableProperty]
        public partial object? RightPanelContent { get; set; }

        /// <summary>
        /// Gets or sets a value indicating whether schemas or tables are currently being loaded.
        /// </summary>
        [ObservableProperty]
        public partial bool IsLoading { get; set; }

        /// <summary>
        /// Gets or sets the error or status message if a connection or query failed.
        /// </summary>
        [ObservableProperty]
        public partial string StatusMessage { get; set; } = string.Empty;

        /// <summary>
        /// Initializes a new instance of the <see cref="DatabaseControlViewModel"/> class.
        /// </summary>
        /// <param name="connectionModel">The connection credentials and server parameters.</param>
        /// <param name="dialogService">The dialog service for database creation and drop confirmations.</param>
        public DatabaseControlViewModel(ConnectionModel connectionModel, IDialogService dialogService)
        {
            _connectionModel = connectionModel ?? throw new ArgumentNullException(nameof(connectionModel));
            _dialogService = dialogService ?? throw new ArgumentNullException(nameof(dialogService));
            Connection = DatabaseConnectionFactory.Create(connectionModel);

            _ = InitializeSessionAsync();
        }

        private async Task InitializeSessionAsync()
        {
            if (Connection == null) return;
            IsLoading = true;
            StatusMessage = "Connecting to database server...";

            try
            {
                bool connected = await Connection.ConnectAsync();
                if (!connected)
                {
                    StatusMessage = "Failed to connect to database server.";
                    return;
                }

                await RefreshDatabasesAsync();
                StatusMessage = string.Empty;
            }
            catch (Exception ex)
            {
                StatusMessage = $"Connection error: {ex.Message}";
            }
            finally
            {
                IsLoading = false;
            }
        }

        /// <summary>
        /// Refreshes the database catalog schema list from the active server session.
        /// </summary>
        [RelayCommand]
        public async Task RefreshDatabasesAsync()
        {
            if (Connection == null || !Connection.IsConnected) return;

            IsLoading = true;
            try
            {
                var databases = await Connection.GetAllDatabasesAsync();
                var root = new ConnectionRoot
                {
                    Connection = _connectionModel,
                    Databases = databases ?? new ObservableCollection<DatabaseInfo>(),
                    IsExpanded = true
                };

                RootConnections.Clear();
                RootConnections.Add(root);
            }
            catch (Exception ex)
            {
                StatusMessage = $"Failed to retrieve databases: {ex.Message}";
            }
            finally
            {
                IsLoading = false;
            }
        }

        /// <summary>
        /// Loads tables for a specified database schema lazily if not already loaded.
        /// </summary>
        /// <param name="database">The database schema to populate tables for.</param>
        public async Task LoadTablesAsync(DatabaseInfo database)
        {
            if (Connection == null || database == null || database.IsTablesLoaded) return;

            lock (_loadingDatabases)
            {
                if (!_loadingDatabases.Add(database.Name))
                {
                    return;
                }
            }

            try
            {
                var tables = await Connection.GetAllTablesAsync(database.Name);
                database.Tables?.Clear();
                if (tables != null)
                {
                    foreach (var table in tables)
                    {
                        database.Tables?.Add(table);
                    }
                }
                database.IsTablesLoaded = true;
            }
            catch (Exception ex)
            {
                StatusMessage = $"Failed to load tables for {database.Name}: {ex.Message}";
            }
            finally
            {
                lock (_loadingDatabases)
                {
                    _loadingDatabases.Remove(database.Name);
                }
            }
        }

        /// <summary>
        /// Selects a table and displays its paginated data viewport in the right panel.
        /// </summary>
        /// <param name="database">The owning database schema.</param>
        /// <param name="table">The selected table definition.</param>
        public void SelectTable(DatabaseInfo database, Table table)
        {
            if (Connection == null || database == null || table == null) return;

            if (RightPanelContent is IDisposable disposable)
            {
                disposable.Dispose();
            }

            RightPanelContent = new DataViewControl(Connection, database, table);
        }

        /// <summary>
        /// Command to launch the database creation dialog and create a new schema.
        /// </summary>
        [RelayCommand]
        public async Task NewDatabaseAsync()
        {
            if (Connection == null) return;

            var newDb = await _dialogService.ShowDatabaseEditingDialogAsync(Connection);
            if (newDb != null)
            {
                try
                {
                    await Connection.CreateDatabase(newDb);
                    await RefreshDatabasesAsync();
                }
                catch (Exception ex)
                {
                    StatusMessage = $"Failed to create database: {ex.Message}";
                }
            }
        }

        /// <summary>
        /// Command to drop a database schema following user confirmation.
        /// </summary>
        /// <param name="database">The database schema to drop.</param>
        [RelayCommand]
        public async Task DropDatabaseAsync(DatabaseInfo database)
        {
            if (Connection == null || database == null) return;

            bool confirmed = await _dialogService.ShowConfirmationDialogAsync(
                "msgbox_delete_ques_title",
                "msgbox_drop_database_params",
                new object[] { database.Name });

            if (confirmed)
            {
                try
                {
                    await Connection.DropDatabase(database);
                    await RefreshDatabasesAsync();
                    if (RightPanelContent is IDisposable disposable)
                    {
                        disposable.Dispose();
                        RightPanelContent = null;
                    }
                }
                catch (Exception ex)
                {
                    StatusMessage = $"Failed to drop database: {ex.Message}";
                }
            }
        }

        /// <inheritdoc/>
        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;

            if (RightPanelContent is IDisposable disposable)
            {
                disposable.Dispose();
                RightPanelContent = null;
            }

            if (Connection != null)
            {
                _ = Connection.DisconnectAsync();
                Connection = null;
            }

            RootConnections.Clear();
            GC.SuppressFinalize(this);
        }
    }
}
