namespace DataSphere.Models.Settings
{
    /// <summary>
    /// Represents an option in the inactivity duration timeout dropdown for background tab sleeping.
    /// </summary>
    public class TabSleepTimeoutOption
    {
        /// <summary>
        /// Gets the inactive timeout duration in minutes before putting a tab to sleep.
        /// </summary>
        public int Minutes { get; init; }

        /// <summary>
        /// Gets the localized display name for this timeout duration option.
        /// </summary>
        public string DisplayName { get; init; } = string.Empty;

        /// <summary>
        /// Initializes a new instance of the <see cref="TabSleepTimeoutOption"/> class.
        /// </summary>
        public TabSleepTimeoutOption()
        {
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="TabSleepTimeoutOption"/> class with the specified duration and display name.
        /// </summary>
        /// <param name="minutes">The timeout duration in minutes.</param>
        /// <param name="displayName">The localized display label.</param>
        public TabSleepTimeoutOption(int minutes, string displayName)
        {
            Minutes = minutes;
            DisplayName = displayName;
        }

        /// <inheritdoc />
        public override string ToString() => DisplayName;
    }
}
