using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using CommunityToolkit.Mvvm.ComponentModel;
using static DataSphere.Resources.ThemeConfigs;

namespace DataSphere.Dialogs.ViewModels
{
    public partial class ConnectionEditing : ObservableObject, INotifyDataErrorInfo
    {
        private bool _isInitialized = false;

        private readonly TextBoxValidation textBoxValidation = new();

        public bool HasErrors => textBoxValidation.HasErrors;

        public event EventHandler<DataErrorsChangedEventArgs>? ErrorsChanged;

        public IEnumerable GetErrors(string? propertyName)
        {
            if (propertyName == null)
                return Enumerable.Empty<string>();

            return textBoxValidation.GetErrors(propertyName);
        }

        public ConnectionEditing()
        {
            if (!_isInitialized)
                InitializeViewModel();
        }

        private void InitializeViewModel()
        {
            _isInitialized = true;

            textBoxValidation.AddValidation(nameof(ConnectionName), () => ConnectionName, TextBoxValidationType.NotEmpty);
            textBoxValidation.AddValidation(nameof(ConnectionHost), () => ConnectionHost, TextBoxValidationType.NotEmpty);
            textBoxValidation.AddValidation(nameof(ConnectionUser), () => ConnectionUser, TextBoxValidationType.NotEmpty);

            textBoxValidation.OnErrorsChanged += (prop) =>
            {
                ErrorsChanged?.Invoke(this, new DataErrorsChangedEventArgs(prop));

                UpdateAllowSubmit();
            };

            textBoxValidation.ApplyValidation();
        }

        private void UpdateAllowSubmit()
        {
            IsAllowSubmit = !HasErrors;
        }

        [ObservableProperty]
        private bool _isAllowSubmit;

        [ObservableProperty]
        private string _connectionName = string.Empty;

        partial void OnConnectionNameChanged(string value)
        {
            textBoxValidation.ApplyValidation(nameof(ConnectionName));
        }

        [ObservableProperty]
        private string _connectionHost = "127.0.0.1";

        partial void OnConnectionHostChanged(string value)
        {
            textBoxValidation.ApplyValidation(nameof(ConnectionHost));
        }

        [ObservableProperty]
        private int _connectionPort = 3306;

        partial void OnConnectionPortChanged(int value)
        {
            textBoxValidation.ApplyValidation(nameof(ConnectionPort));
        }

        [ObservableProperty]
        private string _connectionUser = "root";

        partial void OnConnectionUserChanged(string value)
        {
            textBoxValidation.ApplyValidation(nameof(ConnectionUser));
        }

        [ObservableProperty]
        private string _connectionPassword = string.Empty;

        [ObservableProperty]
        private ObservableCollection<DatabaseTypes> _databaseTypes = new()
        {
            new DatabaseTypes() { Value = DatabaseType.MySql },
        };

        [ObservableProperty]
        private DatabaseTypes _databaseSelectedType = new DatabaseTypes() { Value = DatabaseType.MySql };

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