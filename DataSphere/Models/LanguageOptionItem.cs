using System;
using CommunityToolkit.Mvvm.ComponentModel;

namespace DataSphere.Models
{
    /// <summary>
    /// Represents a selectable application display language option displayed in settings.
    /// </summary>
    public partial class LanguageOptionItem : ObservableObject
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="LanguageOptionItem"/> class.
        /// </summary>
        public LanguageOptionItem()
        {
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="LanguageOptionItem"/> class with specified details.
        /// </summary>
        /// <param name="code">The standard ISO/BCP-47 language code.</param>
        /// <param name="nativeName">The native display name of the language.</param>
        /// <param name="englishName">The English name of the language.</param>
        public LanguageOptionItem(string code, string nativeName, string englishName = "")
        {
            Code = code;
            NativeName = nativeName;
            EnglishName = englishName;
        }

        /// <summary>
        /// Gets or sets the standard ISO/BCP-47 language code (e.g. "vi", "en").
        /// </summary>
        public string Code { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the localized native display name of the language.
        /// </summary>
        [ObservableProperty]
        public partial string NativeName { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the English name of the language.
        /// </summary>
        [ObservableProperty]
        public partial string EnglishName { get; set; } = string.Empty;

        /// <summary>
        /// Returns the native display name of this language option.
        /// </summary>
        /// <returns>The native language name.</returns>
        public override string ToString() => NativeName;

        /// <summary>
        /// Determines whether the specified object is equal to the current language option instance.
        /// </summary>
        /// <param name="obj">The object to compare with the current instance.</param>
        /// <returns><c>true</c> if the specified object has the same code; otherwise, <c>false</c>.</returns>
        public override bool Equals(object? obj)
        {
            return obj is LanguageOptionItem other && string.Equals(Code, other.Code, StringComparison.OrdinalIgnoreCase);
        }

        /// <summary>
        /// Gets the hash code for this language option item.
        /// </summary>
        /// <returns>A hash code for the current language option item.</returns>
        public override int GetHashCode()
        {
            return StringComparer.OrdinalIgnoreCase.GetHashCode(Code);
        }
    }
}
