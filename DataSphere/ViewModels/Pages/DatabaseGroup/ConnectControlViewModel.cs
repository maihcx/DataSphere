using System.Collections.ObjectModel;
using System.Collections.Specialized;
using System.ComponentModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using DataSphere.Models;
using DataSphere.Services;
using DataSphere.Services.Contracts;

namespace DataSphere.ViewModels.Pages.DatabaseGroup
{
    /// <summary>
    /// ViewModel managing the database connection explorer tree, empty state presentation, and connection lifecycle.
    /// </summary>
    public partial class ConnectControlViewModel : ObservableObject
    {
        private readonly IDialogService _dialogService;
        private bool _isInitialized = false;

        /// <summary>
        /// Gets or sets the action callback invoked when a connection session is requested to open.
        /// </summary>
        public Action<ConnectionModel>? OnOpenConnection { get; set; }

        /// <summary>
        /// Gets the collection of configured connections and folder nodes.
        /// </summary>
        [ObservableProperty]
        public partial ObservableCollection<ConnectionModel> ConnectItems { get; set; } = new();

        /// <summary>
        /// Gets or sets a value indicating whether connections exist in the tree.
        /// </summary>
        [ObservableProperty]
        public partial bool IsNotEmptyView { get; set; }

        /// <summary>
        /// Gets or sets a value indicating whether zero connections exist (empty state).
        /// </summary>
        [ObservableProperty]
        public partial bool IsEmptyView { get; set; } = true;

        /// <summary>
        /// Initializes a new instance of the <see cref="ConnectControlViewModel"/> class.
        /// </summary>
        /// <param name="dialogService">The dialog service for creating and editing connections.</param>
        public ConnectControlViewModel(IDialogService dialogService)
        {
            _dialogService = dialogService ?? throw new ArgumentNullException(nameof(dialogService));
            _ = InitializeViewModelAsync();
        }

        private async Task InitializeViewModelAsync()
        {
            if (_isInitialized) return;
            _isInitialized = true;

            var loaded = await ConnectionStorageService.LoadAsync().ConfigureAwait(true);
            ConnectItems = loaded;

            ConnectItems.CollectionChanged -= OnConnectionsCollectionChanged;
            ConnectItems.CollectionChanged += OnConnectionsCollectionChanged;

            foreach (var conn in ConnectItems)
            {
                ModelInitialize(conn, null);
                InitializeParentRecursive(conn, null);
            }

            UpdateViewVisibility();
        }

        private void UpdateViewVisibility()
        {
            int count = ConnectItems.Count;
            IsNotEmptyView = count > 0;
            IsEmptyView = count == 0;
        }

        private void OnConnectionsCollectionChanged(object? sender, NotifyCollectionChangedEventArgs e)
        {
            if (e.NewItems != null)
            {
                foreach (ConnectionModel item in e.NewItems)
                {
                    ModelInitialize(item, null);
                }
            }
            _ = ConnectionStorageService.SaveAsync(ConnectItems);
            UpdateViewVisibility();
        }

        private void OnConnectionPropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            _ = ConnectionStorageService.SaveAsync(ConnectItems);
            UpdateViewVisibility();
        }

        /// <summary>
        /// Initializes runtime properties, contextual command bindings, and property change listeners for a connection node and its children.
        /// </summary>
        /// <param name="model">The connection node to initialize.</param>
        /// <param name="parent">The optional parent folder node.</param>
        public void ModelInitialize(ConnectionModel model, ConnectionModel? parent = null)
        {
            model.Parent = parent;

            model.InitializeRuntimeProperties(
                addConnectionCallback: async folder => await AddConnectionToFolderAsync(folder),
                removeConnectionCallback: async target => await DeleteConnectionAsync(target),
                editConnectionCallback: async target => await EditConnectionAsync(target),
                startConnectionCallback: target => OpenConnection(target)
            );

            model.PropertyChanged -= OnConnectionPropertyChanged;
            model.PropertyChanged += OnConnectionPropertyChanged;

            if (model.Children != null)
            {
                foreach (var child in model.Children)
                {
                    ModelInitialize(child, model);
                }
            }
        }

