using DataSphere.Models.Database;
using DataSphere.Services.Database;
using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DataSphere.ViewModels.Pages.DatabaseGroup
{
    public partial class DCViewModel : ObservableObject
    {
        private bool _isInitialized = false;

        private ConnectionModel ConnectionModel { get; set; }

        private IDatabaseConnection? connection { get; }

        public DCViewModel(ConnectionModel connectionModel)
        {
            ConnectionModel = connectionModel;
            connection = DatabaseConnectionFactory.Create(ConnectionModel);

            if (!_isInitialized)
            {
                InitializeViewModel();
            }
        }

        private async void InitializeViewModel()
        {
            if (connection != null)
            {
                await connection.ConnectAsync();
                AllDatabases = await connection.GetAllDatabasesAsync();
            }
        }

        public async Task LoadTablesAsync(DatabaseInfo db)
        {
            if (db == null || db.IsTablesLoaded || connection == null)
                return;

            var tables = await connection.GetAllTablesAsync(db.Name);

            db.Tables?.Clear();

            if (tables != null)
            {
                foreach (var t in tables)
                    db.Tables?.Add(t);
            }

            db.IsTablesLoaded = true;
        }

        [ObservableProperty]
        private ObservableCollection<DatabaseInfo>? _allDatabases;
    }
}
