using System;
using DataSphere.Models;

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
        /// Gets the active Windows system backdrop material type ("Mica", "Tabbed", "Acrylic", "Solid").
        /// </summary>
        string CurrentBackdrop { get; }

        /// <summary>
        /// Gets the currently active application theme domain mode.
        /// </summary>
        AppThemeMode CurrentThemeMode { get; }

        /// <summary>
        /// Gets the currently active system backdrop material domain mode.
        /// </summary>
        AppBackdropMode CurrentBackdropMode { get; }

        /// <summary>
        /// Occurs when the application theme changes.
        /// </summary>
        event EventHandler<string>? ThemeChanged;

        /// <summary>
        /// Occurs when the active system backdrop material changes.
        /// </summary>
        event EventHandler<string>? BackdropChanged;

        /// <summary>
        /// Occurs when the active application theme domain mode changes.
        /// </summary>
        event EventHandler<AppThemeMode>? ThemeModeChanged;

        /// <summary>
        /// Occurs when the active system backdrop material domain mode changes.
        /// </summary>
        event EventHandler<AppBackdropMode>? BackdropModeChanged;

        /// <summary>
        /// Initializes the theme and system backdrop from persistent storage and applies them to the application.
        /// </summary>
        void Initialize();

        /// <summary>
        /// Sets and persists the application theme, notifying all active windows to refresh their visual state.
        /// </summary>
        /// <param name="themeName">The theme mode name ("Light", "Dark", "Default").</param>
        void SetTheme(string themeName);

        /// <summary>
        /// Sets and persists the application theme domain mode, notifying all active windows to refresh their visual state.
        /// </summary>
        /// <param name="theme">The target domain theme mode.</param>
        void SetTheme(AppThemeMode theme);

        /// <summary>
        /// Sets and persists the Windows system backdrop material, notifying all active windows to update their backdrop.
        /// </summary>
        /// <param name="backdrop">The backdrop material name ("Mica", "Tabbed", "Acrylic", "Solid").</param>
        void SetBackdrop(string backdrop);

        /// <summary>
        /// Sets and persists the Windows system backdrop material domain mode, notifying all active windows to update their backdrop.
        /// </summary>
        /// <param name="backdrop">The target domain backdrop material mode.</param>
        void SetBackdrop(AppBackdropMode backdrop);

        /// <summary>
        /// Applies the active theme to the specified window instance.
        /// </summary>
        /// <param name="window">The window to theme.</param>
        void ApplyThemeToWindow(object window);

        /// <summary>
        /// Applies the active system backdrop material to the specified window instance.
        /// </summary>
        /// <param name="window">The window to apply the backdrop material to.</param>
        void ApplyBackdropToWindow(object window);

        /// <summary>
        /// Applies both the active theme and system backdrop material to the specified window instance in a unified step.
        /// </summary>
        /// <param name="window">The window to theme and apply backdrop material to.</param>
        void ApplyThemeAndBackdrop(object window);
    }
}
