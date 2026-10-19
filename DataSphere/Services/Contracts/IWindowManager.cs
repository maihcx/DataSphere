using Windows.Foundation;
using DataSphere.Models;

namespace DataSphere.Services.Contracts
{
    /// <summary>
    /// Service coordinating multi-window lifecycle, tab tear-off, and cross-window docking.
    /// </summary>
    public interface IWindowManager
    {
        /// <summary>
        /// Gets the read-only collection of all currently open WindowSessions.
        /// </summary>
        IReadOnlyList<WindowSession> Windows { get; }

        /// <summary>
        /// Registers a newly created top-level window session.
        /// </summary>
        /// <param name="session">The window session to register.</param>
        void RegisterWindow(WindowSession session);

        /// <summary>
        /// Deregisters and cleans up a closing window session.
        /// </summary>
        /// <param name="windowId">The unique ID of the closing window.</param>
        void UnregisterWindow(Guid windowId);

        /// <summary>
        /// Spawns a new independent window hosting a torn-off tab at the specified screen coordinates.
        /// </summary>
        /// <param name="tab">The tab model being torn off.</param>
        /// <param name="screenPosition">The drop coordinates on screen.</param>
        /// <returns>The newly instantiated WindowSession.</returns>
        WindowSession TearOffTabToNewWindow(TabItemModel tab, Point screenPosition);

        /// <summary>
        /// Transfers a tab from a donor window to a target window at a specific index.
        /// </summary>
        /// <param name="sourceWindowId">The ID of the donor window.</param>
        /// <param name="targetWindowId">The ID of the receiving window.</param>
        /// <param name="tab">The tab model to transfer.</param>
        /// <param name="targetIndex">The target insertion index in the receiving tab strip.</param>
        void TransferTab(Guid sourceWindowId, Guid targetWindowId, TabItemModel tab, int targetIndex);
    }
}
