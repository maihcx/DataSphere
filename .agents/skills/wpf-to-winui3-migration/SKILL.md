---
name: wpf-to-winui3-migration
description: "Migrate WPF applications to WinUI 3 (Windows App SDK) — namespace replacements, control mapping, ContentDialog XamlRoot handling, DispatcherQueue threading, CommunityToolkit.Mvvm conversion, and ThemeResource dynamic theming based on Microsoft PowerToys migration standards."
---

# WPF to WinUI 3 Migration Guide (PowerToys Standard)

Guide for migrating desktop applications from WPF to WinUI 3 (Windows App SDK).

## 1. Namespace & Core Assembly Replacements

| WPF | WinUI 3 | Notes |
|-----|---------|-------|
| `System.Windows` | `Microsoft.UI.Xaml` | Core visual namespace |
| `System.Windows.Controls` | `Microsoft.UI.Xaml.Controls` | Standard controls |
| `System.Windows.Media` | `Microsoft.UI.Xaml.Media` | Brushes, transforms |
| `System.Windows.Input` | `Microsoft.UI.Xaml.Input` | Pointer & keyboard events |
| `System.Windows.Data` | `Microsoft.UI.Xaml.Data` | Binding & value converters |
| `System.Windows.Threading.Dispatcher` | `Microsoft.UI.Dispatching.DispatcherQueue` | UI thread dispatching |
| `System.Windows.Media.Imaging` | `Microsoft.UI.Xaml.Media.Imaging` / `Windows.Graphics.Imaging` | BitmapImage, SoftwareBitmap |

## 2. Controls & Layout Mapping

- **DataGrid**: Use `ListView` with header Grid or Community Toolkit DataGrid.
- **WrapPanel**: Use `ItemsRepeater` with `UniformGridLayout` or community panel.
- **TabControl**: Use `TabView`.
- **TreeView**: Use WinUI 3 `TreeView` with `TreeViewNode` or hierarchical data binding.
- **Menu / ContextMenu**: Use `MenuBar` / `MenuFlyout` / `MenuFlyoutItem`.
- **StatusBar**: Use bottom `Grid` row with status elements.
- **Expander**: Built-in WinUI 3 `Expander`.

## 3. Critical WinUI 3 Gotchas & Rules

### ContentDialog XamlRoot Requirement
In WinUI 3, every `ContentDialog` MUST have its `XamlRoot` explicitly assigned before calling `ShowAsync()`:
```csharp
var dialog = new ContentDialog
{
    XamlRoot = activeWindow.Content.XamlRoot,
    Title = "Connection Settings",
    PrimaryButtonText = "Save",
    CloseButtonText = "Cancel"
};
await dialog.ShowAsync();
```
Failing to assign `XamlRoot` throws `InvalidOperationException`.

### Threading with DispatcherQueue
```csharp
// WPF:
Application.Current.Dispatcher.Invoke(() => { ... });

// WinUI 3:
dispatcherQueue.TryEnqueue(() => { ... });
```

### Theming: DynamicResource vs ThemeResource
- Replace all `{DynamicResource ...}` with `{ThemeResource ...}`.
- Colors: Use WinUI 3 theme resources like `{ThemeResource CardBackgroundFillColorDefaultBrush}`, `{ThemeResource TextFillColorPrimaryBrush}`, etc.

### MVVM Pattern
- Use `CommunityToolkit.Mvvm` (`ObservableObject`, `[ObservableProperty]`, `[RelayCommand]`).
- Keep ViewModels completely UI-agnostic; never import `Microsoft.UI.Xaml` in ViewModels.
