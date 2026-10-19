using CommunityToolkit.Mvvm.ComponentModel;

namespace DataSphere.Models
{
    /// <summary>
    /// Represents an option item displayed in selection dropdowns and settings lists.
    /// </summary>
    public partial class SettingOptionItem : ObservableObject
    {
        /// <summary>
        /// Gets or sets the underlying configuration value.
        /// </summary>
        public string? Value { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the user-friendly display text.
        /// </summary>
        [ObservableProperty]
        public partial string? Content { get; set; } = string.Empty;

        /// <summary>
        /// Returns the display content of this option.
        /// </summary>
        public override string ToString() => Content ?? string.Empty;

        /// <summary>
        /// Determines whether the specified object is equal to the current instance.
        /// </summary>
        public override bool Equals(object? obj)
        {
            return obj is SettingOptionItem other && this.Value == other.Value;
        }

        /// <summary>
        /// Gets the hash code for this option item.
        /// </summary>
        public override int GetHashCode()
        {
            return (Value ?? string.Empty).GetHashCode();
        }
    }
}
