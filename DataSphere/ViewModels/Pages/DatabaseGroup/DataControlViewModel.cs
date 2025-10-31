using DataSphere.Models.Database;
using DataSphere.Services.Database.Interface;
using System.Data;

namespace DataSphere.ViewModels.Pages.DatabaseGroup
{
    public partial class DataControlViewModel : ObservableObject, IDisposable
    {
        private bool _disposed = false;

        private bool _isInitialized = false;

        private IDatabaseConnection Connection { get; }

        private DatabaseInfo Database {  get; }

        private Table Table { get; }

        [ObservableProperty]
        private DataView? _tableView = null;

        public DataControlViewModel(IDatabaseConnection connection, DatabaseInfo database, Table table)
        {
            Connection = connection;
            Database = database;
            Table = table;

            if (!_isInitialized)
            {
                InitializeViewModel();
            }
        }

        private async void InitializeViewModel()
        {
            if (Table == null) return;

            var query = $"SELECT * FROM {Database.Name}.{Table.Name}";

            using (DataTable? table = await Connection.ExecuteQueryAsync(query))
            {
                TableView = table?.DefaultView;
            }

            _isInitialized = true;
        }

        public void Dispose()
        {
            if (_disposed) return;

            _disposed = true;

            TableView?.Table?.Clear();
            TableView?.Table?.Dispose() ;
            TableView?.Dispose();
            TableView = null;

            GC.Collect();
            GC.SuppressFinalize(this);
        }

        ~DataControlViewModel()
        {
            Dispose();
        }
    }
}
