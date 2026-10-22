using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using DataSphere.Models;
using DataSphere.ViewModels.Pages.DatabaseGroup;

namespace DataSphere.Views.Pages.DatabaseGroup
{
    /// <summary>
    /// UserControl presenting the connection explorer tree and empty state action view.
    /// </summary>
    public sealed partial class ConnectViewControl : UserControl
    {
        /// <summary>
        /// Gets the ViewModel driving the connection tree.
        /// </summary>
        public ConnectControlViewModel ViewModel { get; }

        /// <summary>
        /// Initializes a new instance of the <see cref="ConnectViewControl"/> class.
        /// </summary>
        /// <param name="viewModel">The viewmodel driving this control.</param>
        public ConnectViewControl(ConnectControlViewModel viewModel)
        {
            ViewModel = viewModel ?? throw new ArgumentNullException(nameof(viewModel));
            InitializeComponent();
        }

        /// <summary>
        /// Handles keyboard navigation on the connection tree, opening the selected connection when Enter is pressed.
        /// </summary>
        /// <param name="sender">The TreeView emitting the event.</param>
        /// <param name="e">The key event arguments.</param>
        private void ConnectionsTree_KeyDown(object sender, KeyRoutedEventArgs e)
        {
            if (e.Key == global::Windows.System.VirtualKey.Enter)
            {
                if (ConnectionsTree.SelectedItem is ConnectionModel conn)
                {
                    ViewModel.OpenConnectionCommand.Execute(conn);
                    e.Handled = true;
                }
            }
        }

        /// <summary>
        /// Handles double-tapping a tree node by delegating to the ViewModel's open connection command.
        /// </summary>
        /// <param name="sender">The source element that was double-tapped.</param>
        /// <param name="e">The double-tapped routed event data.</param>
        private void TreeViewItem_DoubleTapped(object sender, DoubleTappedRoutedEventArgs e)
        {
            if (sender is FrameworkElement { DataContext: ConnectionModel conn })
            {
                ViewModel.OpenConnectionCommand.Execute(conn);
                e.Handled = true;
            }
        }

        /// <summary>
        /// Handles key presses while editing a connection name inline.
        /// </summary>
        /// <param name="sender">The source TextBox.</param>
        /// <param name="e">The key event arguments.</param>
        private void RenameTextBox_KeyDown(object sender, KeyRoutedEventArgs e)
        {
            if (sender is TextBox tb && tb.DataContext is ConnectionModel conn)
            {
                if (e.Key is global::Windows.System.VirtualKey.Enter or global::Windows.System.VirtualKey.Escape)
                {
                    conn.IsEditing = false;
                    e.Handled = true;
                }
            }
        }

        /// <summary>
        /// Commits inline renaming when the TextBox loses focus.
        /// </summary>
        /// <param name="sender">The source TextBox.</param>
        /// <param name="e">The routed event arguments.</param>
        private void RenameTextBox_LostFocus(object sender, RoutedEventArgs e)
        {
            if (sender is TextBox tb && tb.DataContext is ConnectionModel conn)
            {
                conn.IsEditing = false;
            }
        }
    }
}
