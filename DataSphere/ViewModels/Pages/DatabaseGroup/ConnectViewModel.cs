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
            int index = ConnectItems.Count(c => c.Type == DatabaseType.Folder) + 1;
            var newFolder = new ConnectionModel()
            {
                Name = $"New Folder {index}",
                Type = DatabaseType.Folder

            };

            newFolder.ContextMenuItems = new ObservableCollection<ContextAction>() 
            {
                new ContextAction()
                {
                    NameKey = "ctx_rename_title",
                    Icon = new SymbolIcon() { Symbol = SymbolRegular.Edit16 },
                    Command = new RelayCommand<ConnectionModel>((param) =>
                    {
                        newFolder.IsEditing = true;
                    }),
                },
                new ContextAction()
                {
                    NameKey = "ctx_delete_title",
                    Icon = new SymbolIcon() { Symbol = SymbolRegular.Delete16 },
                    Command = new RelayCommand<ConnectionModel>(async (param) =>
                    {
                        var msgbox = new Wpf.Ui.Controls.MessageBox()
                        {
                            Title = LanguageBase.GetLangValue("msgbox_delete_ques_title"),
                            Content = LanguageBase.GetLangValue("msgbox_delete_ques_summary"),
                            CloseButtonText = LanguageBase.GetLangValue("msgbox_cancel_title"),
                            PrimaryButtonText = LanguageBase.GetLangValue("msgbox_ok_title"),
                        };
                        msgbox.Owner = Application.Current.MainWindow;
                        msgbox.WindowStartupLocation = WindowStartupLocation.CenterOwner;
                        var result = await msgbox.ShowDialogAsync();
                        if (result == Wpf.Ui.Controls.MessageBoxResult.Primary)
                        {
                            ConnectItems.Remove(newFolder);
                        }
                    })
                }
            };

            ConnectItems.Add(newFolder);
            IsEmptyView = false;
            IsNotEmptyView = true;
        }

        private void InitializeViewModel()
        {
            _isInitialized = true;

            ConnectionHandle.OnConnectLenghtChanged += (lenght) =>
            {
                IsNotEmptyView = lenght == 0;
                IsEmptyView = lenght > 0;
            };


            ViewContextItem.Add(new ContextAction()
            {
                NameKey = "ctx_add_title",
                Icon = new SymbolIcon() { Symbol = SymbolRegular.Add20 },
                Children = new ObservableCollection<ContextAction>()
                    {
                        new ContextAction()
                        {
                            NameKey = "ctx_folder_title",
                            Icon = new SymbolIcon() { Symbol = SymbolRegular.Folder16 },
                            Command = new RelayCommand(() =>
                            {
                                addFolderToTree();
                            })
                        },
                        new ContextAction()
                        {
                            NameKey = "ctx_mysql_title",
                            Icon = new SymbolIcon() { Symbol = SymbolRegular.Database16 },
                            Command = new RelayCommand(async () =>
                            {
                                var result = await MessengerService.ShowDialogAsync<Dialogs.Views.ConnectionEditing, Dialogs.ViewModels.ConnectionEditing>();
                                if (result != null)
                                {
                                }
                            })
                        }
                    }
            });
        }
    }
}
