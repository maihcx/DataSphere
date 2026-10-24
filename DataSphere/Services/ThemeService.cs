using System;
using Microsoft.UI;
using Microsoft.UI.Composition.SystemBackdrops;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using DataSphere.Models;
using DataSphere.Services.Contracts;
using DataSphere.Utils;
using DataSphere.Views.Windows;

namespace DataSphere.Services
{
    /// <summary>
    /// Service responsible for managing application-wide theme preferences and system backdrops across open windows.
    /// </summary>
    public class ThemeService : IThemeService
    {
        private readonly IServiceProvider _serviceProvider;
        private string _currentTheme = "Default";
        private string _currentBackdrop = "Mica";

        /// <summary>
        /// Gets the current theme preference string ("Light", "Dark", "Default").
        /// </summary>
        public string CurrentTheme => _currentTheme;

        /// <summary>
        /// Gets the active Windows system backdrop material type ("Mica", "Tabbed", "Acrylic", "Solid").
        /// </summary>
        public string CurrentBackdrop => _currentBackdrop;

        /// <summary>
        /// Gets the currently active application theme domain mode.
        /// </summary>
        public AppThemeMode CurrentThemeMode => ToThemeMode(_currentTheme);

        /// <summary>
        /// Gets the currently active system backdrop material domain mode.
        /// </summary>
        public AppBackdropMode CurrentBackdropMode => ToBackdropMode(_currentBackdrop);

        /// <summary>
        /// Occurs when the application theme changes.
        /// </summary>
        public event EventHandler<string>? ThemeChanged;

        /// <summary>
        /// Occurs when the active system backdrop material changes.
        /// </summary>
        public event EventHandler<string>? BackdropChanged;

        /// <summary>
        /// Occurs when the active application theme domain mode changes.
        /// </summary>
        public event EventHandler<AppThemeMode>? ThemeModeChanged;

        /// <summary>
        /// Occurs when the active system backdrop material domain mode changes.
        /// </summary>
        public event EventHandler<AppBackdropMode>? BackdropModeChanged;

        /// <summary>
        /// Initializes a new instance of the <see cref="ThemeService"/> class.
        /// </summary>
        /// <param name="serviceProvider">The application service provider for resolving window management services.</param>
        public ThemeService(IServiceProvider serviceProvider)
        {
            _serviceProvider = serviceProvider ?? throw new ArgumentNullException(nameof(serviceProvider));
        }

        /// <summary>
        /// Initializes the theme and system backdrop from persistent storage and applies them to the application.
        /// </summary>
        public void Initialize()
        {
            var savedTheme = UserDataStore.GetValue<string>("IThemeType");
            if (string.IsNullOrWhiteSpace(savedTheme))
            {
                savedTheme = "Default";
            }
            _currentTheme = savedTheme;

            var savedBackdrop = UserDataStore.GetValue<string>("ISystemBackdropType");
            if (string.IsNullOrWhiteSpace(savedBackdrop))
            {
                savedBackdrop = "Mica";
            }
            else if (string.Equals(savedBackdrop, "Default", StringComparison.OrdinalIgnoreCase))
            {
                savedBackdrop = "Solid";
            }
            _currentBackdrop = savedBackdrop;
        }

        /// <summary>
        /// Sets and persists the application theme domain mode, notifying all active windows to refresh their visual state.
        /// </summary>
        /// <param name="theme">The target domain theme mode.</param>
        public void SetTheme(AppThemeMode theme)
        {
            SetTheme(theme.ToString());
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

            if (_currentTheme == themeName)
            {
                return;
            }

            _currentTheme = themeName;
            UserDataStore.SetValue("IThemeType", _currentTheme);

            var windowManager = _serviceProvider.GetService(typeof(IWindowManager)) as IWindowManager;
            if (windowManager != null)
            {
                foreach (var session in windowManager.Windows)
                {
                    // ShellWindow handles its own theme transition with snapshot cross-fade on ThemeChanged
                    if (session.WindowInstance != null && session.WindowInstance is not ShellWindow)
                    {
                        ApplyThemeAndBackdrop(session.WindowInstance);
                    }
                }
            }

            ThemeChanged?.Invoke(this, _currentTheme);
            ThemeModeChanged?.Invoke(this, CurrentThemeMode);
        }

        /// <summary>
        /// Sets and persists the Windows system backdrop material domain mode, notifying all active windows to update their backdrop.
        /// </summary>
        /// <param name="backdrop">The target domain backdrop material mode.</param>
        public void SetBackdrop(AppBackdropMode backdrop)
        {
            SetBackdrop(backdrop.ToString());
        }

        /// <summary>
        /// Sets and persists the Windows system backdrop material, notifying all active windows to update their backdrop.
        /// </summary>
        /// <param name="backdrop">The backdrop material name ("Mica", "Tabbed", "Acrylic", "Solid").</param>
        public void SetBackdrop(string backdrop)
        {
            if (string.IsNullOrWhiteSpace(backdrop))
            {
                backdrop = "Mica";
            }
            else if (string.Equals(backdrop, "Default", StringComparison.OrdinalIgnoreCase))
            {
                backdrop = "Solid";
            }

            if (_currentBackdrop == backdrop)
            {
                return;
            }

            _currentBackdrop = backdrop;
            UserDataStore.SetValue("ISystemBackdropType", _currentBackdrop);

            var windowManager = _serviceProvider.GetService(typeof(IWindowManager)) as IWindowManager;
            if (windowManager != null)
            {
                foreach (var session in windowManager.Windows)
                {
                    // ShellWindow handles its own backdrop transition with snapshot cross-fade on BackdropChanged
                    if (session.WindowInstance != null && session.WindowInstance is not ShellWindow)
                    {
                        ApplyThemeAndBackdrop(session.WindowInstance);
                    }
                }
            }

            BackdropChanged?.Invoke(this, _currentBackdrop);
            BackdropModeChanged?.Invoke(this, CurrentBackdropMode);
        }

