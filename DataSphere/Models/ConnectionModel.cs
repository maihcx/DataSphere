using System.Text.Json.Serialization;

namespace DataSphere.Models
{
    public class ConnectionModel : INotifyPropertyChanged
    {
        public event PropertyChangedEventHandler? PropertyChanged;

        public string Name
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Name));
            }
        }

        public bool IsEditing
        {
            get => field;
            set 
            { 
                field = value; 
                OnPropertyChanged(); 
            }
        }

        public DatabaseTypes? Type
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Type));
            }
        }

        public string Host
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Host));
            }
        }

        public string User
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(User));
            }
        }

        public string Password
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Password));
            }
        }
        public int Port
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Port));
            }
        }

        [JsonIgnore]
        public SymbolIcon Icon
        {
            get
            {
                switch (Type?.Value)
                {
                    case DatabaseType.Folder:
                        return new SymbolIcon() { Symbol = SymbolRegular.Folder16 };

                    case DatabaseType.MySql:
                        return new SymbolIcon() { Symbol = SymbolRegular.Database16 };
                }
                return new SymbolIcon() { Symbol = SymbolRegular.QuestionCircle16 };
            }
        }

        public ObservableCollection<ConnectionModel> Children
        {
            get {
                if (field == null)
                {
                    field = new ObservableCollection<ConnectionModel>();
                }
                return field;
            }
            set 
            { 
                field = value; 
                OnPropertyChanged(); 
            }
        }

        [JsonIgnore]
        public ObservableCollection<ContextAction>? ContextMenuItems { get; set; }

        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }

        public void InitializeRuntimeProperties(
            Action<ConnectionModel>? addConnectionCallback,
            Action<ConnectionModel>? removeConnectionCallback,
            Action<ConnectionModel>? editConnectionCallback) {
            switch (Type?.Value)
            {
                case DatabaseType.Folder:
                    ContextMenuItems = new ObservableCollection<ContextAction>()
                    {
                        new ContextAction()
                        {
                            NameKey = "ctx_add_title",
                            SymbolKey = SymbolRegular.Add20.ToString(),
                            Children = new ObservableCollection<ContextAction>()
                            {
                                new ContextAction()
                                {
                                    NameKey = "ctx_mysql_title",
                                    SymbolKey = SymbolRegular.Database16.ToString(),
                                    Command = new RelayCommand(async () =>
                                    {
                                        var result = await MessengerService.ShowDialogAsync<
                                            Dialogs.Views.ConnectionEditing,
                                            Dialogs.ViewModels.ConnectionEditing>();

                                        if (result != null)
                                        {
                                            addConnectionCallback?.Invoke(result.ToConnectionModel());
                                        }
                                    })
                                }
                            }
                        },
                        new ContextAction()
                        {
                            NameKey = "ctx_rename_title",
                            SymbolKey = SymbolRegular.Rename16.ToString(),
                            Command = new RelayCommand<ConnectionModel>((param) =>
                            {
                                param!.IsEditing = true;
                            }),
                            CommandParameter = this
                        },
                        new ContextAction()
                        {
                            NameKey = "ctx_delete_title",
                            SymbolKey = SymbolRegular.Delete16.ToString(),
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
                                if (result == Wpf.Ui.Controls.MessageBoxResult.Primary && param != null)
                                {
                                    removeConnectionCallback?.Invoke(param);
                                }
                            }),
                            CommandParameter = this
                        }
                    };
                    break;

                case DatabaseType.MySql:
                    ContextMenuItems = new ObservableCollection<ContextAction>()
                    {
                        new ContextAction()
                        {
                            NameKey = "ctx_edit_title",
                            SymbolKey = SymbolRegular.Edit16.ToString(),
                            Command = new RelayCommand<ConnectionModel>((param) =>
                            {
                                if (param != null) {
                                    editConnectionCallback?.Invoke(param);
                                }
                            }),
                            CommandParameter = this
                        },
                        new ContextAction()
                        {
                            NameKey = "ctx_rename_title",
                            SymbolKey = SymbolRegular.Rename16.ToString(),
                            Command = new RelayCommand<ConnectionModel>((param) =>
                            {
                                param!.IsEditing = true;
                            }),
                            CommandParameter = this
                        },
                        new ContextAction()
                        {
                            NameKey = "ctx_delete_title",
                            SymbolKey = SymbolRegular.Delete16.ToString(),
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
                                if (result == Wpf.Ui.Controls.MessageBoxResult.Primary && param != null)
                                {
                                    removeConnectionCallback?.Invoke(param);
                                }
                            }),
                            CommandParameter = this
                        }
                    };
                    break;
            }
        }
    }
}
