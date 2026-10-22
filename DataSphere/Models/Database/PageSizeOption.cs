using System;
using CommunityToolkit.Mvvm.ComponentModel;
using DataSphere.Utils;

namespace DataSphere.Models.Database
{
    /// <summary>
    /// Represents a selectable pagination page size option in the database viewport.
    /// Supports dynamic localization synchronization when language switches at runtime.
    /// </summary>
    public sealed partial class PageSizeOption : ObservableObject, IDisposable
    {
        private readonly string? _localizationKey;
        private bool _disposed;

        /// <summary>
        /// Gets the numeric limit value representing the maximum number of rows to retrieve per page, or <see cref="int.MaxValue"/> for infinity.
        /// </summary>
        public int Value { get; }

        /// <summary>
        /// Gets or sets the localized or textual label displayed in the user interface.
        /// </summary>
        [ObservableProperty]
        public partial string DisplayText { get; set; }

        /// <summary>
        /// Gets a value indicating whether this option represents an unbounded (infinite) row limit.
        /// </summary>
        public bool IsInfinity => Value == int.MaxValue;

        /// <summary>
        /// Initializes a new instance of the <see cref="PageSizeOption"/> class with a static display text.
        /// </summary>
        /// <param name="value">The row limit value or <see cref="int.MaxValue"/>.</param>
        /// <param name="displayText">The text to display in the selector.</param>
        public PageSizeOption(int value, string displayText)
        {
            Value = value;
            DisplayText = displayText;
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="PageSizeOption"/> class with a dynamic localization key.
        /// </summary>
        /// <param name="value">The row limit value or <see cref="int.MaxValue"/>.</param>
        /// <param name="localizationKey">The resource key in localization files.</param>
        /// <param name="defaultText">The fallback text to display if localization is unavailable.</param>
        public PageSizeOption(int value, string localizationKey, string defaultText)
        {
            Value = value;
            _localizationKey = localizationKey;
            DisplayText = LanguageBase.GetLangValue(localizationKey) ?? defaultText;
            LanguageBase.LanguageChanged += OnLanguageChanged;
        }

        /// <summary>
        /// Handles the application language changed notification to update <see cref="DisplayText"/>.
        /// </summary>
        /// <param name="language">The newly selected language code.</param>
        private void OnLanguageChanged(string language)
        {
            if (!string.IsNullOrEmpty(_localizationKey))
            {
                DisplayText = LanguageBase.GetLangValue(_localizationKey) ?? DisplayText;
            }
        }

        /// <inheritdoc/>
        public override string ToString() => DisplayText;

        /// <inheritdoc/>
        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;

            LanguageBase.LanguageChanged -= OnLanguageChanged;
        }
    }
}
