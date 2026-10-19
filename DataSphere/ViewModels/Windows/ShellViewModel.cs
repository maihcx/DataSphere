using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using DataSphere.Models;
using DataSphere.Services.Contracts;
using DataSphere.Views.Pages;

namespace DataSphere.ViewModels.Windows
{
    /// <summary>
    /// ViewModel for the main window shell, coordinating the browser-style tab strip and tab lifecycle.
    /// </summary>
    public partial class ShellViewModel : ObservableObject
    {
        private readonly ITabService _tabService;
        private readonly IWindowManager _windowManager;
        private readonly IServiceProvider _serviceProvider;

        /// <summary>
        /// Gets the tab service managing tab collections and selection for this window.
        /// </summary>
        public ITabService TabService => _tabService;

        /// <summary>
        /// Gets the observable collection of tabs hosted in this window shell.
        /// </summary>
        public ObservableCollection<TabItemModel> Tabs => _tabService.Tabs;

        /// <summary>
        /// Gets or sets the currently selected and active tab.
        /// </summary>
        public TabItemModel? SelectedTab
        {
            get => _tabService.SelectedTab;
            set
            {
                if (!Equals(_tabService.SelectedTab, value))
                {
                    _tabService.SelectedTab = value;
                    OnPropertyChanged();
                }
            }
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="ShellViewModel"/> class.
        /// </summary>
        /// <param name="tabService">The tab service instance for this window.</param>
        /// <param name="windowManager">The application window manager.</param>
        /// <param name="serviceProvider">The application service provider.</param>
        public ShellViewModel(
            ITabService tabService,
            IWindowManager windowManager,
            IServiceProvider serviceProvider)
        {
            _tabService = tabService ?? throw new ArgumentNullException(nameof(tabService));
            _windowManager = windowManager ?? throw new ArgumentNullException(nameof(windowManager));
            _serviceProvider = serviceProvider ?? throw new ArgumentNullException(nameof(serviceProvider));

            InitializeHomeTab();
        }

        /// <summary>
        /// Anchors the uncloseable Home tab at index 0 of the tab strip.
        /// </summary>
        private void InitializeHomeTab()
        {
            if (_tabService.Tabs.Count == 0)
            {
                var homeVm = new DataSphere.ViewModels.Pages.HomeViewModel(_tabService);
                var homePageInstance = new HomePage(homeVm);

                var homeTab = new TabItemModel
                {
                    TitleKey = "page_home_title",
                    Title = DataSphere.Utils.LanguageBase.GetLangValue("page_home_title"),
                    IconGlyph = "\uE80F",
                    PageType = typeof(HomePage),
                    Content = homePageInstance,
                    IsClosable = false,
                    IsSelected = true,
                    State = TabLifecycleState.Active
                };

                _tabService.Tabs.Add(homeTab);
                _tabService.SelectedTab = homeTab;
            }
        }

        /// <summary>
        /// Closes the specified tab, respecting the uncloseable Home tab invariant.
        /// </summary>
        /// <param name="tab">The tab to close.</param>
        [RelayCommand]
        public void CloseTab(TabItemModel? tab)
        {
            if (tab != null && tab.IsClosable)
            {
                _tabService.CloseTab(tab);
                OnPropertyChanged(nameof(SelectedTab));
            }
        }

        /// <summary>
        /// Selects the tab at the specified index.
        /// </summary>
        /// <param name="index">The zero-based index to select.</param>
        [RelayCommand]
        public void SelectTab(int index)
        {
            _tabService.SelectTab(index);
            OnPropertyChanged(nameof(SelectedTab));
        }
    }
}
