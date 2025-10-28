using DataSphere.Models.Database;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DataSphere.ViewModels.Pages.DatabaseGroup
{
    public partial class DCViewModel : ObservableObject
    {
        private bool _isInitialized = false;

        private ConnectionModel ConnectionModel { get; set; }

        public DCViewModel(ConnectionModel connectionModel)
        {
            ConnectionModel = connectionModel;

            if (!_isInitialized)
            {
                InitializeViewModel();
            }
        }

        private async void InitializeViewModel()
        {
            var connect = Services.Database.DatabaseConnectionFactory.Create(ConnectionModel);
            if (connect != null)
            {
                await connect.ConnectAsync();
                AllDatabases = await connect.GetAllDatabasesAsync();
                Console.WriteLine(AllDatabases);
            }
        }

        [ObservableProperty]
        private ObservableCollection<DatabaseInfo>? _allDatabases;
    }
}
