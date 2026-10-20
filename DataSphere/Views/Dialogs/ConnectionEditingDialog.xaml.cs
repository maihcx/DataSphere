using Microsoft.UI.Xaml.Controls;
using DataSphere.Models;
using DataSphere.ViewModels.Dialogs;

namespace DataSphere.Views.Dialogs
{
    /// <summary>
    /// Native WinUI 3 ContentDialog for configuring database connection parameters and testing server reachability.
    /// </summary>
    public sealed partial class ConnectionEditingDialog : ContentDialog
    {
        /// <summary>
        /// Gets the ViewModel driving the connection editing dialog state.
        /// </summary>
        public ConnectionEditingViewModel ViewModel { get; }

        /// <summary>
        /// Gets the resulting configured <see cref="ConnectionModel"/> when the dialog is saved.
        /// </summary>
        public ConnectionModel ResultConnection => ViewModel.ToConnectionModel();

        /// <summary>
        /// Initializes a new instance of the <see cref="ConnectionEditingDialog"/> class.
        /// </summary>
        /// <param name="existingConnection">Optional existing connection to edit.</param>
        public ConnectionEditingDialog(ConnectionModel? existingConnection = null)
        {
            ViewModel = new ConnectionEditingViewModel(existingConnection);
            InitializeComponent();
        }

        private void PasswordBox_PasswordChanged(object sender, Microsoft.UI.Xaml.RoutedEventArgs e)
        {
            if (sender is PasswordBox pb)
            {
                ViewModel.ConnectionPassword = pb.Password;
            }
        }
    }
}
