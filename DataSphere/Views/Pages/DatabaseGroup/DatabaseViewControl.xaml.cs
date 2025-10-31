using DataSphere.Models.Database;
using DataSphere.ViewModels.Pages.DatabaseGroup;
using System.Windows.Controls;

namespace DataSphere.Views.Pages.DatabaseGroup
{
    /// <summary>
    /// Interaction logic for DatabaseViewControl.xaml
    /// </summary>
    public partial class DatabaseViewControl : UserControl, IDisposable
    {
        private bool _disposed = false;

        public ConnectionModel ConnectionModel { get; set; }

        public DatabaseControlViewModel ViewModel { get; }

        public DatabaseViewControl(ConnectionModel connectionModel)
        {
            ConnectionModel = connectionModel;
            ViewModel = new DatabaseControlViewModel(ConnectionModel);
            DataContext = this;

            InitializeComponent();
        }

        private async void TreeViewItem_Expanded(object sender, RoutedEventArgs e)
        {
            if (_disposed) return;

            if (sender is System.Windows.Controls.TreeViewItem item &&
                item.DataContext is DatabaseCategory category)
            {
                if (category.Parent is DatabaseInfo parent)
                {
                    e.Handled = true;
                    await ViewModel.LoadTablesAsync(parent);
                }
            }
        }

        public void Dispose()
        {
            if (_disposed) return;

            _disposed = true;

            treeView.ItemsSource = null;

            // Unsubscribe event handlers
            // (nếu có subscribe events nào khác)

            // Dispose ViewModel
            ViewModel?.Dispose();

            // Clear DataContext
            DataContext = null;

            // Clear connection model reference
            ConnectionModel = null!;

            // Force garbage collection (optional, chỉ dùng khi thực sự cần)
            GC.Collect();
            GC.WaitForPendingFinalizers();
            GC.Collect();

            GC.SuppressFinalize(this);
        }

        ~DatabaseViewControl()
        {
            Dispose();
        }
    }
}