        /// <summary>
        /// Applies the active theme to the specified window instance.
        /// </summary>
        /// <param name="window">The window to theme.</param>
        public void ApplyThemeToWindow(object window)
        {
            ApplyThemeAndBackdrop(window);
        }

        /// <summary>
        /// Applies the active system backdrop material to the specified window instance.
        /// </summary>
        /// <param name="window">The window to apply the backdrop material to.</param>
        public void ApplyBackdropToWindow(object window)
        {
            ApplyThemeAndBackdrop(window);
        }

        /// <summary>
        /// Applies both the active theme and system backdrop material to the specified window instance in a unified step.
        /// </summary>
        /// <param name="window">The window to theme and apply backdrop material to.</param>
        public void ApplyThemeAndBackdrop(object window)
        {
            if (window is Window win)
            {
                var elementTheme = GetElementTheme(_currentTheme);

                if (win.Content is FrameworkElement fe && fe.RequestedTheme != elementTheme)
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

                if (!IsBackdropMatching(win.SystemBackdrop, _currentBackdrop))
                {
                    switch (_currentBackdrop)
                    {
                        case "Mica":
                            win.SystemBackdrop = new MicaBackdrop { Kind = MicaKind.Base };
                            break;
                        case "Tabbed":
                            win.SystemBackdrop = new MicaBackdrop { Kind = MicaKind.BaseAlt };
                            break;
                        case "Acrylic":
                            win.SystemBackdrop = new DesktopAcrylicBackdrop();
                            break;
                        case "Solid":
                        default:
                            win.SystemBackdrop = null;
                            break;
                    }
                }

                if (win.Content is Panel rootPanel)
                {
                    if (win.SystemBackdrop != null)
                    {
                        rootPanel.Background = new SolidColorBrush(Colors.Transparent);
                    }
                    else
                    {
                        // Solid backdrop requires an explicit, theme-synchronized opaque background
                        // to prevent the Win32 window canvas from falling back to default white.
                        bool isDark = elementTheme == ElementTheme.Dark ||
                                     (elementTheme == ElementTheme.Default && Application.Current?.RequestedTheme == ApplicationTheme.Dark);

                        rootPanel.Background = isDark
                            ? new SolidColorBrush(Windows.UI.Color.FromArgb(255, 32, 32, 32))   // WinUI 3 SolidBackgroundFillColorBase Dark (#202020)
                            : new SolidColorBrush(Windows.UI.Color.FromArgb(255, 243, 243, 243)); // WinUI 3 SolidBackgroundFillColorBase Light (#F3F3F3)
                    }
                }
            }
        }

        /// <summary>
        /// Determines whether the active system backdrop on a window matches the target backdrop configuration.
        /// </summary>
        /// <param name="currentBackdrop">The current backdrop instance on the window.</param>
        /// <param name="targetBackdropType">The target backdrop configuration name.</param>
        /// <returns><c>true</c> if the backdrop already matches the target type; otherwise, <c>false</c>.</returns>
        private static bool IsBackdropMatching(Microsoft.UI.Xaml.Media.SystemBackdrop? currentBackdrop, string targetBackdropType)
        {
            if (currentBackdrop == null)
            {
                return string.Equals(targetBackdropType, "Solid", StringComparison.OrdinalIgnoreCase);
            }

            if (currentBackdrop is MicaBackdrop mica)
            {
                if (string.Equals(targetBackdropType, "Mica", StringComparison.OrdinalIgnoreCase))
                {
                    return mica.Kind == MicaKind.Base;
                }
                if (string.Equals(targetBackdropType, "Tabbed", StringComparison.OrdinalIgnoreCase))
                {
                    return mica.Kind == MicaKind.BaseAlt;
                }
                return false;
            }

            if (currentBackdrop is DesktopAcrylicBackdrop)
            {
                return string.Equals(targetBackdropType, "Acrylic", StringComparison.OrdinalIgnoreCase);
            }

            return false;
        }

        /// <summary>
        /// Applies the current theme to a ContentDialog.
        /// </summary>
        /// <param name="dialog">The ContentDialog to theme.</param>
        public void ApplyThemeToDialog(ContentDialog dialog)
        {
            if (dialog == null) return;
            var elementTheme = GetElementTheme(_currentTheme);
            dialog.RequestedTheme = elementTheme;
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

        private static AppThemeMode ToThemeMode(string themeName)
        {
            return themeName switch
            {
                "Light" => AppThemeMode.Light,
                "Dark" => AppThemeMode.Dark,
                _ => AppThemeMode.Default
            };
        }

        private static AppBackdropMode ToBackdropMode(string backdropName)
        {
            return backdropName switch
            {
                "Tabbed" => AppBackdropMode.Tabbed,
                "Acrylic" => AppBackdropMode.Acrylic,
                "Solid" => AppBackdropMode.Solid,
                _ => AppBackdropMode.Mica
            };
        }
    }
}
