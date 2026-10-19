using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using Microsoft.UI.Xaml;

namespace DataSphere.Models
{
    /// <summary>
    /// Represents an active top-level native desktop window hosting a tabbed application shell.
    /// </summary>
    public partial class WindowSession : ObservableObject
    {
        /// <summary>
        /// Gets the unique session identifier for this window.
        /// </summary>
        public Guid WindowId { get; init; } = Guid.NewGuid();

        /// <summary>
        /// Gets or sets the reference to the underlying native WinUI 3 window instance.
        /// </summary>
        [ObservableProperty]
        public partial Window? WindowInstance { get; set; }

        /// <summary>
        /// Gets the collection of active tabs hosted inside this window.
        /// </summary>
        public ObservableCollection<TabItemModel> Tabs { get; } = new();

        /// <summary>
        /// Gets or sets the currently active and visible tab in this window.
        /// </summary>
        [ObservableProperty]
        public partial TabItemModel? SelectedTab { get; set; }

        /// <summary>
        /// Gets or sets a value indicating whether this is the primary application window created during startup.
        /// </summary>
        [ObservableProperty]
        public partial bool IsPrimary { get; set; }

        /// <summary>
        /// Appends a new tab to this window session and ensures it is marked active.
        /// </summary>
        /// <param name="tab">The tab model to append.</param>
        public void AddTab(TabItemModel tab)
        {
            if (tab == null)
            {
                throw new ArgumentNullException(nameof(tab));
            }

            Tabs.Add(tab);
            SelectedTab = tab;
            tab.State = TabLifecycleState.Active;
        }

        /// <summary>
        /// Attempts to close and remove a tab from this window session.
        /// </summary>
        /// <param name="tab">The tab model to remove.</param>
        /// <returns><c>true</c> if the tab was closed and removed; otherwise <c>false</c> if the tab is not closable.</returns>
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
        /// Determines whether this donor window meets the condition to auto-close when a content tab is transferred out.
        /// Returns <c>true</c> if there are currently exactly two tabs (Home and one content tab).
        /// </summary>
        /// <returns><c>true</c> if transferring a tab leaves only the non-closable Home tab.</returns>
        public bool CanAutoCloseOnTransfer()
        {
            return Tabs.Count == 2 || (Tabs.Count == 1 && !Tabs[0].IsClosable);
        }
    }
}
