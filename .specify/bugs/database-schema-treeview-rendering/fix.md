# Bug Fix: Database Schema TreeView Node Rendering & Hardcoded Hint String

- **Slug**: database-schema-treeview-rendering
- **Fixed**: 2026-10-20T13:13:30+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Resolved the schema explorer TreeView rendering defect by configuring `<TreeView.ItemTemplate>` on `SchemaTree` in `DatabaseViewControl.xaml` with `x:DataType="TreeViewNode"` and `<ContentControl Content="{x:Bind Content}" />`, ensuring that each node's visual `StackPanel` (icon and schema label) is rendered rather than falling back to `Microsoft.UI.Xaml.Controls.TreeViewNode`. Replaced the hardcoded English placeholder text with dynamic localization binding `[page_db_select_table_hint]` across all `.resx` bundles in UTF-8 without BOM per Constitution Principle VII.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml` | modified | Added `<TreeView.ItemTemplate>` to `SchemaTree` with `ContentControl` bound to `{x:Bind Content}`; replaced hardcoded table hint text with dynamic localization binding. |
| `DataSphere/Resources/Locales/String.resx` | modified | Added fallback entry `page_db_select_table_hint`. |
| `DataSphere/Resources/Locales/String.en.resx` | modified | Added English entry `page_db_select_table_hint`. |
| `DataSphere/Resources/Locales/String.vi.resx` | modified | Added Vietnamese entry `page_db_select_table_hint` in strict UTF-8 without BOM. |
| `scratch/VerifyDatabaseView/Program.cs` | modified | Added assertions 15–20 validating resource key resolution, absence of Mojibake, and TreeView ItemTemplate XAML definition. |

## Diff Highlights

### 1. `DatabaseViewControl.xaml`
```xml
<!-- Explorer TreeView -->
<TreeView
    Grid.Row="1"
    x:Name="SchemaTree"
    SelectionMode="Single"
    Expanding="SchemaTree_Expanding"
    ItemInvoked="SchemaTree_ItemInvoked"
    Padding="4">
    <TreeView.ItemTemplate>
        <DataTemplate x:DataType="TreeViewNode">
            <ContentControl
                Content="{x:Bind Content}"
                HorizontalContentAlignment="Stretch"
                VerticalContentAlignment="Center" />
        </DataTemplate>
    </TreeView.ItemTemplate>
</TreeView>
```

```xml
<!-- Empty Selection Placeholder -->
<StackPanel
    Visibility="{x:Bind ViewModel.RightPanelContent, Mode=OneWay, Converter={StaticResource InverseBooleanToVisibilityConverter}}"
    HorizontalAlignment="Center"
    VerticalAlignment="Center"
    Spacing="12">
    <FontIcon Glyph="&#xE82D;" FontSize="40" Foreground="{ThemeResource TextFillColorTertiaryBrush}" HorizontalAlignment="Center" />
    <TextBlock
        Text="{Binding [page_db_select_table_hint], Source={StaticResource Localization}, Mode=OneWay}"
        Style="{StaticResource BodyTextBlockStyle}"
        Foreground="{ThemeResource TextFillColorSecondaryBrush}"
        TextAlignment="Center" />
</StackPanel>
```

### 2. `String.vi.resx` & `String.en.resx`
```xml
<data name="page_db_select_table_hint" xml:space="preserve">
  <value>Chọn một bảng trong danh sách để xem dữ liệu</value>
</data>
```

## Tests Added or Updated

- `scratch/VerifyDatabaseView/Program.cs`:
  - `Test 15`: Verifies `page_db_select_table_hint` exists in `String.vi.resx` with exact text `Chọn một bảng trong danh sách để xem dữ liệu`.
  - `Test 16`: Verifies `LanguageBase.GetLangValue("page_db_select_table_hint")` resolves correctly for Vietnamese culture.
  - `Test 17`: Verifies `LanguageBase.GetLangValue("page_db_select_table_hint")` resolves correctly for English culture.
  - `Test 18`: Verifies `DatabaseViewControl.xaml` exists on disk.
  - `Test 19`: Verifies `DatabaseViewControl.xaml` contains `TreeView.ItemTemplate` with `x:DataType="TreeViewNode"`.
  - `Test 20`: Verifies `DatabaseViewControl.xaml` uses dynamic localization indexer `{Binding [page_db_select_table_hint]}`.

## Local Verification

- Build check: `dotnet build DataSphere\DataSphere.csproj -c Debug` → 0 warnings, 0 errors.
- Unit suite: `dotnet run --project scratch\VerifyDatabaseView\VerifyDatabaseView.csproj` → 20/20 passed.
- Regression suite: `dotnet run --project scratch\VerifyConnectionDialog\VerifyConnectionDialog.csproj` → 28/28 passed.
- Regression suite: `dotnet run --project scratch\VerifyTabTransfer\VerifyTabTransfer.csproj` → 13/13 passed.
- Regression suite: `dotnet run --project scratch\VerifyConnectionStorage\VerifyConnectionStorage.csproj` → 14/14 passed.
- Bridge readiness: `powershell -ExecutionPolicy Bypass -File .\.specify\extensions\speckit-superpowers-bridge\scripts\powershell\bridge-status.ps1 -Readiness` → PASS (status: complete, 0 pending tasks).

## Deviations from Assessment

None. The remediation was implemented exactly as specified in `assessment.md`.

## Follow-ups

- Run `/speckit-bug-test slug=database-schema-treeview-rendering` to capture visual evidence per Constitution Principle VIII.
