using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using DataSphere.Models;
using DataSphere.Services.Contracts;

namespace DataSphere.Services
{
    /// <summary>
    /// Service managing the collection, selection, and lifecycle of tabs within a window session.
    /// </summary>
    public partial class TabService : ObservableObject, ITabService
    {
        private readonly IServiceProvider _serviceProvider;

        /// <summary>
        /// Gets the observable collection of tabs active in the current window.
        /// </summary>
        public ObservableCollection<TabItemModel> Tabs { get; } = new();

        /// <summary>
        /// Gets or sets the currently selected and active tab.
        /// </summary>
        [ObservableProperty]
        public partial TabItemModel? SelectedTab { get; set; }

        /// <summary>
        /// Initializes a new instance of the <see cref="TabService"/> class.
        /// </summary>
        /// <param name="serviceProvider">The application service provider for resolving page views.</param>
        public TabService(IServiceProvider serviceProvider)
        {
            _serviceProvider = serviceProvider ?? throw new ArgumentNullException(nameof(serviceProvider));
        }

        /// <summary>
        /// Opens a new tab of the specified page type or switches to an existing tab, dynamically resolving title from a resource key.
        /// </summary>
        /// <param name="pageType">The concrete Type of the page to host.</param>
        /// <param name="titleKey">The localization resource key for the tab header.</param>
        /// <param name="iconGlyph">Fluent icon glyph for the tab.</param>
        /// <param name="parameter">Optional navigation parameter passed to the ViewModel.</param>
        /// <returns>The opened or focused TabItemModel instance.</returns>
        public TabItemModel OpenTab(Type pageType, string titleKey, string iconGlyph, object? parameter = null)
        {
            if (pageType == null)
            {
                throw new ArgumentNullException(nameof(pageType));
            }

            // Check if a tab of this type is already open (e.g. Home or Settings)
            var existingTab = Tabs.FirstOrDefault(t => t.PageType == pageType);
            if (existingTab != null && (existingTab.PageType?.Name == "HomePage" || !existingTab.IsClosable))
            {
                SelectedTab = existingTab;
                existingTab.State = TabLifecycleState.Active;
                return existingTab;
            }

            // If it's a singleton-style settings page, focus existing if found
            if (existingTab != null && (existingTab.TitleKey == titleKey || existingTab.Title == LanguageBase.GetLangValue(titleKey)))
            {
                SelectedTab = existingTab;
                existingTab.State = TabLifecycleState.Active;
                return existingTab;
            }

            // Resolve or instantiate page
            object? pageInstance = null;
            try
            {
                pageInstance = _serviceProvider.GetService(pageType) ?? Activator.CreateInstance(pageType);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[TabService] Warning: Failed to instantiate page {pageType.Name}: {ex.Message}");
                pageInstance = pageType.Name;
            }

            var newTab = new TabItemModel
            {
                TitleKey = titleKey,
                Title = LanguageBase.GetLangValue(titleKey),
                IconGlyph = iconGlyph,
                PageType = pageType,
                Content = pageInstance,
                IsClosable = true,
                State = TabLifecycleState.Active
            };

            Tabs.Add(newTab);
            SelectedTab = newTab;

            return newTab;
        }

        /// <summary>
        /// Requests closing of the specified tab.
        /// </summary>
        /// <param name="tab">The tab to close.</param>
        /// <returns><c>true</c> if the tab was closed successfully; otherwise <c>false</c> if closure was cancelled or forbidden.</returns>
        public bool CloseTab(TabItemModel tab)
        {
            if (tab == null || !tab.IsClosable)
            {
                return false;
            }

            int index = Tabs.IndexOf(tab);
            if (index < 0)
            {
                return false;
            }

            tab.State = TabLifecycleState.Closing;

            bool wasSelected = Equals(SelectedTab, tab);

            // Clean up resources if disposable
            if (tab.Content is IDisposable pageDisposable)
            {
                pageDisposable.Dispose();
            }
            else if (tab.Content is FrameworkElement fe && fe.DataContext is IDisposable vmDisposable)
            {
                vmDisposable.Dispose();
            }

            Tabs.RemoveAt(index);
            tab.State = TabLifecycleState.Disposed;

            if (wasSelected && Tabs.Count > 0)
            {
                int newIndex = Math.Max(0, index - 1);
                SelectedTab = Tabs[newIndex];
                SelectedTab.State = TabLifecycleState.Active;
            }

            return true;
        }

        /// <summary>
        /// Selects the tab at the specified zero-based index.
        /// </summary>
        /// <param name="index">Zero-based tab index.</param>
        public void SelectTab(int index)
        {
            if (index >= 0 && index < Tabs.Count)
            {
                SelectedTab = Tabs[index];
                SelectedTab.State = TabLifecycleState.Active;
            }
        }

        partial void OnSelectedTabChanged(TabItemModel? oldValue, TabItemModel? newValue)
        {
            if (oldValue != null && oldValue.State == TabLifecycleState.Active)
            {
                oldValue.State = TabLifecycleState.Background;
                oldValue.IsSelected = false;
            }

            if (newValue != null)
            {
                newValue.State = TabLifecycleState.Active;
                newValue.IsSelected = true;
            }
        }
    }
}
