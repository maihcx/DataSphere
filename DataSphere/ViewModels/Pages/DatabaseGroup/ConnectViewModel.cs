using System.Collections.Specialized;

namespace DataSphere.ViewModels.Pages.DatabaseGroup
{
    public partial class ConnectViewModel : ObservableObject
    {
        private bool _isInitialized = false;

        public ConnectViewModel()
        {
            if (!_isInitialized)
                InitializeViewModel();
        }

        [ObservableProperty]
        private ObservableCollection<ConnectionModel> _connectItems = new();

        [ObservableProperty]
        private ObservableCollection<ContextAction> _viewContextItem = new();

        [ObservableProperty]
        private bool _isNotEmptyView = ConnectionHandle.IsNotEmpty;

        [ObservableProperty]
        private bool _isEmptyView = !ConnectionHandle.IsNotEmpty;

        private void addFolderToTree()
        {
            int index = ConnectItems.Count(c => c.Type?.Value == DatabaseType.Folder) + 1;
            var newFolder = new ConnectionModel()
            {
                Name = $"New Folder {index}",
                Type = new DatabaseTypes() { Value = DatabaseType.Folder },
                IsEditing = true
            };

            ModelInitialize(newFolder, null);

            ConnectItems.Add(newFolder);
            IsEmptyView = false;
            IsNotEmptyView = true;
        }

        private void setModelValues(ConnectionModel from, ConnectionModel to)
        {
            to.Name = from.Name;
            to.Type = from.Type;
            to.Host = from.Host;
            to.Port = from.Port;
            to.User = from.User;
            to.Password = from.Password;
        }

        private async void SaveConnectionsAsync(object? sender, PropertyChangedEventArgs e)
        {
            await ConnectionStorageService.SaveAsync(ConnectItems);

            int lenght = ConnectItems.Count();
            IsNotEmptyView = lenght > 0;
            IsEmptyView = lenght == 0;
        }

        private async void SaveConnectionsAsync(object? sender, NotifyCollectionChangedEventArgs e)
        {
            await ConnectionStorageService.SaveAsync(ConnectItems);

            int lenght = ConnectItems.Count();
            IsNotEmptyView = lenght > 0;
            IsEmptyView = lenght == 0;
        }

        private void ModelInitialize(ConnectionModel connectionModel, ConnectionModel? parent = null)
        {
            connectionModel.InitializeRuntimeProperties(
                addConnectionCallback: model =>
                {
                    ModelInitialize(model, connectionModel);
                    connectionModel.Children.CollectionChanged -= SaveConnectionsAsync;
                    connectionModel.Children.CollectionChanged += SaveConnectionsAsync;
                    connectionModel.Children.Add(model);
                },
                removeConnectionCallback: model =>
                {
                    if (parent != null)
                    {
                        parent.Children.Remove(model);
                    }
                    else
                    {
                        ConnectItems.Remove(model);
                    }
                },
                editConnectionCallback: async model =>
                {
                    var result = await MessengerService.ShowDialogAsync<Dialogs.Views.ConnectionEditing, Dialogs.ViewModels.ConnectionEditing>(model);
                    if (result != null)
                    {
                        setModelValues(result.ToConnectionModel(), model);
                    }
                }
            );

            connectionModel.PropertyChanged -= SaveConnectionsAsync;
            connectionModel.PropertyChanged += SaveConnectionsAsync;

            foreach (var child in connectionModel.Children)
            {
                ModelInitialize(child, connectionModel);
            }
        }

        private async void InitializeViewModel()
        {
            _isInitialized = true;

            ConnectItems = await ConnectionStorageService.LoadAsync();

            ConnectItems.CollectionChanged -= SaveConnectionsAsync;
            ConnectItems.CollectionChanged += SaveConnectionsAsync;

            foreach (var conn in ConnectItems)
            {
                ModelInitialize(conn, null);
            }

            int lenght = ConnectItems.Count();
            IsNotEmptyView = lenght > 0;
            IsEmptyView = lenght == 0;

            ViewContextItem.Add(new ContextAction()
            {
                NameKey = "ctx_add_title",
                SymbolKey = SymbolRegular.Add20.ToString(),
                Children = new ObservableCollection<ContextAction>()
                {
                    new ContextAction()
                    {
                        NameKey = "ctx_folder_title",
                        SymbolKey = SymbolRegular.Folder16.ToString(),
                        Command = new RelayCommand(() =>
                        {
                            addFolderToTree();
                        })
                    },
                    new ContextAction()
                    {
                        NameKey = "ctx_mysql_title",
                        SymbolKey = SymbolRegular.Database16.ToString(),
                        Command = new RelayCommand(async () =>
                        {
                            var result = await MessengerService.ShowDialogAsync<Dialogs.Views.ConnectionEditing, Dialogs.ViewModels.ConnectionEditing>();
                            if (result != null)
                            {
                                var model = result.ToConnectionModel();
                                ModelInitialize(model, null);
                                ConnectItems.Add(model);
                            }
                        })
                    }
                }
            });
        }
    }
}
