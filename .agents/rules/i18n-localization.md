# i18n-localization

> Hardcoded user-facing string literals in C# and XAML are STRICTLY FORBIDDEN. All UI text MUST be dynamically resolved via `TranslationSource` and `.resx` localization resources.

## Why It Matters

DataSphere supports multi-language execution (e.g. English, Vietnamese) with live, dynamic switching from the Settings page. 
Hardcoding user-facing strings (such as tab titles `"Cơ sở dữ liệu"`, `"Cài Đặt"`, button captions, card descriptions, or message dialogs):
- Breaks the dynamic localization mechanism when the user switches languages.
- Causes inconsistent user experiences where parts of the interface remain in Vietnamese while the rest is in English (or vice versa).
- Violates **DataSphere Constitution Principle VII (Zero Hardcoded User-Facing Strings & Dynamic Internationalization)**.

## Bad Examples

```csharp
// BAD: Hardcoded string literal in method parameters
public void OpenDatabase()
{
    _tabService.OpenTab(typeof(DatabasePage), "Cơ sở dữ liệu", "\uE774");
}

// BAD: Hardcoded default string property in ViewModel
[ObservableProperty]
public partial string Title { get; set; } = "Cơ sở dữ liệu";

// BAD: Hardcoded strings in XAML
<TextBlock Text="Cơ sở dữ liệu" />
<Button Content="Cài Đặt" />
```

## Good Examples

### 1. In C# ViewModels / Services:
```csharp
// GOOD: Dynamic string lookup via TranslationSource or LanguageBase
public void OpenDatabase()
{
    // Option A: Pass translation resource key or resolved localized string
    string title = LanguageBase.GetLangValue("db_title") ?? "Database";
    _tabService.OpenTab(typeof(DatabasePage), title, "\uE774", "db_title");
}

// GOOD: Property that dynamically updates when language changes
public partial class DatabaseViewModel : ObservableObject
{
    [ObservableProperty]
    public partial string Title { get; set; } = string.Empty;

    public DatabaseViewModel()
    {
        UpdateLocalizedStrings();
        TranslationSource.Instance.PropertyChanged += (s, e) => UpdateLocalizedStrings();
    }

    private void UpdateLocalizedStrings()
    {
        Title = LanguageBase.GetLangValue("db_title") ?? "Database";
    }
}
```

### 2. In Models / Tab items:
```csharp
// GOOD: TabItemModel storing a TitleKey so when language switches, the tab title updates automatically
public partial class TabItemModel : ObservableObject
{
    public string? TitleKey { get; set; }

    public TabItemModel()
    {
        TranslationSource.Instance.PropertyChanged += (s, e) =>
        {
            if (!string.IsNullOrEmpty(TitleKey))
            {
                Title = LanguageBase.GetLangValue(TitleKey) ?? Title;
            }
        };
    }
}
```

### 3. In XAML:
```xml
<!-- MANDATORY: Binding directly to the Localization StaticResource via resource key indexer -->
<TextBlock Text="{Binding [page_db_title], Source={StaticResource Localization}, Mode=OneWay}" />
<TextBlock Text="{Binding [page_settings_title], Source={StaticResource Localization}, Mode=OneWay}" />
```
> [!IMPORTANT]
> In XAML views, always bind UI text directly to `{StaticResource Localization}` using the indexer syntax `{Binding [KeyName], Source={StaticResource Localization}, Mode=OneWay}` instead of cluttering ViewModels with redundant display string properties.

## Resource File Locations
All localization keys MUST be maintained across:
- `DataSphere/Resources/Locales/String.resx` (Default / Fallback)
- `DataSphere/Resources/Locales/String.en.resx` (English)
- `DataSphere/Resources/Locales/String.vi.resx` (Vietnamese)
