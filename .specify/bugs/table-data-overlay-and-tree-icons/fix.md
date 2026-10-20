# Bug Fix: Table Data Viewport Overlay Blocking, Non-Interactive Rows/Cells & Inappropriate Schema Tree Glyphs

- **Slug**: table-data-overlay-and-tree-icons
- **Fixed**: 2026-10-20T13:34:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Resolved the persistent table selection hint overlay by implementing `NullToVisibilityConverter` and setting `IsHitTestVisible="False"` on the placeholder. Enabled table interaction by setting `SelectionMode="Single"` on `ListView` and `IsTextSelectionEnabled="True"` on cell `TextBlock`s. Corrected schema tree and viewport icon glyphs across `DatabaseViewControl`, `DataViewControl`, and `DatabaseInfo`.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Helpers/Converters.cs` | modified | Added `NullToVisibilityConverter` and `NotNullToVisibilityConverter` with US English XML comments. |
| `DataSphere/App.xaml` | modified | Registered `NullToVisibilityConverter` and `NotNullToVisibilityConverter` as application resources. |
| `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml` | modified | Switched placeholder visibility converter to `NullToVisibilityConverter`, added `IsHitTestVisible="False"`, and updated icon to `&#xF0E2;`. |
| `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs` | modified | Updated schema tree node icon glyphs to appropriate database representations: Database (`\uEDA2`), Tables category (`\uE8B7`), Table item (`\uF0E2`), Views (`\uE890`), Functions (`\uF168`). |
| `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml` | modified | Changed toolbar icon to `&#xF0E2;`, changed `ListView.SelectionMode` to `Single`, and added `IsTextSelectionEnabled="True"` on cell `TextBlock`s. |
| `DataSphere/Models/Database/DatabaseInfo.cs` | modified | Aligned `DatabaseCategory` glyphs for consistency (`\uE8B7`, `\uE890`, `\uF168`). |
| `scratch/VerifyDatabaseView/Program.cs` | modified | Added Tests 21–29 verifying converters, XAML bindings, hit test safety, and icon glyphs. |

## Diff Highlights

```xml
<!-- DatabaseViewControl.xaml -->
<StackPanel
    Visibility="{x:Bind ViewModel.RightPanelContent, Mode=OneWay, Converter={StaticResource NullToVisibilityConverter}}"
    IsHitTestVisible="False"
    HorizontalAlignment="Center"
    VerticalAlignment="Center"
    Spacing="12">
    <FontIcon Glyph="&#xF0E2;" FontSize="40" Foreground="{ThemeResource TextFillColorTertiaryBrush}" HorizontalAlignment="Center" />
```

```xml
<!-- DataViewControl.xaml -->
<ListView
    ItemsSource="{x:Bind ViewModel.DataPage.Rows, Mode=OneWay}"
    SelectionMode="Single"
    Padding="0,4">
    <ListView.ItemTemplate>
        <DataTemplate x:DataType="models:TableRowData">
            <ItemsControl ItemsSource="{x:Bind Cells}">
                ...
                <TextBlock
                    Text="{x:Bind}"
                    TextTrimming="CharacterEllipsis"
                    IsTextSelectionEnabled="True" />
```

```csharp
// DatabaseViewControl.xaml.cs
var dbNode = CreateNode(db.Name, "\uEDA2", db); // Storage/HardDrive
var tablesCatNode = CreateNode(LanguageBase.GetLangValue("dbinf_tables_title"), "\uE8B7", db); // Folder
var tableNode = CreateNode(table.Name, "\uF0E2", new TableNodeContext(db, table)); // GridView/Table
args.Node.Children.Add(CreateNode(LanguageBase.GetLangValue("dbinf_views_title"), "\uE890", db)); // View/Eye
args.Node.Children.Add(CreateNode(LanguageBase.GetLangValue("dbinf_fncs_title"), "\uF168", db)); // Function fx
```

## Tests Added or Updated

- `scratch/VerifyDatabaseView/Program.cs`:
  - `Test 21`: `NullToVisibilityConverter` returns `Visible` for `null` and `Collapsed` for non-null objects.
  - `Test 22`: `NotNullToVisibilityConverter` returns `Collapsed` for `null` and `Visible` for non-null objects.
  - `Test 23`: `DatabaseViewControl.xaml` binds placeholder using `NullToVisibilityConverter`.
  - `Test 24`: `DatabaseViewControl.xaml` sets `IsHitTestVisible="False"` on placeholder.
  - `Test 26`: `DataViewControl.xaml` sets `SelectionMode="Single"` on `ListView`.
  - `Test 27`: `DataViewControl.xaml` sets `IsTextSelectionEnabled="True"` on cell `TextBlock`.
  - `Test 28`: `DatabaseViewControl.xaml.cs` maps `\uEDA2` for database schema node and `\uF0E2` for table nodes.
  - `Test 29`: `DatabaseInfo.cs` maps `\uE8B7` for tables, `\uE890` for views, and `\uF168` for functions.

## Local Verification

- Commands run:
  - `dotnet build DataSphere\DataSphere.csproj -c Debug` → Succeeded (0 Warning, 0 Error).
  - `dotnet run --project scratch/VerifyDatabaseView/VerifyDatabaseView.csproj` → 29 passed, 0 failed.

## Deviations from Assessment

None. All changes faithfully followed the preferred remediation outlined in `assessment.md`.

## Follow-ups

- Run `/speckit-bug-test slug=table-data-overlay-and-tree-icons` to record the formal verification test report and visual desktop verification.
