namespace DataSphere.Services.Contracts
{
    /// <summary>
    /// Contract implemented by tab viewports capable of low-power suspension and fast rehydration.
    /// </summary>
    public interface ISleepableTabContent
    {
        /// <summary>
        /// Gets a value indicating whether this tab content is eligible for sleep.
        /// Returns false if active operations, queries, or unsaved changes are present.
        /// </summary>
        bool CanSleep { get; }

        /// <summary>
        /// Releases heavy visual element allocations, stops compositor sync, and trims transient caches.
        /// </summary>
        void Sleep();

        /// <summary>
        /// Rehydrates visual controls and restores active rendering and synchronization upon tab selection.
        /// </summary>
        void WakeUp();
    }
}
