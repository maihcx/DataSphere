using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using DataSphere.Models;
using DataSphere.Services.Database.Connection;
using DataSphere.Utils;

namespace DataSphere.ViewModels.Dialogs
{
    /// <summary>
    /// Represents a selectable database engine option item for ComboBox binding.
    /// </summary>
    public class DatabaseTypeOption
    {
        /// <summary>
        /// Gets the underlying engine type enum.
        /// </summary>
        public DatabaseType Type { get; }

        /// <summary>
        /// Gets the display name for the database engine.
        /// </summary>
        public string DisplayName { get; }

        /// <summary>
        /// Initializes a new instance of the <see cref="DatabaseTypeOption"/> class.
        /// </summary>
        /// <param name="type">The database engine type.</param>
        /// <param name="displayName">The display label.</param>
        public DatabaseTypeOption(DatabaseType type, string displayName)
        {
            Type = type;
            DisplayName = displayName;
        }

        /// <inheritdoc/>
        public override string ToString() => DisplayName;
    }

    /// <summary>
    /// ViewModel driving database connection configuration, input validation, and asynchronous connection testing.
    /// </summary>
    public partial class ConnectionEditingViewModel : ObservableObject
    {
        private readonly ConnectionModel? _originalModel;

        /// <summary>
        /// Gets the list of available database engine options for selection.
        /// </summary>
        public ObservableCollection<DatabaseTypeOption> AvailableDatabaseTypes { get; } = new();

        /// <summary>
        /// Gets or sets the selected database engine option.
        /// </summary>
        [ObservableProperty]
        public partial DatabaseTypeOption? SelectedDatabaseType { get; set; }

        /// <summary>
        /// Gets or sets the display name for this connection.
        /// </summary>
        [ObservableProperty]
        public partial string ConnectionName { get; set; } = "Localhost MySQL";

        /// <summary>
        /// Gets or sets the server host address or IP.
        /// </summary>
        [ObservableProperty]
        public partial string ConnectionHost { get; set; } = "127.0.0.1";

        /// <summary>
        /// Gets or sets the network port number for the database server.
        /// </summary>
        [ObservableProperty]
        public partial int ConnectionPort { get; set; } = 3306;

        /// <summary>
        /// Gets or sets the authentication username.
        /// </summary>
        [ObservableProperty]
        public partial string ConnectionUser { get; set; } = "root";

