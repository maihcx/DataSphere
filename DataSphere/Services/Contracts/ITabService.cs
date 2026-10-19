using System.Collections.ObjectModel;
using DataSphere.Models;

namespace DataSphere.Services.Contracts
{
    /// <summary>
    /// Service responsible for managing tabbed navigation and tab lifecycle inside a window shell.
    /// </summary>
    public interface ITabService
    {
        /// <summary>
        /// Gets the observable collection of tabs active in the current window.
        /// </summary>
        ObservableCollection<TabItemModel> Tabs { get; }

        /// <summary>
        /// Gets or sets the currently selected and active tab.
        /// </summary>
        TabItemModel? SelectedTab { get; set; }

        /// <summary>
        /// Opens a new tab of the specified page type or switches to an existing tab, dynamically resolving title from a resource key.
        /// </summary>
        /// <param name="pageType">The concrete Type of the page to host.</param>
        /// <param name="titleKey">The localization resource key for the tab header.</param>
        /// <param name="iconGlyph">Fluent icon glyph for the tab.</param>
        /// <param name="parameter">Optional navigation parameter passed to the ViewModel.</param>
        /// <returns>The opened or focused TabItemModel instance.</returns>
        TabItemModel OpenTab(Type pageType, string titleKey, string iconGlyph, object? parameter = null);

        /// <summary>
        /// Requests closing of the specified tab.
        /// </summary>
        /// <param name="tab">The tab to close.</param>
        /// <returns><c>true</c> if the tab was closed successfully; otherwise <c>false</c> if closure was cancelled or forbidden.</returns>
        bool CloseTab(TabItemModel tab);

        /// <summary>
        /// Selects the tab at the specified zero-based index.
        /// </summary>
        /// <param name="index">Zero-based tab index.</param>
        void SelectTab(int index);
    }
}
