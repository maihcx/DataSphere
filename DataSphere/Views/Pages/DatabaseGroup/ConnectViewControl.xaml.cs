using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using DataSphere.Models;
using DataSphere.Services.Contracts;
using DataSphere.Utils;
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

        private void ConnectionsTree_ItemInvoked(TreeView sender, TreeViewItemInvokedEventArgs args)
        {
            if (args.InvokedItem is ConnectionModel conn && conn.Type?.Value == DatabaseType.MySql)
            {
                ViewModel.OnOpenConnection?.Invoke(conn);
            }
        }

        private void TreeViewItem_DoubleTapped(object sender, DoubleTappedRoutedEventArgs e)
        {
            if (sender is FrameworkElement fe && fe.DataContext is ConnectionModel conn)
            {
                if (conn.Type?.Value == DatabaseType.MySql)
                {
                    ViewModel.OnOpenConnection?.Invoke(conn);
                    e.Handled = true;
                }
            }
        }

        private void TreeViewItem_ContextRequested(UIElement sender, ContextRequestedEventArgs args)
        {
            if (sender is FrameworkElement fe && fe.DataContext is ConnectionModel conn)
            {
                var flyout = new MenuFlyout();

                if (conn.Type?.Value == DatabaseType.MySql)
                {
                    // Connect action
                    var connectItem = new MenuFlyoutItem
                    {
                        Text = LanguageBase.GetLangValue("ctx_opencnn_title"),
                        Icon = new FontIcon { Glyph = "\uE774" }
                    };
                    connectItem.Click += (s, e) => ViewModel.OnOpenConnection?.Invoke(conn);
                    flyout.Items.Add(connectItem);

                    flyout.Items.Add(new MenuFlyoutSeparator());

                    // Edit action
                    var editItem = new MenuFlyoutItem
                    {
                        Text = LanguageBase.GetLangValue("ctx_edit_title"),
                        Icon = new FontIcon { Glyph = "\uE70F" }
                    };
                    editItem.Click += async (s, e) =>
                    {
                        var dialogService = App.GetRequiredService<IDialogService>();
                        var updated = await dialogService.ShowConnectionEditingDialogAsync(conn, this.XamlRoot);
                        if (updated != null)
                        {
                            conn.Name = updated.Name;
                            conn.Host = updated.Host;
                            conn.Port = updated.Port;
                            conn.User = updated.User;
                            conn.Password = updated.Password;
                            await Services.ConnectionStorageService.SaveAsync(ViewModel.ConnectItems);
                        }
                    };
                    flyout.Items.Add(editItem);
                }
                else if (conn.Type?.Value == DatabaseType.Folder)
                {
                    // New connection inside folder
                    var addConnItem = new MenuFlyoutItem
                    {
                        Text = LanguageBase.GetLangValue("ctx_mysql_title"),
                        Icon = new FontIcon { Glyph = "\uE774" }
                    };
                    addConnItem.Click += async (s, e) =>
                    {
                        var dialogService = App.GetRequiredService<IDialogService>();
                        var newConn = await dialogService.ShowConnectionEditingDialogAsync(null, this.XamlRoot);
                        if (newConn != null)
                        {
                            newConn.Parent = conn;
                            conn.Children.Add(newConn);
                            await Services.ConnectionStorageService.SaveAsync(ViewModel.ConnectItems);
                        }
                    };
                    flyout.Items.Add(addConnItem);

                    flyout.Items.Add(new MenuFlyoutSeparator());
                }

                // Rename action
                var renameItem = new MenuFlyoutItem
                {
                    Text = LanguageBase.GetLangValue("ctx_rename_title"),
                    Icon = new FontIcon { Glyph = "\uE8AC" }
                };
                renameItem.Click += (s, e) => conn.IsEditing = true;
                flyout.Items.Add(renameItem);

                // Delete action
                var deleteItem = new MenuFlyoutItem
                {
                    Text = LanguageBase.GetLangValue("ctx_delete_title"),
                    Icon = new FontIcon { Glyph = "\uE74D" }
                };
                deleteItem.Click += async (s, e) =>
                {
                    var dialogService = App.GetRequiredService<IDialogService>();
                    bool confirmed = await dialogService.ShowConfirmationDialogAsync(
                        "dialog_delete_connection_title",
                        "dialog_delete_connection_message",
                        new object[] { conn.Name },
                        this.XamlRoot);

                    if (confirmed)
                    {
                        if (conn.Parent != null)
                        {
                            conn.Parent.Children.Remove(conn);
                        }
                        else
                        {
                            ViewModel.ConnectItems.Remove(conn);
                        }
                        await Services.ConnectionStorageService.SaveAsync(ViewModel.ConnectItems);
                    }
                };
                flyout.Items.Add(deleteItem);

                if (args.TryGetPosition(fe, out var point))
                {
                    flyout.ShowAt(fe, point);
                }
                else
                {
                    flyout.ShowAt(fe);
                }

                args.Handled = true;
            }
        }

        private void RenameTextBox_KeyDown(object sender, KeyRoutedEventArgs e)
        {
            if (sender is TextBox tb && tb.DataContext is ConnectionModel conn)
            {
                if (e.Key == global::Windows.System.VirtualKey.Enter)
                {
                    conn.IsEditing = false;
                    _ = Services.ConnectionStorageService.SaveAsync(ViewModel.ConnectItems);
                    e.Handled = true;
                }
                else if (e.Key == global::Windows.System.VirtualKey.Escape)
                {
                    conn.IsEditing = false;
                    e.Handled = true;
                }
            }
        }

        private void RenameTextBox_LostFocus(object sender, RoutedEventArgs e)
        {
            if (sender is TextBox tb && tb.DataContext is ConnectionModel conn)
            {
                conn.IsEditing = false;
                _ = Services.ConnectionStorageService.SaveAsync(ViewModel.ConnectItems);
            }
        }
    }
}
