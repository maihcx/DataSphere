using DataSphere.Models;

namespace DataSphere.Services.Contracts
{
    /// <summary>
    /// Manages the background idle evaluation and automated sleeping of inactive tabs.
    /// </summary>
    public interface ITabMemorySaverService : IDisposable
    {
        /// <summary>
        /// Gets or sets a value indicating whether background tab memory saving is active.
        /// </summary>
        bool IsEnabled { get; set; }

        /// <summary>
        /// Gets or sets the idle timeout in minutes before putting an inactive tab to sleep.
        /// </summary>
        int IdleTimeoutMinutes { get; set; }

        /// <summary>
        /// Manually triggers an evaluation pass over all open tabs.
        /// </summary>
        /// <param name="tabs">The collection of all currently opened tabs.</param>
        /// <param name="activeTab">The currently selected active tab, which must remain hot.</param>
        void EvaluateTabs(IEnumerable<TabItemModel> tabs, TabItemModel? activeTab);

        /// <summary>
        /// Awakes a sleeping tab on demand, rehydrating its visual state and restoring active lifecycle state.
        /// </summary>
        /// <param name="tab">The tab to wake up.</param>
        void WakeUpTab(TabItemModel tab);
    }
}
