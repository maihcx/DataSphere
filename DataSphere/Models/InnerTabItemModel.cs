using CommunityToolkit.Mvvm.ComponentModel;

namespace DataSphere.Models
{
    /// <summary>
    /// Represents an individual inner sub-tab hosted inside the Database workspace TabView.
    /// </summary>
    public partial class InnerTabItemModel : ObservableObject, IDisposable
    {
        /// <summary>
        /// Gets or sets the display header title of the tab.
        /// </summary>
        [ObservableProperty]
        public partial string Header { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the Segoe Fluent Icon glyph displayed next to the tab header.
        /// Defaults to "\uE703" (Connect).
        /// </summary>
        [ObservableProperty]
        public partial string IconGlyph { get; set; } = "\uE703";

        /// <summary>
        /// Gets or sets the visual content element or UserControl hosted within this tab.
        /// </summary>
        [ObservableProperty]
        public partial object? Content { get; set; }

        /// <summary>
        /// Gets or sets a value indicating whether this tab can be closed by the user.
        /// Tab 0 (Connections explorer) is anchored and non-closable.
        /// </summary>
        [ObservableProperty]
        public partial bool IsClosable { get; set; } = true;

        /// <summary>
        /// Gets or sets the unique connection key associated with this tab session, if any.
        /// </summary>
        [ObservableProperty]
        public partial string? ConnectionKey { get; set; }

        /// <summary>
        /// Gets or sets an optional disposable context (e.g. database session or viewmodel)
        /// that must be cleaned up when this tab is closed.
        /// </summary>
        public IDisposable? DisposableContext { get; set; }

        /// <summary>
        /// Releases resources and disposes hosted content or context.
        /// </summary>
        public void Dispose()
        {
            DisposableContext?.Dispose();
            DisposableContext = null;

            if (Content is IDisposable disposable)
            {
                disposable.Dispose();
            }
        }
    }
}
