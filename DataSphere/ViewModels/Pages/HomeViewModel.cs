using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using DataSphere.Services.Contracts;
using DataSphere.Utils;
using DataSphere.Views.Pages.DatabaseGroup;
using DataSphere.Views.PagesBottom;

namespace DataSphere.ViewModels.Pages
{
    /// <summary>
    /// ViewModel for the Home Dashboard, exposing application metadata and actions to open sub-pages in new tabs.
    /// </summary>
    public partial class HomeViewModel : ObservableObject
    {
        private readonly ITabService _tabService;

        /// <summary>
        /// Gets the application display name.
        /// </summary>
        [ObservableProperty]
        public partial string AppName { get; set; } = AppInfoHelper.AppName;

        /// <summary>
        /// Gets the application author name.
        /// </summary>
        [ObservableProperty]
        public partial string Author { get; set; } = AppInfoHelper.Author;

        /// <summary>
        /// Gets the author short name or title.
        /// </summary>
        [ObservableProperty]
        public partial string SortAuthor { get; set; } = AppInfoHelper.SortAuthor;

        /// <summary>
        /// Gets the creation / copyright text.
        /// </summary>
        [ObservableProperty]
        public partial string AuthorCreated { get; set; } = AppInfoHelper.AuthorCreated;

        /// <summary>
        /// Gets the high-level application description.
        /// </summary>
        [ObservableProperty]
        public partial string AppDescription { get; set; } = AppInfoHelper.AppDescription;

        /// <summary>
        /// Initializes a new instance of the <see cref="HomeViewModel"/> class.
        /// </summary>
        /// <param name="tabService">The tab service associated with the host window.</param>
        public HomeViewModel(ITabService tabService)
        {
            _tabService = tabService ?? throw new ArgumentNullException(nameof(tabService));
        }

        /// <summary>
        /// Opens or focuses the Database tab in the current window's tab strip using the dynamic resource key.
        /// </summary>
        [RelayCommand]
        public void OpenDatabase()
        {
            _tabService.OpenTab(typeof(DatabasePage), "page_db_title", "\uE774");
        }

        /// <summary>
        /// Opens or focuses the Settings tab in the current window's tab strip using the dynamic resource key.
        /// </summary>
        [RelayCommand]
        public void OpenSettings()
        {
            _tabService.OpenTab(typeof(SettingsPage), "page_settings_title", "\uE713");
        }
    }
}
