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
        private string _connectionHost = string.Empty;

        [ObservableProperty]
        private int _connectionPort = 3306;

        [ObservableProperty]
        private string _connectionUser = string.Empty;

        [ObservableProperty]
        private string _connectionPassword = string.Empty;

        public string Error => string.Empty;

        partial void OnConnectionNameChanged(string? oldValue, string newValue)
        {
            MakeAllowSubmit();
        }

        public string this[string columnName]
        {
            get
            {
                if (string.IsNullOrWhiteSpace(ConnectionName) ||
                    string.IsNullOrWhiteSpace(ConnectionHost) ||
                    string.IsNullOrWhiteSpace(ConnectionUser) ||
                    string.IsNullOrWhiteSpace(ConnectionPassword)
                ) {
                    return "error";
                }
                return string.Empty;
            }
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
