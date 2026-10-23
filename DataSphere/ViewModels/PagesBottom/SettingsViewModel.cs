using System;
using System.Collections.ObjectModel;
using System.Linq;
using System.Reflection;
using CommunityToolkit.Mvvm.ComponentModel;
using DataSphere.Models;
using DataSphere.Models.Settings;
using DataSphere.Services.Contracts;
using DataSphere.Utils;

namespace DataSphere.ViewModels.PagesBottom
{
    /// <summary>
    /// ViewModel for the application settings page, governing personalization, system backdrops, language preferences, and version information.
    /// </summary>
    public partial class SettingsViewModel : ObservableObject
    {
        private readonly IThemeService? _themeService;
        private readonly ITabMemorySaverService? _tabMemorySaverService;

        /// <summary>
        /// Gets or sets a value indicating whether tab memory saver is enabled.
        /// </summary>
        [ObservableProperty]
        public partial bool EnableTabMemorySaver { get; set; } = true;

        /// <summary>
        /// Gets or sets the selectable timeout duration options for background tab sleeping.
        /// </summary>
        [ObservableProperty]
        public partial ObservableCollection<TabSleepTimeoutOption> SleepTimeoutOptions { get; set; } = new();

        /// <summary>
        /// Gets or sets the currently selected timeout duration option.
        /// </summary>
        [ObservableProperty]
        public partial TabSleepTimeoutOption? SelectedSleepTimeoutOption { get; set; }

        /// <summary>
        /// Gets or sets the copyright notice text.
        /// </summary>
        [ObservableProperty]
        public partial string CopyRight { get; set; } = AppInfoHelper.CopyRight;

