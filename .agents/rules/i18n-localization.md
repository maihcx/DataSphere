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

---

## Strict File Encoding & Mojibake Prevention Rules

> [!CAUTION]
> Windows PowerShell 5.1 and legacy shell scripting tools default to ANSI/Windows-1252 when redirecting or writing strings. This corrupts UTF-8 multi-byte characters (such as Vietnamese diacritics: `ư`, `ơ`, `ế`, `ộ`), resulting in irreversible Mojibake corruption (e.g., `Kế°t ná»'i` instead of `Kết nối`).

1. **UTF-8 Without BOM**: All `.resx` files MUST be saved in strict UTF-8 without BOM (`new System.Text.UTF8Encoding(false)`).
2. **No Shell ANSI Redirection**: NEVER use shell appending (`>>`, `Out-File`, `Add-Content`) without explicit UTF-8 encoding parameters.
3. **Safe Modification Practices**:
   - Use XML DOM parsers (`System.Xml.Linq.XDocument`, `XmlDocument`) preserving UTF-8 formatting.
   - When generating or patching localized text via scripts, use C# Unicode escape sequences (`\uXXXX`) for non-ASCII characters to guarantee safe transport across any CLI or script environment.

---

## WinUI 3 TabView & Viewport Decoupling Mandate

> [!WARNING]
> In WinUI 3, `TabView` is specialized for tab header management. Any element declared as a direct child of `<TabView>` is treated by XAML layout as a `TabItem` or header element.

- **Prohibition**: Placing viewport host controls (`<ContentControl>`, `<Frame>`, `<ContentPresenter>`) directly inside `<TabView>` tags is STRICTLY FORBIDDEN. Doing so causes the viewport to be swallowed or orphaned, rendering an empty page when tabs change.
- **Mandatory Pattern**: Always decouple the tab strip and viewport into separate Grid rows:
```xml
<!-- GOOD: Decoupled TabView and Content Viewport -->
<Grid>
    <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
        <RowDefinition Height="*" />
    </Grid.RowDefinitions>

    <!-- Row 0: Only tab headers -->
    <TabView Grid.Row="0"
             TabItemsSource="{Binding Tabs}"
             SelectedItem="{Binding SelectedTab, Mode=TwoWay}">
        <!-- TabStripFooter or other header controls only -->
    </TabView>

    <!-- Row 1: Dedicated Viewport -->
    <ContentControl Grid.Row="1"
                    Content="{Binding SelectedTab.Content}" />
</Grid>
```
