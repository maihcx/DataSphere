using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using DataSphere.Models;
using DataSphere.ViewModels.Pages.DatabaseGroup;

namespace DataSphere.Views.Pages.DatabaseGroup
{
    /// <summary>
    /// Database management page hosting the multi-connection inner TabView workspace.
    /// Anchors the permanent Connection catalog explorer in TabStripHeader and hosts open database sessions as dynamic tabs.
    /// </summary>
    public sealed partial class DatabasePage : Page
    {
        /// <summary>
        /// Gets the ViewModel driving the database workspace.
        /// </summary>
        public DatabaseViewModel ViewModel { get; }

        /// <summary>
        /// Initializes a new instance of the <see cref="DatabasePage"/> class.
        /// </summary>
        /// <param name="viewModel">The viewmodel driving this page.</param>
        public DatabasePage(DatabaseViewModel viewModel)
        {
            ViewModel = viewModel ?? throw new ArgumentNullException(nameof(viewModel));
            InitializeComponent();

            // Synchronize selection: deselect dynamic tabs when Connection tab is selected
            ViewModel.PropertyChanged += (s, e) =>
            {
                if (e.PropertyName == nameof(DatabaseViewModel.IsConnectionSelected) && ViewModel.IsConnectionSelected)
                {
                    InnerTabView.SelectedItem = null;
                }
            };
        }

        /// <summary>
        /// Handles the Tapped event on the anchored Connection TabViewItem to select the Connection catalog.
        /// </summary>
        /// <param name="sender">The source of the tapped event.</param>
        /// <param name="e">The event data.</param>
        private void OnConnectionTabTapped(object sender, TappedRoutedEventArgs e)
        {
            ViewModel.SelectConnectionCommand.Execute(null);
            InnerTabView.SelectedItem = null;
        }

        /// <summary>
        /// Handles the TabCloseRequested event when a user requests closing a dynamic database session tab.
        /// </summary>
        /// <param name="sender">The TabView raising the close request.</param>
        /// <param name="args">The event arguments specifying which tab is to be closed.</param>
        private void InnerTabView_TabCloseRequested(TabView sender, TabViewTabCloseRequestedEventArgs args)
        {
            if (args.Item is InnerTabItemModel tab)
            {
                ViewModel.CloseTab(tab);
            }
        }

        /// <summary>
        /// Handles the SelectionChanged event on the inner TabView to synchronize dynamic tab selection to the ViewModel.
        /// </summary>
        /// <param name="sender">The source of the selection change event.</param>
        /// <param name="e">The selection change event arguments.</param>
        private void InnerTabView_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (InnerTabView.SelectedItem is InnerTabItemModel selected && !Equals(ViewModel.SelectedInnerTab, selected))
            {
                ViewModel.SelectedInnerTab = selected;
            }
        }
    }
}
