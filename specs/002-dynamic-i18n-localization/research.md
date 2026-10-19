# Architectural Research & Technology Decisions: Dynamic i18n & Zero Hardcoded Strings

**Feature**: `002-dynamic-i18n-localization` | **Date**: 2026-10-19

This document outlines the architectural research, trade-offs, and technical decisions made to eradicate hardcoded strings and achieve 100% dynamic internationalization across DataSphere.

---

## 1. Tab Header Dynamic Localization Mechanism

### Decision
Enhance [`TabItemModel`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Models/TabItemModel.cs) with a `TitleKey` property. In `TabItemModel`'s constructor or initialization, subscribe to `TranslationSource.Instance.PropertyChanged`. When a culture change event is dispatched, if `TitleKey` is populated, re-evaluate:
```csharp
Title = LanguageBase.GetLangValue(TitleKey);
```

### Rationale
- `TabViewItem.Header` in WinUI 3 binds directly to `TabItemModel.Title`.
- Subscribing to `TranslationSource.Instance.PropertyChanged` directly inside `TabItemModel` ensures all active and background tabs in every open `ShellWindow` update their headers instantly without tearing down tab views or losing user state (such as text input, active database connections, or scroll position).
- If a tab has a custom dynamic title without a resource key (e.g. an unsaved SQL script file name), `TitleKey` remains null and `Title` is preserved unchanged.

### Alternatives Considered
- *Recreating all tabs upon language switch*: Discarded because it would reset page view states, abort in-flight queries, and induce noticeable UI flickering.
- *XAML Custom MarkupExtension in TabView DataTemplate*: WinUI 3 markup extensions for dynamic binding to static indexers are less predictable than standard `INotifyPropertyChanged` observation in the model.

---

## 2. Tab Creation API Modernization in `ITabService`

### Decision
Update [`ITabService`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Services/Contracts/ITabService.cs) and [`TabService`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Services/TabService.cs) to accept `titleKey`:
```csharp
TabItemModel OpenTab(Type pageType, string titleKey, string iconGlyph, object? parameter = null);
```
Inside `TabService.OpenTab`:
1. Check if an existing unclosable tab (e.g., Home) or singleton tab matches `pageType`.
2. Resolve initial title: `string title = LanguageBase.GetLangValue(titleKey);`
3. Instantiate `TabItemModel` with both `TitleKey = titleKey` and `Title = title`.

### Rationale
- Callers (like `HomeViewModel.OpenDatabaseCommand`) no longer pass hardcoded strings like `"Cơ sở dữ liệu"`. Instead, they pass clean resource keys like `"page_db_title"`.
- Enforces compile-time separation of localization keys from display values, adhering strictly to Constitution Principle VII.

---

## 3. ViewModel Dynamic Localization Pattern

### Decision
For ViewModels exposing user-facing text (`HomeViewModel`, `DatabaseViewModel`, `ShellViewModel`, `SettingsViewModel`):
1. Expose bindable properties for localized titles, section headers, and card summaries.
2. In the ViewModel constructor, call a private method `UpdateLocalizedStrings()` and register a weak or instance handler to `TranslationSource.Instance.PropertyChanged`.
3. In `UpdateLocalizedStrings()`, assign properties via `LanguageBase.GetLangValue("key")` and raise property changed notifications.

### Example Pattern:
```csharp
public partial class HomeViewModel : ObservableObject
{
    [ObservableProperty]
    public partial string SectionsTitle { get; set; } = string.Empty;

    [ObservableProperty]
    public partial string DatabaseCardTitle { get; set; } = string.Empty;

    [ObservableProperty]
    public partial string DatabaseCardSummary { get; set; } = string.Empty;

    [ObservableProperty]
    public partial string SettingsCardTitle { get; set; } = string.Empty;

    [ObservableProperty]
    public partial string SettingsCardSummary { get; set; } = string.Empty;

    public HomeViewModel(ITabService tabService)
    {
        _tabService = tabService;
        UpdateLocalizedStrings();
        TranslationSource.Instance.PropertyChanged += (s, e) => UpdateLocalizedStrings();
    }

    private void UpdateLocalizedStrings()
    {
        SectionsTitle = LanguageBase.GetLangValue("page_home_sections_title");
        DatabaseCardTitle = LanguageBase.GetLangValue("page_db_title");
        DatabaseCardSummary = LanguageBase.GetLangValue("page_db_summary");
        SettingsCardTitle = LanguageBase.GetLangValue("page_settings_title");
        SettingsCardSummary = LanguageBase.GetLangValue("page_settings_summary");
    }
}
```

### Rationale
- Eliminates 100% of hardcoded strings from XAML markup in `HomePage.xaml`.
- Uses standard WinUI 3 `{x:Bind ViewModel.DatabaseCardTitle, Mode=OneWay}`, which is compiled, type-safe, and observes `PropertyChanged` automatically.

---

## 4. Resource Bundle Synchronization (`String.resx`, `String.en.resx`, `String.vi.resx`)

### Decision
Ensure 100% symmetric key definitions across all three locale files:
- `DataSphere/Resources/Locales/String.resx` (Neutral / Invariant / English fallback)
- `DataSphere/Resources/Locales/String.en.resx` (English translation)
- `DataSphere/Resources/Locales/String.vi.resx` (Vietnamese translation)

New keys to register:
- `page_home_sections_title`: `"Main Modules"` / `"Các Phân Hệ Chính"`
- `page_home_banner_title`: `"DataSphere Database Manager"` / `"DataSphere - Quản Lý Cơ Sở Dữ Liệu"`
- `page_home_banner_desc`: Localized application description.
- Audit existing keys `page_home_title`, `page_db_title`, `page_db_summary`, `page_settings_title`, `page_settings_summary`.

---

## 5. Fallback & Resilience Strategy

### Decision
In `LanguageBase.GetLangValue(string key, params object[] args)`:
1. Lookup key in active culture.
2. If null or whitespace, lookup in neutral/English fallback culture (`CultureInfo.InvariantCulture` or `en`).
3. If still null, return `key` as the string fallback to avoid crashes or null references.
