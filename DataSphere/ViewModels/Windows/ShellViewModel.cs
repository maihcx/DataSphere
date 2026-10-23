using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using DataSphere.Models;
using DataSphere.Services.Contracts;
using DataSphere.Views.Pages;

namespace DataSphere.ViewModels.Windows
{
    /// <summary>
    /// ViewModel for the main window shell, coordinating the anchored Home tab in TabStripHeader, dynamic workspace tabs, and unified viewport content.
    /// </summary>
    public partial class ShellViewModel : ObservableObject
    {
        private readonly ITabService _tabService;
        private readonly IWindowManager _windowManager;
        private readonly IServiceProvider _serviceProvider;

        /// <summary>
        /// Occurs when closing the sole remaining tab requests closing the window and application session.
        /// </summary>
        public event EventHandler? RequestCloseWindow;

        /// <summary>
        /// Gets the tab service managing dynamic tab collections and selection for this window.
        /// </summary>
        public ITabService TabService => _tabService;

        /// <summary>
        /// Gets the dedicated TabItemModel representing the permanently anchored Home tab.
        /// </summary>
        public TabItemModel HomeTab { get; }

        /// <summary>
        /// Gets or sets a value indicating whether the Home tab is currently selected and active.
        /// </summary>
        [ObservableProperty]
        [NotifyPropertyChangedFor(nameof(EffectiveTabIndex))]
        [NotifyPropertyChangedFor(nameof(ActiveViewportContent))]
        public partial bool IsHomeSelected { get; set; } = true;

        /// <summary>
        /// Gets the zero-based effective index of the currently active tab (0 for Home tab, 1+ for dynamic workspace tabs).
        /// Used by the viewport host to calculate directional horizontal transition animations.
        /// </summary>
        public int EffectiveTabIndex => IsHomeSelected ? 0 : (_tabService.SelectedTab != null ? _tabService.Tabs.IndexOf(_tabService.SelectedTab) + 1 : 0);

        /// <summary>
        /// Gets the observable collection of dynamic workspace tabs hosted in this window shell.
        /// </summary>
        public ObservableCollection<TabItemModel> Tabs => _tabService.Tabs;

        /// <summary>
        /// Gets or sets the currently selected dynamic tab. Null when the Home tab is active.
        /// </summary>
        public TabItemModel? SelectedTab
        {
            get => _tabService.SelectedTab;
            set
            {
                if (!Equals(_tabService.SelectedTab, value))
                {
                    _tabService.SelectedTab = value;
                    if (value != null)
                    {
                        IsHomeSelected = false;
                    }
                    OnPropertyChanged();
                    OnPropertyChanged(nameof(EffectiveTabIndex));
                    OnPropertyChanged(nameof(ActiveViewportContent));
                }
            }
        }

        /// <summary>
        /// Gets the active content to display in the main viewport, dynamically resolving between Home and the selected dynamic tab.
        /// </summary>
        public object? ActiveViewportContent => IsHomeSelected ? HomeTab.Content : SelectedTab?.Content;

        /// <summary>
        /// Initializes a new instance of the <see cref="ShellViewModel"/> class.
        /// </summary>
        /// <param name="tabService">The tab service instance for this window.</param>
        /// <param name="windowManager">The application window manager.</param>
        /// <param name="serviceProvider">The application service provider.</param>
        public ShellViewModel(
            ITabService tabService,
            IWindowManager windowManager,
            IServiceProvider serviceProvider,
            ITabMemorySaverService tabMemorySaverService)
        {
            _tabService = tabService ?? throw new ArgumentNullException(nameof(tabService));
            _windowManager = windowManager ?? throw new ArgumentNullException(nameof(windowManager));
            _serviceProvider = serviceProvider ?? throw new ArgumentNullException(nameof(serviceProvider));

            if (tabMemorySaverService.IsEnabled)
            {
                Debug.WriteLine("Tab Memory Optimization is Stated");
            }

            HomeTab = CreateHomeTab();

            // Synchronize selection changes originating from TabService
            _tabService.PropertyChanged += (sender, e) =>
            {
                if (e.PropertyName == nameof(ITabService.SelectedTab))
                {
                    if (_tabService.SelectedTab != null)
                    {
                        IsHomeSelected = false;
                    }
                    OnPropertyChanged(nameof(SelectedTab));
                    OnPropertyChanged(nameof(EffectiveTabIndex));
                    OnPropertyChanged(nameof(ActiveViewportContent));
                }
            };

            // Dynamically manage close button visibility and fallback selection on collection change
            _tabService.Tabs.CollectionChanged += (sender, e) =>
            {
                UpdateHomeState();
            };

            UpdateHomeState();
        }

