# UI & Service Contracts: Dedicated ComboBox Models and Dynamic i18n Theme Architecture

**Feature Branch**: `011-combobox-models-theme-i18n`
**Date**: 2026-10-21
**Spec**: [spec.md](../spec.md) | **Data Model**: [data-model.md](../data-model.md)

## 1. `IThemeService` Service Contract

```csharp
namespace DataSphere.Services.Contracts
{
    /// <summary>
    /// Service responsible for managing application visual themes and window backdrops.
    /// </summary>
    public interface IThemeService
    {
        /// <summary>
        /// Occurs when the active application theme changes.
        /// </summary>
        event EventHandler<AppThemeMode>? ThemeChanged;

        /// <summary>
        /// Occurs when the active system backdrop material changes.
        /// </summary>
        event EventHandler<AppBackdropMode>? BackdropChanged;

        /// <summary>
        /// Gets the currently active application theme mode.
        /// </summary>
        AppThemeMode CurrentTheme { get; }

        /// <summary>
        /// Gets the currently active system backdrop material mode.
        /// </summary>
        AppBackdropMode CurrentBackdrop { get; }

        /// <summary>
        /// Sets and persists the application visual theme mode.
        /// </summary>
        /// <param name="theme">The target theme mode.</param>
        void SetTheme(AppThemeMode theme);

        /// <summary>
        /// Sets and persists the window system backdrop material mode.
        /// </summary>
        /// <param name="backdrop">The target backdrop mode.</param>
        void SetBackdrop(AppBackdropMode backdrop);

        /// <summary>
        /// Synchronizes both theme and backdrop states onto the specified window instance.
        /// </summary>
        /// <param name="window">The target WinUI 3 window.</param>
        void ApplyThemeAndBackdrop(object window);
    }
}
```

---

## 2. `SettingsViewModel` Contract

```csharp
namespace DataSphere.ViewModels.PagesBottom
{
    public partial class SettingsViewModel : ObservableObject
    {
        /// <summary>
        /// Gets the observable collection of available color theme choices.
        /// </summary>
        public ObservableCollection<ThemeOptionItem> ThemeList { get; } = new();

        /// <summary>
        /// Gets or sets the currently selected color theme option.
        /// </summary>
        [ObservableProperty]
        public partial ThemeOptionItem? SelectedTheme { get; set; }

        /// <summary>
        /// Gets the observable collection of available system backdrop material choices.
        /// </summary>
        public ObservableCollection<BackdropOptionItem> BackdropList { get; } = new();

        /// <summary>
        /// Gets or sets the currently selected system backdrop material option.
        /// </summary>
        [ObservableProperty]
        public partial BackdropOptionItem? SelectedBackdrop { get; set; }

        /// <summary>
        /// Gets the observable collection of available UI language options.
        /// </summary>
        public ObservableCollection<LanguageOptionItem> Languages { get; } = new();

        /// <summary>
        /// Gets or sets the currently selected UI display language.
        /// </summary>
        [ObservableProperty]
        public partial LanguageOptionItem? SelectedLanguage { get; set; }

        /// <summary>
        /// Updates localized text properties on existing option items in-place without rebuilding collections.
        /// </summary>
        private void UpdateLocalizedStrings();
    }
}
```

---

## 3. `SettingsPage.xaml` XAML View Binding Contract

```xml
<!-- Theme Selector ComboBox -->
<ComboBox
    Grid.Column="2"
    MinWidth="200"
    HorizontalAlignment="Right"
    VerticalAlignment="Center"
    ItemsSource="{x:Bind ViewModel.ThemeList, Mode=OneWay}"
    SelectedItem="{x:Bind ViewModel.SelectedTheme, Mode=TwoWay}"
    DisplayMemberPath="DisplayName" />

<!-- Backdrop Selector ComboBox -->
<ComboBox
    Grid.Column="2"
    MinWidth="200"
    HorizontalAlignment="Right"
    VerticalAlignment="Center"
    ItemsSource="{x:Bind ViewModel.BackdropList, Mode=OneWay}"
    SelectedItem="{x:Bind ViewModel.SelectedBackdrop, Mode=TwoWay}"
    DisplayMemberPath="DisplayName" />

<!-- Language Selector ComboBox -->
<ComboBox
    Grid.Column="2"
    MinWidth="200"
    HorizontalAlignment="Right"
    VerticalAlignment="Center"
    ItemsSource="{x:Bind ViewModel.Languages, Mode=OneWay}"
    SelectedItem="{x:Bind ViewModel.SelectedLanguage, Mode=TwoWay}"
    DisplayMemberPath="NativeName" />
```
