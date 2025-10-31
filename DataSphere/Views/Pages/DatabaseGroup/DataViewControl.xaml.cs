using DataSphere.Models.Database;
using DataSphere.Services.Database.Interface;
using DataSphere.ViewModels.Pages.DatabaseGroup;

namespace DataSphere.Views.Pages.DatabaseGroup
{
    /// <summary>
    /// Interaction logic for DataViewControl.xaml
    /// </summary>
    public partial class DataViewControl : UserControl, IDisposable
    {
        public DataControlViewModel ViewModel { get; }

        public DataViewControl(IDatabaseConnection connection, DatabaseInfo database, Table table)
        {
            ViewModel = new DataControlViewModel(connection, database, table);
            this.DataContext = this;
            InitializeComponent();
        }

        public void Dispose()
        {
            ViewModel.Dispose();
            dataView.ItemsSource = null;
            BindingOperations.ClearAllBindings(dataView);
            dataView.Columns.Clear();
            dataView.SelectedItem = null;

            GC.Collect();
            GC.WaitForPendingFinalizers();
        }
    }
}