        /// <summary>
        /// Instantiates and configures the singleton Home tab model.
        /// </summary>
        /// <returns>A configured <see cref="TabItemModel"/> instance for the Home tab.</returns>
        private TabItemModel CreateHomeTab()
        {
            var homeVm = new DataSphere.ViewModels.Pages.HomeViewModel(_tabService);
            object? homePageInstance = null;
            try
            {
                homePageInstance = new HomePage(homeVm);
            }
            catch
            {
                // Fallback for headless environments or unit testing where WinUI Xaml core is not active
                homePageInstance = homeVm;
            }

            return new TabItemModel
            {
                TitleKey = "page_home_title",
                Title = DataSphere.Utils.LanguageBase.GetLangValue("page_home_title"),
                IconGlyph = "\uE80F",
                PageType = typeof(HomePage),
                Content = homePageInstance,
                IsClosable = true,
                IsSelected = true,
                State = TabLifecycleState.Active
            };
        }

        /// <summary>
        /// Updates the closability state of the Home tab and handles fallback selection when all dynamic tabs are closed.
        /// </summary>
        private void UpdateHomeState()
        {
            // When 1 or more dynamic tabs are open (total tabs >= 2), Home's close button is hidden (IsClosable = false).
            // Only when dynamic tabs count is 0 (Home is the sole tab remaining), Home's close button is shown (IsClosable = true).
            HomeTab.IsClosable = _tabService.Tabs.Count == 0;

            if (_tabService.Tabs.Count == 0)
            {
                IsHomeSelected = true;
                _tabService.SelectedTab = null;
            }

            OnPropertyChanged(nameof(EffectiveTabIndex));
            OnPropertyChanged(nameof(ActiveViewportContent));
        }

        /// <summary>
        /// Selects the Home tab, switching the active viewport and clearing dynamic tab selection.
        /// </summary>
        [RelayCommand]
        public void SelectHome()
        {
            IsHomeSelected = true;
            SelectedTab = null;
            OnPropertyChanged(nameof(EffectiveTabIndex));
            OnPropertyChanged(nameof(ActiveViewportContent));
        }

        /// <summary>
        /// Closes the Home tab. Only permitted when no dynamic tabs are open; triggers application session shutdown.
        /// </summary>
        [RelayCommand]
        public void CloseHome()
        {
            if (HomeTab.IsClosable && _tabService.Tabs.Count == 0)
            {
                RequestCloseWindow?.Invoke(this, EventArgs.Empty);
            }
        }

        /// <summary>
        /// Closes the specified dynamic tab, falling back to Home if it was the last dynamic tab.
        /// </summary>
        /// <param name="tab">The tab to close.</param>
        [RelayCommand]
        public void CloseTab(TabItemModel? tab)
        {
            if (tab != null && tab.IsClosable)
            {
                _tabService.CloseTab(tab);
                if (_tabService.Tabs.Count == 0)
                {
                    SelectHome();
                }
                OnPropertyChanged(nameof(SelectedTab));
                OnPropertyChanged(nameof(EffectiveTabIndex));
                OnPropertyChanged(nameof(ActiveViewportContent));
            }
        }

        /// <summary>
        /// Selects the tab at the specified index within dynamic tabs.
        /// </summary>
        /// <param name="index">The zero-based index to select.</param>
        [RelayCommand]
        public void SelectTab(int index)
        {
            _tabService.SelectTab(index);
            if (index >= 0 && index < _tabService.Tabs.Count)
            {
                IsHomeSelected = false;
            }
            OnPropertyChanged(nameof(SelectedTab));
            OnPropertyChanged(nameof(EffectiveTabIndex));
            OnPropertyChanged(nameof(ActiveViewportContent));
        }
    }
}
