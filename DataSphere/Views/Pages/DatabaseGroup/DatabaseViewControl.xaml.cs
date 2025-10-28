using DataSphere.Models.Database;
using DataSphere.ViewModels.Pages.DatabaseGroup;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;

namespace DataSphere.Views.Pages.DatabaseGroup
{
    /// <summary>
    /// Interaction logic for DatabaseViewControl.xaml
    /// </summary>
    public partial class DatabaseViewControl : UserControl
    {
        public ConnectionModel ConnectionModel { get; set; }

        public DCViewModel ViewModel { get; }

        public DatabaseViewControl(ConnectionModel connectionModel)
        {
            ConnectionModel = connectionModel;
            ViewModel = new DCViewModel(ConnectionModel);
            DataContext = this;

            InitializeComponent();
        }

        private async void TreeViewItem_Expanded(object sender, RoutedEventArgs e)
        {
            if (e.OriginalSource is System.Windows.Controls.TreeViewItem item &&
                item.DataContext is DatabaseInfo db)
            {
                await ViewModel.LoadTablesAsync(db);
            }
        }
    }
}
