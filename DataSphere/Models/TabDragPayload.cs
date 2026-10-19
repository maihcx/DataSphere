namespace DataSphere.Models
{
    /// <summary>
    /// Represents the drag payload metadata transferred during tab drag-and-drop operations across windows.
    /// </summary>
    public class TabDragPayload
    {
        /// <summary>
        /// Gets the unique identifier of the donor window initiating the drag operation.
        /// </summary>
        public Guid SourceWindowId { get; init; }

        /// <summary>
        /// Gets the unique identifier of the tab item being dragged.
        /// </summary>
        public Guid TabId { get; init; }

        /// <summary>
        /// Gets the tab model instance being transferred.
        /// </summary>
        public TabItemModel Tab { get; init; } = null!;

        /// <summary>
        /// Gets the original zero-based index of the tab in the donor window's tab strip.
        /// </summary>
        public int SourceIndex { get; init; }
    }
}