        private static void InitializeParentRecursive(ConnectionModel model, ConnectionModel? parent)
        {
            model.Parent = parent;
            if (model.Children != null)
            {
                foreach (var child in model.Children)
                {
                    InitializeParentRecursive(child, model);
                }
            }
        }

        /// <summary>
        /// Command to open a database connection session in a workspace tab.
        /// </summary>
        /// <param name="connection">The target connection node.</param>
        [RelayCommand]
        public void OpenConnection(ConnectionModel? connection)
        {
            if (connection != null && connection.Type?.Value != DatabaseType.Folder)
            {
                OnOpenConnection?.Invoke(connection);
            }
        }

        /// <summary>
        /// Command to launch the connection editing dialog and update the connection configuration.
        /// </summary>
        /// <param name="connection">The target connection node to edit.</param>
        [RelayCommand]
        public async Task EditConnectionAsync(ConnectionModel? connection)
        {
            if (connection == null) return;

            var result = await _dialogService.ShowConnectionEditingDialogAsync(connection);
            if (result != null)
            {
                connection.Name = result.Name;
                connection.Host = result.Host;
                connection.Port = result.Port;
                connection.User = result.User;
                connection.Password = result.Password;
                await ConnectionStorageService.SaveAsync(ConnectItems);
            }
        }

        /// <summary>
        /// Command to delete a connection or folder node after user confirmation.
        /// </summary>
        /// <param name="connection">The target connection or folder node to remove.</param>
        [RelayCommand]
        public async Task DeleteConnectionAsync(ConnectionModel? connection)
        {
            if (connection == null) return;

            bool confirmed = await _dialogService.ShowConfirmationDialogAsync(
                "dialog_delete_connection_title",
                "dialog_delete_connection_message",
                new object[] { connection.Name });

            if (confirmed)
            {
                if (connection.Parent != null)
                {
                    connection.Parent.Children.Remove(connection);
                }
                else
                {
                    ConnectItems.Remove(connection);
                }
                await ConnectionStorageService.SaveAsync(ConnectItems);
                UpdateViewVisibility();
            }
        }

        /// <summary>
        /// Command to create and add a new database connection inside a specified folder node.
        /// </summary>
        /// <param name="folder">The target folder node.</param>
        [RelayCommand]
        public async Task AddConnectionToFolderAsync(ConnectionModel? folder)
        {
            if (folder == null) return;

            var result = await _dialogService.ShowConnectionEditingDialogAsync();
            if (result != null)
            {
                ModelInitialize(result, folder);
                folder.Children.Add(result);
                await ConnectionStorageService.SaveAsync(ConnectItems);
            }
        }

        /// <summary>
        /// Command to initiate inline renaming for a connection or folder node.
        /// </summary>
        /// <param name="connection">The connection or folder node to rename.</param>
        [RelayCommand]
        public void StartRename(ConnectionModel? connection)
        {
            if (connection != null)
            {
                connection.IsEditing = true;
            }
        }

        /// <summary>
        /// Command to add a new grouping folder to the connection explorer tree.
        /// </summary>
        /// <param name="folder">The target folder node.</param>
        [RelayCommand]
        public async Task AddFolderAsync()
        {
            int index = ConnectItems.Count(c => c.Type?.Value == DatabaseType.Folder) + 1;
            var newFolder = new ConnectionModel
            {
                Name = $"New Folder {index}",
                Type = new DatabaseTypes { Value = DatabaseType.Folder },
                IsEditing = true
            };

            ModelInitialize(newFolder, null);
            ConnectItems.Add(newFolder);
            await ConnectionStorageService.SaveAsync(ConnectItems);
            UpdateViewVisibility();
        }

        /// <summary>
        /// Command to launch the connection editing dialog and add a newly configured connection to the tree.
        /// </summary>
        [RelayCommand]
        public async Task NewConnectionAsync()
        {
            var result = await _dialogService.ShowConnectionEditingDialogAsync();
            if (result != null)
            {
                ModelInitialize(result, null);
                ConnectItems.Add(result);
                await ConnectionStorageService.SaveAsync(ConnectItems);
                UpdateViewVisibility();
            }
        }
    }
}
