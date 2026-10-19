namespace DataSphere.Models
{
    /// <summary>
    /// Represents the lifecycle state of an application tab.
    /// </summary>
    public enum TabLifecycleState
    {
        /// <summary>
        /// The tab has been instantiated but not yet activated or focused.
        /// </summary>
        Created,

        /// <summary>
        /// The tab is currently selected, visible, and actively processing user interactions.
        /// </summary>
        Active,

        /// <summary>
        /// The tab remains in memory with open connections or cached state, but is in the background.
        /// </summary>
        Background,

        /// <summary>
        /// Closure has been requested for the tab; pending asynchronous operations are being cancelled.
        /// </summary>
        Closing,

        /// <summary>
        /// The tab has released its resources, closed database sessions, and was removed from the tab collection.
        /// </summary>
        Disposed
    }
}
