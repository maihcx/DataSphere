using System;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using DataSphere.Services.Contracts;
using DataSphere.Utils;

namespace DataSphere.Services
{
    /// <summary>
    /// Service responsible for managing application-wide theme preferences and applying them across open windows.
    /// </summary>
    public class ThemeService : IThemeService
    {
        private readonly IServiceProvider _serviceProvider;
        private string _currentTheme = "Default";

        /// <summary>
        /// Gets the current theme preference string ("Light", "Dark", "Default").
        /// </summary>
        public string CurrentTheme => _currentTheme;

        /// <summary>
        /// Occurs when the application theme changes.
        /// </summary>
        public event EventHandler<string>? ThemeChanged;

        /// <summary>
        /// Initializes a new instance of the <see cref="ThemeService"/> class.
        /// </summary>
        /// <param name="serviceProvider">The application service provider for resolving window management services.</param>
        public ThemeService(IServiceProvider serviceProvider)
        {
            _serviceProvider = serviceProvider ?? throw new ArgumentNullException(nameof(serviceProvider));
        }

        /// <summary>
        /// Initializes the theme from persistent storage and applies it to the application.
        /// </summary>
        public void Initialize()
        {
            var savedTheme = UserDataStore.GetValue<string>("IThemeType");
            if (string.IsNullOrWhiteSpace(savedTheme))
            {
                savedTheme = "Default";
            }

            _currentTheme = savedTheme;
        }

        /// <summary>
        /// Sets and persists the application theme, notifying all active windows to refresh their visual state.
        /// </summary>
        /// <param name="themeName">The theme mode name ("Light", "Dark", "Default").</param>
        public void SetTheme(string themeName)
        {
            if (string.IsNullOrWhiteSpace(themeName))
            {
                themeName = "Default";
            }

            _currentTheme = themeName;
            UserDataStore.SetValue("IThemeType", _currentTheme);

            var windowManager = _serviceProvider.GetService(typeof(IWindowManager)) as IWindowManager;
            if (windowManager != null)
            {
                foreach (var session in windowManager.Windows)
                {
                    if (session.WindowInstance != null)
                    {
                        ApplyThemeToWindow(session.WindowInstance);
                    }
                }
            }

            ThemeChanged?.Invoke(this, _currentTheme);
        }

        /// <summary>
        /// Applies the active theme to the specified window instance.
        /// </summary>
        /// <param name="window">The window to theme.</param>
        public void ApplyThemeToWindow(object window)
        {
            if (window is Window win)
            {
                var elementTheme = GetElementTheme(_currentTheme);

                if (win.Content is FrameworkElement fe)
                {
                    fe.RequestedTheme = elementTheme;
                }

                if (win.AppWindow?.TitleBar != null)
                {
                    switch (elementTheme)
                    {
                        case ElementTheme.Light:
                            win.AppWindow.TitleBar.ButtonForegroundColor = Colors.Black;
                            win.AppWindow.TitleBar.ButtonHoverForegroundColor = Colors.Black;
                            break;
                        case ElementTheme.Dark:
                            win.AppWindow.TitleBar.ButtonForegroundColor = Colors.White;
                            win.AppWindow.TitleBar.ButtonHoverForegroundColor = Colors.White;
                            break;
                        default:
                            win.AppWindow.TitleBar.ButtonForegroundColor = null;
                            win.AppWindow.TitleBar.ButtonHoverForegroundColor = null;
                            break;
                    }
                }
            }
        }

        private static ElementTheme GetElementTheme(string themeName)
        {
            return themeName switch
            {
                "Light" => ElementTheme.Light,
                "Dark" => ElementTheme.Dark,
                _ => ElementTheme.Default
            };
        }
    }
}
