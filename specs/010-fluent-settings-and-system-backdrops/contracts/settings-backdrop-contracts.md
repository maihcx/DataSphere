# Contracts: Settings ViewModel, Backdrop Service & UI Tokens

**Feature**: `010-fluent-settings-and-system-backdrops`
**Date**: 2026-10-21T14:13:45+07:00

---

## 1. `SettingsViewModel` Observable API

```csharp
namespace DataSphere.ViewModels.PagesBottom
{
    public partial class SettingsViewModel : ObservableObject
    {
        /// <summary>
        /// Gets the available system backdrop options ("Mica", "Tabbed", "Acrylic", "Solid").
        /// </summary>
        public ObservableCollection<BackdropOptionItem> BackdropList { get; }

        /// <summary>
        /// Gets or sets the selected system backdrop option.
        /// Changing this property immediately notifies IThemeService and applies the backdrop across windows.
        /// </summary>
        [ObservableProperty]
        public partial BackdropOptionItem? SelectedBackdrop { get; set; }
    }
}
```

---

## 2. Localization Resource Contract (`String.*.resx`)

All entries are strictly encoded in UTF-8 without BOM:

| Resource Key | English Value (`String.en.resx` / `String.resx`) | Vietnamese Value (`String.vi.resx`) |
|---|---|---|
| `page_settings_backdrop_title` | `Backdrop Material` | `Hiệu ứng nền` |
| `page_settings_backdrop_summary` | `Select Windows system backdrop material (Mica, Tabbed, Acrylic)` | `Chọn hiệu ứng chất liệu nền hệ thống (Mica, Tabbed, Acrylic)` |
| `backdrop_tabbed` | `Tabbed (Mica Alt)` | `Tabbed (Mica Alt)` |
| `backdrop_mica` | `Mica (Standard)` | `Mica (Tiêu chuẩn)` |
| `backdrop_acrylic` | `Acrylic (Frosted Glass)` | `Acrylic (Kính mờ)` |
| `backdrop_solid` | `Solid (Default)` | `Mặc định (Đơn sắc)` |

---

## 3. Settings Card XAML Pattern Contract

In `SettingsPage.xaml`:

```xml
<!-- System Backdrop Card -->
<Border
    Background="{ThemeResource CardBackgroundFillColorDefaultBrush}"
    BorderBrush="{ThemeResource CardStrokeColorDefaultBrush}"
    BorderThickness="1"
    CornerRadius="8"
    Padding="16,14">
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto" />
            <ColumnDefinition Width="*" />
            <ColumnDefinition Width="Auto" />
        </Grid.ColumnDefinitions>

        <FontIcon Grid.Column="0" Glyph="&#xE790;" FontSize="20" Margin="0,0,16,0" VerticalAlignment="Center" Foreground="{ThemeResource TextFillColorPrimaryBrush}" />

        <StackPanel Grid.Column="1" VerticalAlignment="Center" Spacing="2">
            <TextBlock Text="{Binding [page_settings_backdrop_title], Source={StaticResource Localization}, Mode=OneWay}" Style="{StaticResource BodyStrongTextBlockStyle}" />
            <TextBlock Text="{Binding [page_settings_backdrop_summary], Source={StaticResource Localization}, Mode=OneWay}" Style="{StaticResource CaptionTextBlockStyle}" Foreground="{ThemeResource TextFillColorSecondaryBrush}" TextWrapping="Wrap" />
        </StackPanel>

        <ComboBox
            Grid.Column="2"
            MinWidth="200"
            HorizontalAlignment="Right"
            VerticalAlignment="Center"
            ItemsSource="{x:Bind ViewModel.BackdropList, Mode=OneWay}"
            SelectedItem="{x:Bind ViewModel.SelectedBackdrop, Mode=TwoWay}"
            DisplayMemberPath="Content" />
    </Grid>
</Border>
```
