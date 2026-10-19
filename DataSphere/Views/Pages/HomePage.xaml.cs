using Microsoft.UI.Xaml.Controls;
using DataSphere.ViewModels.Pages;

namespace DataSphere.Views.Pages
{
    /// <summary>
    /// Home dashboard page presenting overview metadata and quick actions to open sub-modules in new tabs.
    /// </summary>
    public sealed partial class HomePage : Page
    {
        /// <summary>
        /// Gets the ViewModel associated with the home page.
        /// </summary>
        public HomeViewModel ViewModel { get; }

        /// <summary>
        /// Initializes a new instance of the <see cref="HomePage"/> class.
        /// </summary>
        public HomePage()
        {
            ViewModel = App.GetRequiredService<HomeViewModel>();
            InitializeComponent();
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="HomePage"/> class with an injected ViewModel.
        /// </summary>
        /// <param name="viewModel">The home page ViewModel.</param>
        public HomePage(HomeViewModel viewModel)
        {
            ViewModel = viewModel ?? throw new ArgumentNullException(nameof(viewModel));
            InitializeComponent();
        }
    }
}
