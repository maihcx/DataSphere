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
            _ = ConnectionStorageService.SaveAsync(ConnectItems);
            UpdateViewVisibility();
        }

        private void OnConnectionPropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            _ = ConnectionStorageService.SaveAsync(ConnectItems);
            UpdateViewVisibility();
        }

        private void ModelInitialize(ConnectionModel model, ConnectionModel? parent = null)
        {
            model.Parent = parent;

            model.InitializeRuntimeProperties(
                addConnectionCallback: async folder =>
                {
                    var result = await _dialogService.ShowConnectionEditingDialogAsync();
                    if (result != null)
                    {
                        ModelInitialize(result, folder);
                        folder.Children.Add(result);
                        await ConnectionStorageService.SaveAsync(ConnectItems);
                    }
                },
                removeConnectionCallback: async target =>
                {
                    bool confirmed = await _dialogService.ShowConfirmationDialogAsync(
                        "dialog_delete_connection_title",
                        "dialog_delete_connection_message",
                        new object[] { target.Name });

                    if (confirmed)
                    {
                        if (target.Parent != null)
                        {
                            target.Parent.Children.Remove(target);
                        }
                        else
                        {
                            ConnectItems.Remove(target);
                        }
                        await ConnectionStorageService.SaveAsync(ConnectItems);
                        UpdateViewVisibility();
                    }
                },
                editConnectionCallback: async target =>
                {
                    var result = await _dialogService.ShowConnectionEditingDialogAsync(target);
                    if (result != null)
                    {
                        target.Name = result.Name;
                        target.Host = result.Host;
                        target.Port = result.Port;
                        target.User = result.User;
                        target.Password = result.Password;
                        await ConnectionStorageService.SaveAsync(ConnectItems);
                    }
                },
                startConnectionCallback: target =>
                {
                    OnOpenConnection?.Invoke(target);
                }
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
        /// Command to add a new grouping folder to the connection explorer tree.
        /// </summary>
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
