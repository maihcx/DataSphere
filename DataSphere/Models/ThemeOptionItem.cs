using System;
using CommunityToolkit.Mvvm.ComponentModel;

namespace DataSphere.Models
{
    /// <summary>
    /// Represents a selectable application color theme option displayed in settings.
    /// </summary>
    public partial class ThemeOptionItem : ObservableObject
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="ThemeOptionItem"/> class.
        /// </summary>
        /// <param name="mode">The domain theme mode.</param>
        /// <param name="displayName">The localized display name.</param>
        /// <param name="description">The localized descriptive text.</param>
        /// <param name="iconGlyph">The Segoe Fluent Icon glyph representing this mode.</param>
        public ThemeOptionItem(AppThemeMode mode, string displayName, string description = "", string iconGlyph = "\uE790")
        {
            Mode = mode;
            DisplayName = displayName;
            Description = description;
            IconGlyph = iconGlyph;
        }

        /// <summary>
        /// Gets the underlying domain color theme mode.
        /// </summary>
        public AppThemeMode Mode { get; init; }

        /// <summary>
        /// Gets or sets the localized display name of the theme mode.
        /// </summary>
        [ObservableProperty]
        public partial string DisplayName { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the localized descriptive subtitle explaining the theme characteristics.
        /// </summary>
        [ObservableProperty]
        public partial string Description { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the Segoe Fluent Icon glyph representing the theme mode.
        /// </summary>
        public string IconGlyph { get; init; } = "\uE790";

        /// <summary>
        /// Returns the display name of this theme option.
        /// </summary>
        /// <returns>The localized display name.</returns>
        public override string ToString() => DisplayName;

        /// <summary>
        /// Determines whether the specified object is equal to the current theme option instance.
        /// </summary>
        /// <param name="obj">The object to compare with the current instance.</param>
        /// <returns><c>true</c> if the specified object has the same mode; otherwise, <c>false</c>.</returns>
        public override bool Equals(object? obj)
        {
            return obj is ThemeOptionItem other && Mode == other.Mode;
        }

        /// <summary>
        /// Gets the hash code for this theme option item.
        /// </summary>
        /// <returns>A hash code for the current theme option item.</returns>
        public override int GetHashCode()
        {
            return (int)Mode;
        }
    }
}
