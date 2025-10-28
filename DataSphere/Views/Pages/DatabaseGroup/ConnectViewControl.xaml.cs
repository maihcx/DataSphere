using CommunityToolkit.Mvvm.Messaging;
using CommunityToolkit.Mvvm.Messaging.Messages;
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

        private void ConnectTreeView_MouseDoubleClick(object sender, MouseButtonEventArgs e)
        {
            if (ConnectTreeView.SelectedItem is ConnectionModel selected)
            {
                if (selected.Type?.Value != DatabaseType.Folder)
                {
                    WeakReferenceMessenger.Default.Send(new GenericMessage<(ConnectionModel, string)>((selected, "add")));
                }
            }
        }

        private void ConnectTreeView_KeyDown(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.F2)
            {
                if (ConnectTreeView.SelectedItem is ConnectionModel selected)
                {
                    selected.IsEditing = true;
                }
                e.Handled = false;
            }
        }
    }
}
