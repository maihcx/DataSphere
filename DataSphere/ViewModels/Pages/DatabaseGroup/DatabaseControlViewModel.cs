using DataSphere.Models.Database;
using DataSphere.Services.Database;
using DataSphere.Services.Database.Interface;
using DataSphere.Views.Pages.DatabaseGroup;
using System.Collections.Generic;

namespace DataSphere.ViewModels.Pages.DatabaseGroup
{
    public partial class DatabaseControlViewModel : ObservableObject, IDisposable
    {
        private bool _disposed = false;

        private bool _isInitialized = false;

        private ConnectionModel ConnectionModel { get; set; }

        public static IDatabaseConnection? connection { get; set; }

        private DatabaseInfo? DataBaseSeleted {  get; set; }

        private Dictionary<string, WeakReference<ObservableCollection<Table>>> _tableCache = new();

        [ObservableProperty]
        private ObservableCollection<ContextAction> _databaseContextMenuItems;

        [ObservableProperty]
        private ObservableCollection<ContextAction> _rootConnectionsContextMenuItems;

        [ObservableProperty]
        private ObservableCollection<ConnectionRoot>? _rootConnections = new();

        [ObservableProperty]
        private object _selectedRootConnection = new();

        [ObservableProperty]
        private object? _rightPanelContent = null;

        public DatabaseControlViewModel(ConnectionModel connectionModel)
        {
            ConnectionModel = connectionModel;
            connection = DatabaseConnectionFactory.Create(ConnectionModel);

            if (!_isInitialized)
            {
                InitializeViewModel();
            }

            RootConnectionsContextMenuItems = new ObservableCollection<ContextAction>()
            {
                new ContextAction()
                {
                    SymbolKey = SymbolRegular.Add20.ToString(),
                    NameKey = "ctx_add_title",
                    Children = new ObservableCollection<ContextAction>()
                    {
                        new ContextAction()
                        {
                            SymbolKey = SymbolRegular.BookDatabase20.ToString(),
                            NameKey = "dbinf_database_title",
                            Command =  new RelayCommand(async () =>
                            {
                                var result = await MessengerService.ShowDialogAsync<Dialogs.Views.DatabaseEditing, Dialogs.ViewModels.DatabaseEditing>(null, null, async(v) =>
                                {
                                    v.ViewModel.InitializeViewModel(connection);
                                });

                                if (result != null)
                                {
                                    await CreateTable(result);
                                }
                            })
                        }
                    }
                }
            };

            DatabaseContextMenuItems = new ObservableCollection<ContextAction>()
            {
                new ContextAction()
                {
                    SymbolKey = SymbolRegular.Open16.ToString(),
                    NameKey = "ctx_open_title",
                    Command = new RelayCommand<DatabaseInfo>((param) =>
                    {
                        if (param != null)
                        {
                            param.IsExpanded = true;
                        }
                    })
                },
                new ContextAction()
                {
                    SymbolKey = SymbolRegular.Edit16.ToString(),
                    NameKey = "ctx_edit_title",
                    Command =  new RelayCommand<DatabaseInfo>(async (dbinfo) =>
                    {
                        var result = await MessengerService.ShowDialogAsync<Dialogs.Views.DatabaseEditing, Dialogs.ViewModels.DatabaseEditing>(dbinfo, null, async(v) =>
                        {
                            v.ViewModel.InitializeViewModel(connection);
                        });

                        if (result != null)
                        {

                        }
                    })
                },
                new ContextAction()
                {
                    SymbolKey = SymbolRegular.Add20.ToString(),
                    NameKey = "ctx_add_title",
                    Children = new ObservableCollection<ContextAction>()
                    {
                        new ContextAction()
                        {
                            SymbolKey = SymbolRegular.AppGeneric20.ToString(),
                            NameKey = "dbinf_table_title"
                        },
                        new ContextAction()
                        {
                            SymbolKey = SymbolRegular.ContentView20.ToString(),
                            NameKey = "dbinf_view_title"
                        },
                        new ContextAction()
                        {
                            SymbolKey = SymbolRegular.Code20.ToString(),
                            NameKey = "dbinf_sp_title"
                        },
                        new ContextAction()
                        {
                            SymbolKey = SymbolRegular.AppFolder20.ToString(),
                            NameKey = "dbinf_fnc_title"
                        },
                        new ContextAction()
                        {
                            SymbolKey = SymbolRegular.Settings20.ToString(),
                            NameKey = "dbinf_trigger_title"
                        },
                        new ContextAction()
                        {
                            SymbolKey = SymbolRegular.CalendarLtr20.ToString(),
                            NameKey = "dbinf_event_title"
                        }
                    }
                },
                new ContextAction()
                {
                    SymbolKey = SymbolRegular.Delete20.ToString(),
                    NameKey = "ctx_delete_title",
                    Command = new RelayCommand<DatabaseInfo>(async (dbinfo) =>
                    {
                        if (dbinfo != null)
                        {
                            await DropDatabase(dbinfo);
                        }
                    })
                }
            };
        }