        /// <summary>
        /// Gets or sets the authentication password.
        /// </summary>
        [ObservableProperty]
        public partial string ConnectionPassword { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the default schema/database name (optional).
        /// </summary>
        [ObservableProperty]
        public partial string ConnectionDatabase { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets a value indicating whether an asynchronous connection test is currently active.
        /// </summary>
        [ObservableProperty]
        public partial bool IsTesting { get; set; }

        /// <summary>
        /// Gets or sets the status feedback message resulting from a connection test.
        /// </summary>
        [ObservableProperty]
        public partial string TestStatusMessage { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets a value indicating whether the connection test succeeded.
        /// </summary>
        [ObservableProperty]
        public partial bool IsTestSuccess { get; set; }

        /// <summary>
        /// Gets or sets a value indicating whether the connection test failed.
        /// </summary>
        [ObservableProperty]
        public partial bool IsTestError { get; set; }

        /// <summary>
        /// Gets a value indicating whether all mandatory parameters are populated to permit saving.
        /// </summary>
        public bool IsAllowSubmit =>
            SelectedDatabaseType != null &&
            !string.IsNullOrWhiteSpace(ConnectionName) &&
            !string.IsNullOrWhiteSpace(ConnectionHost) &&
            !string.IsNullOrWhiteSpace(ConnectionUser) &&
            ConnectionPort > 0 && ConnectionPort <= 65535;

        /// <summary>
        /// Initializes a new instance of the <see cref="ConnectionEditingViewModel"/> class.
        /// </summary>
        /// <param name="existing">Optional existing connection to edit.</param>
        public ConnectionEditingViewModel(ConnectionModel? existing = null)
        {
            _originalModel = existing;

            AvailableDatabaseTypes.Add(new DatabaseTypeOption(DatabaseType.MySql, "MySQL"));
            AvailableDatabaseTypes.Add(new DatabaseTypeOption(DatabaseType.MariaDB, "MariaDB"));
            AvailableDatabaseTypes.Add(new DatabaseTypeOption(DatabaseType.PostgreSql, "PostgreSQL"));

            if (existing != null)
            {
                ConnectionName = existing.Name;
                ConnectionHost = string.IsNullOrEmpty(existing.Host) ? "127.0.0.1" : existing.Host;
                ConnectionPort = existing.Port <= 0 ? 3306 : existing.Port;
                ConnectionUser = string.IsNullOrEmpty(existing.User) ? "root" : existing.User;
                ConnectionPassword = existing.Password;
                ConnectionDatabase = existing.Database ?? string.Empty;

                var existingType = existing.Type?.Value ?? DatabaseType.MySql;
                SelectedDatabaseType = AvailableDatabaseTypes.FirstOrDefault(o => o.Type == existingType) ?? AvailableDatabaseTypes[0];
            }
            else
            {
                SelectedDatabaseType = AvailableDatabaseTypes[0];
            }
        }

        partial void OnSelectedDatabaseTypeChanged(DatabaseTypeOption? value)
        {
            if (value == null) return;

            if (value.Type == DatabaseType.PostgreSql && (ConnectionPort == 3306 || ConnectionPort <= 0))
            {
                ConnectionPort = 5432;
            }
            else if ((value.Type == DatabaseType.MySql || value.Type == DatabaseType.MariaDB) && (ConnectionPort == 5432 || ConnectionPort <= 0))
            {
                ConnectionPort = 3306;
            }

            if (_originalModel == null && (string.IsNullOrWhiteSpace(ConnectionName) || ConnectionName.StartsWith("Localhost ")))
            {
                ConnectionName = $"Localhost {value.DisplayName}";
            }

            OnPropertyChanged(nameof(IsAllowSubmit));
        }

        partial void OnConnectionNameChanged(string value) => OnPropertyChanged(nameof(IsAllowSubmit));
        partial void OnConnectionHostChanged(string value) => OnPropertyChanged(nameof(IsAllowSubmit));
        partial void OnConnectionPortChanged(int value) => OnPropertyChanged(nameof(IsAllowSubmit));
        partial void OnConnectionUserChanged(string value) => OnPropertyChanged(nameof(IsAllowSubmit));

        /// <summary>
        /// Asynchronously tests connectivity to the target database server using provided credentials.
        /// </summary>
        [RelayCommand]
        public async Task TestConnectionAsync()
        {
            if (IsTesting) return;

            IsTesting = true;
            IsTestSuccess = false;
            IsTestError = false;
            TestStatusMessage = LanguageBase.GetLangValue("status_testing");

            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));

            try
            {
                if (SelectedDatabaseType?.Type == DatabaseType.PostgreSql)
                {
                    // Check socket reachability for PostgreSQL
                    using var tcpClient = new System.Net.Sockets.TcpClient();
                    var connectTask = tcpClient.ConnectAsync(ConnectionHost.Trim(), ConnectionPort);
                    var timeoutTask = Task.Delay(TimeSpan.FromSeconds(5), cts.Token);
                    var completed = await Task.WhenAny(connectTask, timeoutTask).ConfigureAwait(true);

                    if (completed == connectTask && tcpClient.Connected)
                    {
                        IsTestSuccess = true;
                        IsTestError = false;
                        TestStatusMessage = LanguageBase.GetLangValue("msg_test_pg_socket", ConnectionPort.ToString());
                    }
                    else
                    {
                        IsTestSuccess = false;
                        IsTestError = true;
                        TestStatusMessage = LanguageBase.GetLangValue("msg_test_connection_failed", "PostgreSQL host or port unreachable");
                    }
                    return;
                }

                // MySQL and MariaDB wire-protocol connection verification
                var testModel = ToConnectionModel();
                var conn = new MySqlDatabaseConnection(testModel);

                bool success = await Task.Run(async () =>
                {
                    try
                    {
                        bool connected = await conn.ConnectAsync();
                        if (connected)
                        {
                            await conn.DisconnectAsync();
                            return true;
                        }
                        return false;
                    }
                    catch
                    {
                        return false;
                    }
                }, cts.Token).ConfigureAwait(true);

                if (success)
                {
                    IsTestSuccess = true;
                    IsTestError = false;
                    TestStatusMessage = LanguageBase.GetLangValue("msg_test_connection_success");
                }
                else
                {
                    IsTestSuccess = false;
                    IsTestError = true;
                    TestStatusMessage = LanguageBase.GetLangValue("msg_test_connection_failed", "Server rejected credentials or is offline");
                }
            }
            catch (OperationCanceledException)
            {
                IsTestSuccess = false;
                IsTestError = true;
                TestStatusMessage = LanguageBase.GetLangValue("msg_test_connection_failed", "Connection timed out after 5 seconds");
            }
            catch (Exception ex)
            {
                IsTestSuccess = false;
                IsTestError = true;
                TestStatusMessage = LanguageBase.GetLangValue("msg_test_connection_failed", ex.Message);
            }
            finally
            {
                IsTesting = false;
            }
        }

        /// <summary>
        /// Converts the current input parameters into a populated <see cref="ConnectionModel"/> instance.
        /// </summary>
        /// <returns>A new or updated ConnectionModel.</returns>
        public ConnectionModel ToConnectionModel()
        {
            var model = _originalModel ?? new ConnectionModel();
            model.Name = ConnectionName.Trim();
            model.Host = ConnectionHost.Trim();
            model.Port = ConnectionPort;
            model.User = ConnectionUser.Trim();
            model.Password = ConnectionPassword;
            model.Database = string.IsNullOrWhiteSpace(ConnectionDatabase) ? null : ConnectionDatabase.Trim();
            model.Type = new DatabaseTypes { Value = SelectedDatabaseType?.Type ?? DatabaseType.MySql };
            return model;
        }
    }
}
