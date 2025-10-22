using static DataSphere.Resources.ThemeConfigs;

namespace DataSphere.ViewModels.PagesBottom
{
    public partial class SettingsViewModel : ObservableObject, INavigationAware
    {
        private bool _isInitialized = false;

        private static ApplicationThemeManagerService ThemeManagerService = WindowHelper.ThemeManagerService ?? new ApplicationThemeManagerService(WindowHelper.MainWindow ?? App.Current.MainWindow);

        [ObservableProperty]
        private string _copyRight = AppInfoHelper.CopyRight;

        [ObservableProperty]
        private string _appVersion = string.Empty;

        public Task OnNavigatedToAsync()
        {
            if (!_isInitialized)
                InitializeViewModel();

            return Task.CompletedTask;
        }

        public Task OnNavigatedFromAsync() => Task.CompletedTask;

        private void InitializeViewModel()
        {
            AppVersion = $"{AppInfoHelper.AppName} - {GetAssemblyVersion()}";

            _isInitialized = true;
        }

        private string GetAssemblyVersion()
        {
            return Assembly.GetExecutingAssembly().GetName().Version?.ToString()
                ?? string.Empty;
        }

        #region Navigation panel auto hide
        [ObservableProperty]
        private bool _autoHideNavigationPanel = WindowHelper.IsAutoHideNavPanel;

        partial void OnAutoHideNavigationPanelChanged(bool oldValue, bool newValue)
        {
            WindowHelper.IsAutoHideNavPanel = AutoHideNavigationPanel = newValue;
        }
        #endregion

        #region Language list handle
        [ObservableProperty]
        private LanguageItem _selectedLanguage = LanguageBase.GetCurrentLanguageItem();

        [ObservableProperty]
        private ObservableCollection<LanguageItem> _languages = LanguageBase.GetLanguageItems();

        partial void OnSelectedLanguageChanged(LanguageItem value)
        {
            LanguageBase.SetLanguage(value.Code ?? "en");
        }
        #endregion

        #region Theme list handle
        [ObservableProperty]
        private Models.ComboBoxItem _selectedTheme = ThemeManagerService.GetThemeCBBSelected();

        [ObservableProperty]
        private ObservableCollection<Models.ComboBoxItem> _themeList = ThemeManagerService.GetThemeCBBs();

        partial void OnSelectedThemeChanged(Models.ComboBoxItem value)
        {
            ThemeManagerService.SetApplicationTheme(Enum.Parse<IThemeType>(value.Value ?? "en"));
        }
        #endregion

        #region Material list handle
        [ObservableProperty]
        private Models.ComboBoxItem _selectedMaterial = ThemeManagerService.GetMaterialCBBSelected();

        [ObservableProperty]
        private ObservableCollection<Models.ComboBoxItem> _materialList = ThemeManagerService.GetMaterialCBBs();

        partial void OnSelectedMaterialChanged(Models.ComboBoxItem value)
        {
            ThemeManagerService.SetBackdropType(Enum.Parse<WindowBackdropType>(value.Value ?? WindowBackdropType.Tabbed.ToString()));
            ThemeManagerService.SetApplicationTheme(Enum.Parse<IThemeType>(SelectedTheme.Value ?? IThemeType.Auto.ToString()));
        }
        #endregion

        #region CornerRadius list handle
        [ObservableProperty]
        private int _sliderCornerRadius = ThemeManagerService.GlobalCornerRadius;

        partial void OnSliderCornerRadiusChanged(int oldValue, int newValue)
        {
            ThemeManagerService.GlobalCornerRadius = newValue;
        }
        #endregion
    }
}
