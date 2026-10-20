using CommunityToolkit.Mvvm.ComponentModel;

namespace DataSphere.Models.Database
{
    /// <summary>
    /// Represents the pure data payload for a database schema explorer tree node.
    /// Decouples visual tree presentation from node data to prevent UIElement reparenting
    /// and virtualization container recycling crashes while notifying UI bindings of state changes.
    /// </summary>
    public sealed partial class DatabaseTreeNode : ObservableObject
    {
        /// <summary>
        /// Gets or sets the display text for the tree node.
        /// </summary>
        [ObservableProperty]
        public partial string Title { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the Segoe Fluent Icon glyph for the tree node.
        /// </summary>
        [ObservableProperty]
        public partial string IconGlyph { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets a value indicating whether child schema objects are currently being loaded asynchronously.
        /// </summary>
        [ObservableProperty]
        public partial bool IsLoading { get; set; }

        /// <summary>
        /// Gets or sets the underlying data model associated with this tree node
        /// (e.g. <see cref="DatabaseInfo"/>, <see cref="ConnectionRoot"/>, or table context).
        /// </summary>
        public object? DataContext { get; set; }
    }
}
