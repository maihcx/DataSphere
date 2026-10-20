using Microsoft.UI.Xaml.Controls;
using DataSphere.Models;
using DataSphere.ViewModels.Pages.DatabaseGroup;

namespace DataSphere.Views.Pages.DatabaseGroup
{
    /// <summary>
    /// Database management page hosting the multi-connection inner TabView workspace.
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
        }

        private void InnerTabView_TabCloseRequested(TabView sender, TabViewTabCloseRequestedEventArgs args)
        {
            if (args.Item is InnerTabItemModel tab)
            {
                ViewModel.CloseTab(tab);
            }
        }

        private void InnerTabView_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (InnerTabView.SelectedItem is InnerTabItemModel selected && !Equals(ViewModel.SelectedInnerTab, selected))
            {
                ViewModel.SelectedInnerTab = selected;
            }
        }
    }
}
