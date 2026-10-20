namespace DataSphere.Models
{
    /// <summary>
    /// Represents the persisted physical layout, dimensions, and presentation state of a top-level window.
    /// </summary>
    public record WindowPlacementState
    {
        /// <summary>
        /// Gets the minimum allowable window width in pixels.
        /// </summary>
        public const double MinimumWidth = 800.0;

        /// <summary>
        /// Gets the minimum allowable window height in pixels.
        /// </summary>
        public const double MinimumHeight = 500.0;

        /// <summary>
        /// Gets or initializes the horizontal screen position of the window's top-left corner in pixels.
        /// </summary>
        public double Left { get; init; } = 100.0;

        /// <summary>
        /// Gets or initializes the vertical screen position of the window's top-left corner in pixels.
        /// </summary>
        public double Top { get; init; } = 100.0;

        /// <summary>
        /// Gets or initializes the physical width of the window in pixels.
        /// </summary>
        public double Width { get; init; } = 1280.0;

        /// <summary>
        /// Gets or initializes the physical height of the window in pixels.
        /// </summary>
        public double Height { get; init; } = 800.0;

        /// <summary>
        /// Gets or initializes a value indicating whether the window was in a maximized state when closed.
        /// </summary>
        public bool IsMaximized { get; init; } = false;

        /// <summary>
        /// Gets a value indicating whether the current dimensions satisfy the minimum size constraints.
        /// </summary>
        public bool IsValid => Width >= MinimumWidth && Height >= MinimumHeight;
    }
}
