using System;

namespace DataSphere.Services.Contracts
{
    /// <summary>
    /// Service responsible for managing application-wide theme preferences and applying them across open windows.
    /// </summary>
    public interface IThemeService
    {
        /// <summary>
        /// Gets the current theme preference string ("Light", "Dark", "Default").
        /// </summary>
        string CurrentTheme { get; }

        /// <summary>
        /// Occurs when the application theme changes.
        /// </summary>
        event EventHandler<string>? ThemeChanged;

        /// <summary>
        /// Initializes the theme from persistent storage and applies it to the application.
        /// </summary>
        void Initialize();

        /// <summary>
        /// Sets and persists the application theme, notifying all active windows to refresh their visual state.
        /// </summary>
        /// <param name="themeName">The theme mode name ("Light", "Dark", "Default").</param>
        void SetTheme(string themeName);

        /// <summary>
        /// Applies the active theme to the specified window instance.
        /// </summary>
        /// <param name="window">The window to theme.</param>
        void ApplyThemeToWindow(object window);
    }
}
