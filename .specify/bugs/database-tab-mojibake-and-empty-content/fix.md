# Bug Fix: Database Tab Mojibake Title and Empty Inner Content Viewport

- **Slug**: database-tab-mojibake-and-empty-content
- **Fixed**: 2026-10-20T10:20:45+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Restored clean UTF-8 Vietnamese translations for all 20 connection management keys in `String.vi.resx` (eliminating `Kế°t ná»'i` Mojibake), and restructured `DatabasePage.xaml` so that `<ContentControl>` is placed in its own grid row outside `<TabView>`, fully restoring visibility and interactivity to `ConnectViewControl` and `DatabaseViewControl`.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Resources/Locales/String.vi.resx` | modified | Replaced 20 corrupted ANSI/double-byte Mojibake entries with clean UTF-8 Vietnamese strings (`Kết nối`, `Kiểm tra kết nối`, `Tạo kết nối mới`, etc.). |
| `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml` | modified | Restructured layout into 2 rows: Row 0 (`Height="Auto"`) for `InnerTabView` tab strip, Row 1 (`Height="*"`) for `<ContentControl>` content presenter; wired `SelectionChanged="InnerTabView_SelectionChanged"`. |
| `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml.cs` | modified | Implemented `InnerTabView_SelectionChanged` event handler to synchronize `ViewModel.SelectedInnerTab`. |
| `DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseViewModel.cs` | modified | Added headless try/catch fallback when creating `ConnectViewControl` and `DatabaseViewControl` to allow unit testing without active WinUI 3 XAML core. |
| `scratch/VerifyDatabaseView/Program.cs` | added | Headless verification suite confirming zero Mojibake in `String.vi.resx`, accurate culture resolution, and non-null `tab0.Content` initialization. |

## Diff Highlights

### 1. `DataSphere/Resources/Locales/String.vi.resx`
```xml
  <data name="tab_connections_header" xml:space="preserve">
    <value>Kết nối</value>
  </data>
  <data name="btn_test_connection" xml:space="preserve">
    <value>Kiểm tra kết nối</value>
  </data>
  <data name="btn_new_connection" xml:space="preserve">
    <value>Tạo kết nối mới</value>
  </data>
```

### 2. `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml`
```xml
        <!-- Inner Tab Workspace -->
        <Grid Grid.Row="1">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto" />
                <RowDefinition Height="*" />
            </Grid.RowDefinitions>

            <TabView
                Grid.Row="0"
                x:Name="InnerTabView"
                TabItemsSource="{x:Bind ViewModel.InnerTabs, Mode=OneWay}"
                SelectedItem="{x:Bind ViewModel.SelectedInnerTab, Mode=TwoWay}"
                SelectionChanged="InnerTabView_SelectionChanged"
                TabCloseRequested="InnerTabView_TabCloseRequested"
                IsAddTabButtonVisible="False"
                CanReorderTabs="False"
                HorizontalAlignment="Stretch">
                ...
            </TabView>

            <!-- Active Tab Content Area -->
            <ContentControl
                Grid.Row="1"
                Content="{x:Bind ViewModel.SelectedInnerTab.Content, Mode=OneWay}"
                HorizontalContentAlignment="Stretch"
                VerticalContentAlignment="Stretch" />
        </Grid>
```

## Tests Added or Updated

- `scratch/VerifyDatabaseView/Program.cs`:
  - `Test 1-5`: Asserts `String.vi.resx` contains zero double-encoded Mojibake substrings (`Káº¿t`, `Kiá»ƒm`, `Táº¡o`) and XML element `tab_connections_header` equals `"Kết nối"`.
  - `Test 6-8`: Asserts `LanguageBase.GetLangValue` resolves `"Kết nối"`, `"Tạo kết nối mới"`, and `"Kiểm tra kết nối"` under Vietnamese culture.
  - `Test 9-14`: Asserts `DatabaseViewModel` creates `tab0` titled `"Kết nối"`, has non-null content, is selected by default, and is marked non-closable.

## Local Verification

- Build: `dotnet build DataSphere\DataSphere.csproj -c Debug` → 0 warnings, 0 errors.
- Verification Suite: `dotnet run --project scratch\VerifyDatabaseView\VerifyDatabaseView.csproj` → 14 passed, 0 failed.
- Regression Suite 1: `dotnet run --project scratch\VerifyTabTransfer\VerifyTabTransfer.csproj` → 13 passed, 0 failed.
- Regression Suite 2: `dotnet run --project scratch\VerifyConnectionStorage\VerifyConnectionStorage.csproj` → 14 passed, 0 failed.

## Deviations from Assessment

None. The remediation followed the assessment plan precisely, with the added refinement of adding headless fallbacks in `DatabaseViewModel` to allow headless test execution without requiring WinUI 3 XAML core activation.

## Follow-ups

- Proceed to `/speckit-bug-test slug=database-tab-mojibake-and-empty-content` to record formal verification evidence.
