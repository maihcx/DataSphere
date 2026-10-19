using Microsoft.UI.Xaml.Controls;
using DataSphere.ViewModels.PagesBottom;

namespace DataSphere.Views.PagesBottom
{
    /// <summary>
    /// Settings page allowing users to customize themes, display language, and view application metadata.
    /// </summary>
    public sealed partial class SettingsPage : Page
    {
        /// <summary>
        /// Gets the ViewModel associated with this settings page.
        /// </summary>
        public SettingsViewModel ViewModel { get; }

        /// <summary>
        /// Initializes a new instance of the <see cref="SettingsPage"/> class.
        /// </summary>
        public SettingsPage()
        {
            ViewModel = App.GetRequiredService<SettingsViewModel>();
            InitializeComponent();
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="SettingsPage"/> class with an injected ViewModel.
        /// </summary>
        /// <param name="viewModel">The settings page ViewModel.</param>
        public SettingsPage(SettingsViewModel viewModel)
        {
            ViewModel = viewModel ?? throw new ArgumentNullException(nameof(viewModel));
            InitializeComponent();
        }
    }
}
