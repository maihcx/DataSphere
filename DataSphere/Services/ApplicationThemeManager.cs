﻿namespace DataSphere.Services
{
    public class ApplicationThemeManagerService(Window mainWindow)
    {
        public WindowBackdropType GetBackdropType()
        {
            return (WindowBackdropType)Enum.Parse(
                typeof(WindowBackdropType), 
                UserDataStore.GetValue<string>("IWindowBackdropType")
            );
        }

        public delegate void ThemeChangedHandle(ThemeType theme);

        public event ThemeChangedHandle? OnThemeChanged;

        public Window MainWindowHandle { get; private set; } = mainWindow;

        public bool IsWatcher {  get; set; }

        public void SetBackdropType(WindowBackdropType _WindowBackdropType)
        {
            UserDataStore.SetValue("IWindowBackdropType", _WindowBackdropType.ToString());

            ThemeApply(GetSysApplicationTheme(), _WindowBackdropType);
        }

        public ThemeConfigs.IThemeType GetApplicationTheme()
        {
            try
            {
                return (ThemeConfigs.IThemeType)Enum.Parse(
                    typeof(ThemeConfigs.IThemeType),
                    UserDataStore.GetValue<string>("IThemeType")
                );
            }
            catch
            {
                return ThemeConfigs.IThemeType.Auto;
            }
        }

        public ThemeType GetSysApplicationTheme()
        {
            ThemeType _ThemeType = ThemeType.Unknown;
            if (UserDataStore.GetValue<string>("IThemeType") == "Auto")
            {
                ApplicationThemeManager.ApplySystemTheme();
                _ThemeType = ApplicationThemeManager.GetAppTheme();
            }
            else
            {
                _ThemeType = (ThemeType)Enum.Parse(
                    typeof(ThemeType),
                    UserDataStore.GetValue<string>("IThemeType")
                );
            }

            return _ThemeType;
        }

        private int globalCornerRadius = UserDataStore.GetValue<int>("ObjectCornerRadius");
        public int GlobalCornerRadius { get => globalCornerRadius; 
            set
            {
                if (globalCornerRadius == value) return;

                globalCornerRadius = value;

                Application.Current.Resources["ControlCornerRadius"] = new CornerRadius(value);
                UserDataStore.SetValue("ObjectCornerRadius", value);
            }
        }

        public void SetApplicationTheme(ThemeConfigs.IThemeType _IThemeType) 
        { 
            //if (GetApplicationTheme() == _IThemeType) return;

            UnWatch();
            UserDataStore.SetValue("IThemeType", _IThemeType.ToString());
            ThemeType applicationTheme = GetSysApplicationTheme();
            WindowBackdropType windowBackdropType = GetBackdropType();

            if (_IThemeType == ThemeConfigs.IThemeType.Auto)
            {
                Watch(applicationTheme, windowBackdropType);
            }
            else
            {
                ThemeApply(applicationTheme, windowBackdropType);
            }
            OnThemeChanged?.Invoke(applicationTheme);
        }

        public void Watch(ThemeType applicationTheme = ThemeType.Unknown, WindowBackdropType windowBackdrop = WindowBackdropType.Tabbed, bool updateAccents = true)
        {
            if (!IsWatcher)
            {
                ThemeApply(applicationTheme, windowBackdrop);
                Watcher.Watch(WindowHelper.MainWindow, windowBackdrop, updateAccents);
                SystemThemeWatcher.Watch(MainWindowHandle, this.GetBackdropType(), updateAccents);

                IsWatcher = true;
            }
        }

        private void ThemeApply(ThemeType applicationTheme = ThemeType.Light, WindowBackdropType backgroundEffect = WindowBackdropType.Mica)
        {
            ApplicationThemeManager.Apply(applicationTheme, backgroundEffect, true);
        }

        public void UnWatch()
        {
            if (IsWatcher)
            {
                Watcher.UnWatch(WindowHelper.MainWindow);
                SystemThemeWatcher.UnWatch(MainWindowHandle);
                IsWatcher = false;
            }
        }

        public void InitCornerRadius()
        {
            Application.Current.Resources["ControlCornerRadius"] = new CornerRadius(GlobalCornerRadius);
        }

        public ObservableCollection<Models.ComboBoxItem> GetThemeCBBs()
        {
            return new ObservableCollection<Models.ComboBoxItem>(
                Enum.GetValues(typeof(ThemeConfigs.IThemeType))
                    .Cast<ThemeConfigs.IThemeType>()
                    .Where(e => e != ThemeConfigs.IThemeType.Unknown)
                    .Select(e => new Models.ComboBoxItem
                    {
                        Value = ((int)e).ToString(),
                        Content = e.ToString()
                    })
            );
        }

        public Models.ComboBoxItem GetThemeCBBSelected()
        {
            return GetThemeCBBs().FirstOrDefault(x => x.Content == GetApplicationTheme().ToString()) ?? 
                new Models.ComboBoxItem() { 
                    Content = ThemeConfigs.IThemeType.Auto.ToString(), 
                    Value = ((int)ThemeConfigs.IThemeType.Auto).ToString() 
                };
        }

        public ObservableCollection<Models.ComboBoxItem> GetMaterialCBBs()
        {
            return new ObservableCollection<Models.ComboBoxItem>(
                Enum.GetValues(typeof(WindowBackdropType))
                    .Cast<WindowBackdropType>()
                    .Select(e => new Models.ComboBoxItem
                    {
                        Value = ((int)e).ToString(),
                        Content = e.ToString()
                    })
            );
        }

        public Models.ComboBoxItem GetMaterialCBBSelected()
        {
            return GetMaterialCBBs().FirstOrDefault(x => x.Content == GetBackdropType().ToString()) ??
                new Models.ComboBoxItem()
                {
                    Content = WindowBackdropType.Mica.ToString(),
                    Value = ((int)WindowBackdropType.Mica).ToString()
                };
        }
    }
}
