using DataSphere.ViewModels.Pages.DatabaseGroup;

namespace DataSphere.Views.Pages.DatabaseGroup
{
    /// <summary>
    /// Interaction logic for ConnectViewControl.xaml
    /// </summary>
    public partial class ConnectViewControl : UserControl
    {
        public ConnectViewModel ViewModel { get; }

        public ConnectViewControl()
        {
            ViewModel = new ConnectViewModel();
            DataContext = this;

            InitializeComponent();
        }

        private void TextBlock_MouseDown(object sender, MouseButtonEventArgs e)
        {
            if (e.ClickCount == 2) // double-click để rename
            {
                if (sender is Wpf.Ui.Controls.TextBlock tb && tb.DataContext is ConnectionModel item)
                {
                    item.IsEditing = true;

                    // Delay nhỏ để đảm bảo TextBox render xong
                    Dispatcher.BeginInvoke(() =>
                    {
                        var container = (System.Windows.Controls.TreeViewItem)ConnectTreeView.ItemContainerGenerator.ContainerFromItem(item);
                        var textBox = FindVisualChild<Wpf.Ui.Controls.TextBox>(container);
                        textBox?.Focus();
                        textBox?.SelectAll();
                    });
                }
            }
        }

        private void TextBox_Loaded(object sender, RoutedEventArgs e)
        {
            if (sender is Wpf.Ui.Controls.TextBox tb && tb.DataContext is ConnectionModel model && model.IsEditing)
            {
                tb.Focus();
                tb.SelectAll();
            }
        }

        private void TextBox_LostFocus(object sender, RoutedEventArgs e)
        {
            if (sender is Wpf.Ui.Controls.TextBox tb && tb.DataContext is ConnectionModel item)
                item.IsEditing = false;
        }

        private void TextBox_KeyDown(object sender, KeyEventArgs e)
        {
            if (sender is Wpf.Ui.Controls.TextBox tb && tb.DataContext is ConnectionModel item)
            {
                if (e.Key == Key.Enter)
                {
                    item.IsEditing = false;
                    e.Handled = true;
                }
                else if (e.Key == Key.Escape)
                {
                    item.IsEditing = false;
                    e.Handled = true;
                }
            }
        }

        private static T? FindVisualChild<T>(DependencyObject parent) where T : DependencyObject
        {
            for (int i = 0; i < VisualTreeHelper.GetChildrenCount(parent); i++)
            {
                var child = VisualTreeHelper.GetChild(parent, i);
                if (child is T result)
                    return result;

                var descendent = FindVisualChild<T>(child);
                if (descendent != null)
                    return descendent;
            }
            return null;
        }
    }
}