        /// <summary>
        /// Gets or sets the application version text.
        /// </summary>
        [ObservableProperty]
        public partial string AppVersion { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the available application theme options.
        /// </summary>
        [ObservableProperty]
        public partial ObservableCollection<ThemeOptionItem> ThemeList { get; set; } = new();

        /// <summary>
        /// Gets or sets the selected application theme option.
        /// </summary>
        [ObservableProperty]
        public partial ThemeOptionItem? SelectedTheme { get; set; }

        /// <summary>
        /// Gets or sets the available Windows system backdrop material options.
        /// </summary>
        [ObservableProperty]
        public partial ObservableCollection<BackdropOptionItem> BackdropList { get; set; } = new();

        /// <summary>
        /// Gets or sets the selected Windows system backdrop material option.
        /// </summary>
        [ObservableProperty]
        public partial BackdropOptionItem? SelectedBackdrop { get; set; }

        /// <summary>
        /// Gets or sets the available language options.
        /// </summary>
        [ObservableProperty]
        public partial ObservableCollection<LanguageOptionItem> Languages { get; set; } = LanguageBase.GetLanguageOptionItems();

        /// <summary>
        /// Gets or sets the selected UI display language.
        /// </summary>
        [ObservableProperty]
        public partial LanguageOptionItem? SelectedLanguage { get; set; }

        /// <summary>
        /// Initializes a new instance of the <see cref="SettingsViewModel"/> class resolving dependencies from the service provider.
        /// </summary>
        public SettingsViewModel() : this(App.GetService<IThemeService>(), App.GetService<ITabMemorySaverService>())
        {
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="SettingsViewModel"/> class with the specified theme service and tab memory saver service.
        /// </summary>
        /// <param name="themeService">The application theme service.</param>
        /// <param name="tabMemorySaverService">The tab memory saver service.</param>
        public SettingsViewModel(IThemeService? themeService, ITabMemorySaverService? tabMemorySaverService = null)
        {
            _themeService = themeService;
            _tabMemorySaverService = tabMemorySaverService ?? App.GetService<ITabMemorySaverService>();
            AppVersion = $"{AppInfoHelper.AppName} - {GetAssemblyVersion()}";
            InitializeThemes();
            InitializeBackdrops();
            InitializeLanguages();
            InitializeTabMemorySaver();
            UpdateLocalizedStrings();
            TranslationSource.Instance.PropertyChanged += (s, e) => UpdateLocalizedStrings();
        }

        private void InitializeTabMemorySaver()
        {
            EnableTabMemorySaver = _tabMemorySaverService?.IsEnabled ?? (UserDataStore.GetValue<bool?>("EnableTabMemorySaver") ?? true);
            int currentMinutes = _tabMemorySaverService?.IdleTimeoutMinutes ?? (UserDataStore.GetValue<int?>("TabSleepTimeoutMinutes") ?? 15);
            BuildSleepTimeoutOptions(currentMinutes);
        }

        private void BuildSleepTimeoutOptions(int selectedMinutes)
        {
            SleepTimeoutOptions = new ObservableCollection<TabSleepTimeoutOption>
            {
                new TabSleepTimeoutOption(1, LanguageBase.GetLangValue("tab_sleep_timeout_1m") ?? "1 minute"),
                new TabSleepTimeoutOption(5, LanguageBase.GetLangValue("tab_sleep_timeout_5m") ?? "5 minutes"),
                new TabSleepTimeoutOption(15, LanguageBase.GetLangValue("tab_sleep_timeout_15m") ?? "15 minutes"),
                new TabSleepTimeoutOption(30, LanguageBase.GetLangValue("tab_sleep_timeout_30m") ?? "30 minutes"),
                new TabSleepTimeoutOption(60, LanguageBase.GetLangValue("tab_sleep_timeout_60m") ?? "1 hour")
            };

            SelectedSleepTimeoutOption = SleepTimeoutOptions.FirstOrDefault(o => o.Minutes == selectedMinutes) ?? SleepTimeoutOptions.FirstOrDefault(o => o.Minutes == 15);
        }

        partial void OnEnableTabMemorySaverChanged(bool value)
        {
            if (_tabMemorySaverService != null)
            {
                _tabMemorySaverService.IsEnabled = value;
            }
            else
            {
                UserDataStore.SetValue("EnableTabMemorySaver", value);
            }
        }

        partial void OnSelectedSleepTimeoutOptionChanged(TabSleepTimeoutOption? value)
        {
            if (value != null)
            {
                if (_tabMemorySaverService != null)
                {
                    _tabMemorySaverService.IdleTimeoutMinutes = value.Minutes;
                }
                else
                {
                    UserDataStore.SetValue("TabSleepTimeoutMinutes", value.Minutes);
                }
            }
        }

        private void InitializeThemes()
        {
            ThemeList = new ObservableCollection<ThemeOptionItem>
            {
                new ThemeOptionItem(AppThemeMode.Light, LanguageBase.GetLangValue("theme_light"), iconGlyph: "\uE706"),
                new ThemeOptionItem(AppThemeMode.Dark, LanguageBase.GetLangValue("theme_dark"), iconGlyph: "\uE708"),
                new ThemeOptionItem(AppThemeMode.Default, LanguageBase.GetLangValue("theme_default"), iconGlyph: "\uE790")
            };

            var targetMode = _themeService?.CurrentThemeMode ?? ResolvePersistedThemeMode();
            SelectedTheme = ThemeList.FirstOrDefault(t => t.Mode == targetMode) ?? ThemeList.FirstOrDefault();
        }

        private void InitializeBackdrops()
        {
            BackdropList = new ObservableCollection<BackdropOptionItem>
            {
                new BackdropOptionItem(AppBackdropMode.Mica, LanguageBase.GetLangValue("backdrop_mica"), LanguageBase.GetLangValue("page_settings_backdrop_summary"), "\uE790"),
                new BackdropOptionItem(AppBackdropMode.Tabbed, LanguageBase.GetLangValue("backdrop_tabbed"), LanguageBase.GetLangValue("page_settings_backdrop_summary"), "\uE790"),
                new BackdropOptionItem(AppBackdropMode.Acrylic, LanguageBase.GetLangValue("backdrop_acrylic"), LanguageBase.GetLangValue("page_settings_backdrop_summary"), "\uE790"),
                new BackdropOptionItem(AppBackdropMode.Solid, LanguageBase.GetLangValue("backdrop_solid"), LanguageBase.GetLangValue("page_settings_backdrop_summary"), "\uE790")
            };

            var targetMode = _themeService?.CurrentBackdropMode ?? ResolvePersistedBackdropMode();
            SelectedBackdrop = BackdropList.FirstOrDefault(b => b.Mode == targetMode) ?? BackdropList.FirstOrDefault();
        }

        private void InitializeLanguages()
        {
            Languages = LanguageBase.GetLanguageOptionItems();
            var currentLangCode = LanguageBase.GetCurrentLanguage().TwoLetterISOLanguageName;
            SelectedLanguage = Languages.FirstOrDefault(l => string.Equals(l.Code, currentLangCode, StringComparison.OrdinalIgnoreCase)) ?? Languages.FirstOrDefault();
        }

        private void UpdateLocalizedStrings()
        {
            foreach (var theme in ThemeList)
            {
                theme.DisplayName = theme.Mode switch
                {
                    AppThemeMode.Light => LanguageBase.GetLangValue("theme_light"),
                    AppThemeMode.Dark => LanguageBase.GetLangValue("theme_dark"),
                    _ => LanguageBase.GetLangValue("theme_default")
                };
            }

            foreach (var backdrop in BackdropList)
            {
                backdrop.DisplayName = backdrop.Mode switch
                {
                    AppBackdropMode.Mica => LanguageBase.GetLangValue("backdrop_mica"),
                    AppBackdropMode.Tabbed => LanguageBase.GetLangValue("backdrop_tabbed"),
                    AppBackdropMode.Acrylic => LanguageBase.GetLangValue("backdrop_acrylic"),
                    AppBackdropMode.Solid => LanguageBase.GetLangValue("backdrop_solid"),
                    _ => backdrop.Mode.ToString()
                };
                backdrop.Summary = LanguageBase.GetLangValue("page_settings_backdrop_summary");
            }

            int currentMinutes = SelectedSleepTimeoutOption?.Minutes ?? 15;
            BuildSleepTimeoutOptions(currentMinutes);
        }

        private static AppThemeMode ResolvePersistedThemeMode()
        {
            var saved = UserDataStore.GetValue<string>("IThemeType");
            if (Enum.TryParse<AppThemeMode>(saved, true, out var mode))
            {
                return mode;
            }
            return AppThemeMode.Default;
        }

        private static AppBackdropMode ResolvePersistedBackdropMode()
        {
            var saved = UserDataStore.GetValue<string>("ISystemBackdropType");
            if (string.Equals(saved, "Default", StringComparison.OrdinalIgnoreCase) || string.Equals(saved, "Solid", StringComparison.OrdinalIgnoreCase))
            {
                return AppBackdropMode.Solid;
            }
            if (Enum.TryParse<AppBackdropMode>(saved, true, out var mode))
            {
                return mode;
            }
            return AppBackdropMode.Mica;
        }

        private static string GetAssemblyVersion()
        {
            return Assembly.GetExecutingAssembly().GetName().Version?.ToString() ?? "1.0.0";
        }

        partial void OnSelectedLanguageChanged(LanguageOptionItem? value)
        {
            if (value?.Code != null && !string.Equals(value.Code, LanguageBase.GetCurrentLanguage().TwoLetterISOLanguageName, StringComparison.OrdinalIgnoreCase))
            {
                LanguageBase.SetLanguage(value.Code);
            }
        }

        partial void OnSelectedThemeChanged(ThemeOptionItem? value)
        {
            if (value != null)
            {
                if (_themeService != null)
                {
                    _themeService.SetTheme(value.Mode);
                }
                else
                {
                    UserDataStore.SetValue("IThemeType", value.Mode.ToString());
                }
            }
        }

        partial void OnSelectedBackdropChanged(BackdropOptionItem? value)
        {
            if (value != null)
            {
                if (_themeService != null)
                {
                    _themeService.SetBackdrop(value.Mode);
                }
                else
                {
                    UserDataStore.SetValue("ISystemBackdropType", value.Mode.ToString());
                }
            }
        }
    }
}
