using Microsoft.UI.Xaml.Controls;
using DataSphere.ViewModels.Pages.DatabaseGroup;

namespace DataSphere.Views.Pages.DatabaseGroup
{
    /// <summary>
    /// Database management page coordinating connection explorer, schema views, and query execution.
    /// </summary>
    public sealed partial class DatabasePage : Page
    {
        /// <summary>
        /// Gets the ViewModel associated with this database page.
        /// </summary>
        public DatabaseViewModel ViewModel { get; }

        /// <summary>
        /// Initializes a new instance of the <see cref="DatabasePage"/> class.
        /// </summary>
        public DatabasePage()
        {
            ViewModel = App.GetRequiredService<DatabaseViewModel>();
            InitializeComponent();
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="DatabasePage"/> class with an injected ViewModel.
        /// </summary>
        /// <param name="viewModel">The database page ViewModel.</param>
        public DatabasePage(DatabaseViewModel viewModel)
        {
            ViewModel = viewModel ?? throw new ArgumentNullException(nameof(viewModel));
            InitializeComponent();
        }
    }
}
