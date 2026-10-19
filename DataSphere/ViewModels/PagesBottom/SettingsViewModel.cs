using System.Collections.ObjectModel;
using System.Reflection;
using CommunityToolkit.Mvvm.ComponentModel;
using DataSphere.Models;
using DataSphere.Utils;

namespace DataSphere.ViewModels.PagesBottom
{
    /// <summary>
    /// ViewModel for the application settings page, governing personalization, language preferences, and version information.
    /// </summary>
    public partial class SettingsViewModel : ObservableObject
    {
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
        public partial ObservableCollection<SettingOptionItem> ThemeList { get; set; } = new();

        /// <summary>
        /// Gets or sets the selected application theme.
        /// </summary>
        [ObservableProperty]
        public partial SettingOptionItem? SelectedTheme { get; set; }

        /// <summary>
        /// Gets or sets the available language options.
        /// </summary>
        [ObservableProperty]
        public partial ObservableCollection<LanguageItem> Languages { get; set; } = LanguageBase.GetLanguageItems();

        /// <summary>
        /// Gets or sets the selected UI display language.
        /// </summary>
        [ObservableProperty]
        public partial LanguageItem SelectedLanguage { get; set; } = LanguageBase.GetCurrentLanguageItem();

        /// <summary>
        /// Initializes a new instance of the <see cref="SettingsViewModel"/> class.
        /// </summary>
        public SettingsViewModel()
        {
            AppVersion = $"{AppInfoHelper.AppName} - {GetAssemblyVersion()}";
            InitializeThemes();
            UpdateLocalizedStrings();
            TranslationSource.Instance.PropertyChanged += (s, e) => UpdateLocalizedStrings();
        }

        private void InitializeThemes()
        {
            ThemeList = new ObservableCollection<SettingOptionItem>
            {
                new SettingOptionItem { Value = "Light", Content = LanguageBase.GetLangValue("theme_light") },
                new SettingOptionItem { Value = "Dark", Content = LanguageBase.GetLangValue("theme_dark") },
                new SettingOptionItem { Value = "Default", Content = LanguageBase.GetLangValue("theme_default") }
            };

            var savedTheme = UserDataStore.GetValue<string>("IThemeType");
            SelectedTheme = ThemeList.FirstOrDefault(t => t.Value == savedTheme) ?? ThemeList.FirstOrDefault();
        }

        private void UpdateLocalizedStrings()
        {
            foreach (var theme in ThemeList)
            {
                if (theme.Value == "Light") theme.Content = LanguageBase.GetLangValue("theme_light");
                else if (theme.Value == "Dark") theme.Content = LanguageBase.GetLangValue("theme_dark");
                else if (theme.Value == "Default") theme.Content = LanguageBase.GetLangValue("theme_default");
            }
        }

        private static string GetAssemblyVersion()
        {
            return Assembly.GetExecutingAssembly().GetName().Version?.ToString() ?? "1.0.0";
        }

        partial void OnSelectedLanguageChanged(LanguageItem value)
        {
            if (value?.Code != null)
            {
                LanguageBase.SetLanguage(value.Code);
            }
        }

        partial void OnSelectedThemeChanged(SettingOptionItem? value)
        {
            if (value?.Value != null)
            {
                UserDataStore.SetValue("IThemeType", value.Value);
            }
        }
    }
}
