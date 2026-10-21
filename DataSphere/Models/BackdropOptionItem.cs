using System;
using CommunityToolkit.Mvvm.ComponentModel;

namespace DataSphere.Models
{
    /// <summary>
    /// Represents a selectable Windows system backdrop material option in personalization settings.
    /// </summary>
    public partial class BackdropOptionItem : ObservableObject
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="BackdropOptionItem"/> class.
        /// </summary>
        public BackdropOptionItem()
        {
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="BackdropOptionItem"/> class with specified parameters.
        /// </summary>
        /// <param name="mode">The domain backdrop mode.</param>
        /// <param name="displayName">The localized display title.</param>
        /// <param name="summary">The localized summary description.</param>
        /// <param name="iconGlyph">The Segoe Fluent Icon glyph representing the material.</param>
        public BackdropOptionItem(AppBackdropMode mode, string displayName, string summary = "", string iconGlyph = "\uE790")
        {
            Mode = mode;
            DisplayName = displayName;
            Summary = summary;
            IconGlyph = iconGlyph;
        }

        /// <summary>
        /// Gets or sets the underlying domain backdrop mode.
        /// </summary>
        public AppBackdropMode Mode { get; set; }

        /// <summary>
        /// Gets or sets the unique technical key identifying the backdrop material ("Mica", "Tabbed", "Acrylic", "Solid").
        /// </summary>
        public string Key
        {
            get => Mode.ToString();
            set
            {
                if (Enum.TryParse<AppBackdropMode>(value, true, out var parsedMode))
                {
                    Mode = parsedMode;
                }
            }
        }

        /// <summary>
        /// Gets or sets the localized display title of the backdrop material.
        /// </summary>
        [ObservableProperty]
        public partial string DisplayName { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the legacy display title for backward compatibility with XAML bindings.
        /// </summary>
        public string Content
        {
            get => DisplayName;
            set => DisplayName = value;
        }

        /// <summary>
        /// Gets or sets the localized summary description of the backdrop material.
        /// </summary>
        [ObservableProperty]
        public partial string Summary { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the Segoe Fluent Icon glyph representing the material.
        /// </summary>
        public string IconGlyph { get; set; } = "\uE790";

        /// <summary>
        /// Returns the display content of this backdrop option.
        /// </summary>
        /// <returns>The localized display title.</returns>
        public override string ToString() => DisplayName;

        /// <summary>
        /// Determines whether the specified object is equal to the current backdrop option instance.
        /// </summary>
        /// <param name="obj">The object to compare with the current instance.</param>
        /// <returns><c>true</c> if the specified object has the same mode; otherwise, <c>false</c>.</returns>
        public override bool Equals(object? obj)
        {
            return obj is BackdropOptionItem other && Mode == other.Mode;
        }

        /// <summary>
        /// Gets the hash code for this backdrop option item.
        /// </summary>
        /// <returns>A hash code for the current backdrop option item.</returns>
        public override int GetHashCode()
        {
            return (int)Mode;
        }
    }
}