        private async void InitializeViewModel()
        {
            if (connection == null) return;

            await connection.ConnectAsync();

            var databases = await connection.GetAllDatabasesAsync();

            var root = new ConnectionRoot()
            {
                Connection = ConnectionModel,
                Databases = databases ?? new ObservableCollection<DatabaseInfo>(),
                IsExpanded = true,
            };

            RootConnections?.Clear();
            RootConnections?.Add(root);

            _isInitialized = true;
        }

        public async Task LoadTablesAsync(DatabaseInfo db)
        {
            if (db == null || db.IsTablesLoaded || connection == null || _disposed)
                return;

            if (_tableCache.TryGetValue(db.Name, out var weakRef) &&
                weakRef.TryGetTarget(out var cachedTables))
            {
                db.Tables = cachedTables;
                db.IsTablesLoaded = true;
                return;
            }

            var tables = await connection.GetAllTablesAsync(db.Name);

            db.Tables?.Clear();

            if (tables != null)
            {
                foreach (var t in tables)
                    db?.Tables?.Add(t);

                if (db != null && db.Tables != null)
                {
                    _tableCache[db.Name] = new WeakReference<ObservableCollection<Table>>(db.Tables);
                }
            }

            DataBaseSeleted = db;

            db?.IsTablesLoaded = true;
        }

        private async Task CreateTable(Dialogs.ViewModels.DatabaseEditing databaseEditing)
        {
            var dbinfo = databaseEditing.ToDatabaseInfo();
            if (dbinfo != null && connection != null)
            {   
                await connection.CreateDatabase(dbinfo);
                await RefreshDatabase();
            }
        }

        private async Task DropDatabase(DatabaseInfo dbInfo)
        {
            if (connection != null)
            {
                var uiMessageBox = new Wpf.Ui.Controls.MessageBox
                {
                    Title = LanguageBase.GetLangValue("msgbox_delete_ques_title"),
                    Content = LanguageBase.GetLangValue("msgbox_drop_database_params", dbInfo.Name),
                };
                uiMessageBox.Owner = App.Current.MainWindow;
                uiMessageBox.PrimaryButtonText = LanguageBase.GetLangValue("msgbox_ok_title");
                uiMessageBox.CloseButtonText = LanguageBase.GetLangValue("msgbox_cancel_title");

                uiMessageBox.WindowStartupLocation = WindowStartupLocation.CenterOwner;

                var res = await uiMessageBox.ShowDialogAsync();

                if (res == Wpf.Ui.Controls.MessageBoxResult.Primary)
                {
                    await connection.DropDatabase(dbInfo);

                    _tableCache.Remove(dbInfo.Name);

                    RootConnections?.First().Databases.Remove(dbInfo);
                }
            }
        }

        private async Task RefreshDatabase()
        {
            if (connection == null) return;

            _tableCache.Clear();

            string? currTableName = DataBaseSeleted?.Name;

            var databases = await connection.GetAllDatabasesAsync();

            var root = new ConnectionRoot()
            {
                Connection = ConnectionModel,
                Databases = databases ?? new ObservableCollection<DatabaseInfo>(),
                IsExpanded = true,
            };

            RootConnections?.Clear();
            RootConnections?.Add(root);
        }

        partial void OnSelectedRootConnectionChanged(object? oldValue, object newValue)
        {
            if (RightPanelContent != null)
            {
                if (RightPanelContent is IDisposable page)
                {
                    page.Dispose();
                }
                RightPanelContent = null;
            }

            if (newValue is Table table)
            {
                if (DataBaseSeleted != null && connection != null)
                {
                    RightPanelContent = new DataViewControl(connection, DataBaseSeleted, table);
                }
            }
        }

        public void Dispose()
        {
            if (_disposed) return;

            _disposed = true;

            if (connection != null)
            {
                try
                {
                    Task.Run(async () => await connection.DisconnectAsync()).Wait(TimeSpan.FromSeconds(5));
                }
                catch { /* Ignore disposal errors */ }

                if (connection is IDisposable disposableConnection)
                {
                    disposableConnection.Dispose();
                }
                connection = null;
            }

            if (RootConnections != null)
            {
                foreach (var root in RootConnections)
                {
                    if (root.Databases != null)
                    {
                        foreach (var db in root.Databases)
                        {
                            db.Tables?.Clear();
                            db.Tables = null;
                        }
                        root.Databases.Clear();
                    }
                }
                RootConnections.Clear();
                RootConnections = null;
            }

            if (RightPanelContent != null)
            {
                if (RightPanelContent is IDisposable page)
                {
                    page.Dispose();
                }
                RightPanelContent = null;
            }

            DatabaseContextMenuItems?.Clear();
            RootConnectionsContextMenuItems?.Clear();

            ConnectionModel = null!;

            GC.SuppressFinalize(this);
        }

        ~DatabaseControlViewModel()
        {
            Dispose();
        }
    }
}
