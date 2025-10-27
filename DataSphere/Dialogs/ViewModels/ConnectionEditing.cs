using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using static DataSphere.Resources.ThemeConfigs;

namespace DataSphere.Dialogs.ViewModels
{
    public partial class ConnectionEditing : ObservableObject, IDataErrorInfo
    {
        private bool _isInitialized = false;

        public ConnectionEditing()
        {
            if (!_isInitialized)
                InitializeViewModel();
        }

        private void InitializeViewModel()
        {
            _isInitialized = true;
        }

        [ObservableProperty]
        private bool _isAllowSubmit = false;

        private void MakeAllowSubmit()
        {
            IsAllowSubmit = !string.IsNullOrEmpty(ConnectionName);
        }

        [ObservableProperty]
        private string _connectionName = string.Empty;

        [ObservableProperty]
        private string _connectionHost = "127.0.0.1";

        [ObservableProperty]
        private int _connectionPort = 3306;

        [ObservableProperty]
        private string _connectionUser = "root";

        [ObservableProperty]
        private string _connectionPassword = string.Empty;

        [ObservableProperty]
        private ObservableCollection<DatabaseTypes> _databaseTypes = new()
        {
            new DatabaseTypes() { Value = DatabaseType.MySql },
        };

        [ObservableProperty]
        private DatabaseTypes _databaseSelectedType = new DatabaseTypes() { Value = DatabaseType.MySql };

        public string Error => string.Empty;

        partial void OnConnectionNameChanged(string? oldValue, string newValue)
        {
            MakeAllowSubmit();
        }

        public string this[string columnName]
        {
            get
            {
                switch (columnName)
                {
                    case nameof(ConnectionName):
                        if (string.IsNullOrWhiteSpace(ConnectionName))
                            return "Connection name is required";
                        break;
                    case nameof(ConnectionHost):
                        if (string.IsNullOrWhiteSpace(ConnectionHost))
                            return "Connection Host name is required";
                        break;
                    case nameof(ConnectionUser):
                        if (string.IsNullOrWhiteSpace(ConnectionUser))
                            return "Connection User name is required";
                        break;
                }
                return string.Empty;
            }
        }

        public ConnectionModel ToConnectionModel()
        {
            return new ConnectionModel()
            {
                Name = ConnectionName,
                Type = DatabaseSelectedType,
                Host = ConnectionHost,
                Port = ConnectionPort,
                User = ConnectionUser,
                Password = ConnectionPassword,
            };
        }

        public void SetModel(ConnectionModel? model)
        {
            if (model != null)
            {
                ConnectionName = model.Name;
                ConnectionHost = model.Host;
                ConnectionPort = model.Port;
                ConnectionUser = model.User;
                ConnectionPassword = model.Password;
            }
        }
    }
}
