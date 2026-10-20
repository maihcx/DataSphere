# Bug Assessment: Table Data Viewport Overlay Blocking, Non-Interactive Rows/Cells & Inappropriate Schema Tree Glyphs

- **Slug**: table-data-overlay-and-tree-icons
- **Created**: 2026-10-20T13:28:00+07:00
- **Source**: pasted text & diagnostic screenshot (`media_1792477227654_9b07b32f.png`)
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

The user submitted a diagnostic report with an attached screenshot of the active database connection workspace (`localhost`):

> `"chọn 1 bảng trong danh sách để xem dữ liệu" cái này luôn luôn hiển thị dù tôi đã chọn bảng rồi, và các dữ liệu ở trong cũng không tương tác được (không thể nhấn chuột vào bất kì cell nào hay hàng nào)`
> `tree menu database bên cạnh có icon không phù hợp`

Diagnostic Screenshot Evidence:
![Diagnostic Evidence](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/bug_diagnostic_evidence.png)

## Symptom

1. **Persistent Empty State Placeholder Overlay**: Even after clicking and selecting a table (e.g. `chatrooms`), the empty selection placeholder ("Chọn một bảng trong danh sách để xem dữ liệu" with icon `\uE82D`) remains permanently visible in the center of the right viewport, directly overlaid on top of the rendered table data rows and columns.
2. **Non-Interactive Table Data**: Users are unable to interact with any row or cell in the table viewport:
   - Clicks in the central area are intercepted by the overlaid placeholder `StackPanel`.
   - The underlying `ListView` in `DataViewControl.xaml` is configured with `SelectionMode="None"`, disabling row selection, focus, and hover feedback.
   - Table cell values are rendered inside plain `TextBlock` elements with `IsTextSelectionEnabled="False"`, preventing users from clicking, highlighting, or copying text from any cell.
3. **Inappropriate Schema Explorer Icons**:
   - Database schema nodes (`chat`, `download_service`, `file3dluutru`) use `\uE8B9` (Picture / Photo profile badge) instead of a storage/database icon.
   - Tables category folder ("Các bảng") and table nodes (`chatrooms`, `admin`) use `\uE82D` (Dictionary / Book / Smartphone) instead of folder and grid table icons.
   - Views category ("Trình bày") uses `\uE8B9` (Picture) instead of an eye/view icon.
   - Functions category ("Các hàm") uses `\uE8B7` (Folder) instead of a math/function icon (`\uF168`).
   - The toolbar and empty placeholder icons use `\uE82D` (Dictionary).

## Reproduction

1. Launch `DataSphere.exe` on desktop (`WinSta0\default`).
2. Open or navigate to an active database server connection (e.g. `localhost`).
3. Expand a database schema (e.g. `chat`) and its `Các bảng` (Tables) folder.
   - *Observe*: Database schemas display a photo/person badge icon (`\uE8B9`). Tables display a dictionary/phone icon (`\uE82D`).
4. Click on a table (e.g. `chatrooms`).
   - *Observe*: Table columns and rows load in the background, but the centered placeholder "Chọn một bảng trong danh sách để xem dữ liệu" remains visible on top of the data.
5. Attempt to click on any row, cell, or copy text in the data viewport:
   - *Observe*: Nothing can be clicked, selected, highlighted, or copied.

## Suspected Code Paths

- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml:91-103`:
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
  `InverseBooleanToVisibilityConverter` receives an `object?` (`RightPanelContent`), not a `bool`. When `RightPanelContent` is a `DataViewControl`, `value is bool b && b` evaluates to `false`, causing the converter to always return `Visibility.Visible`. Furthermore, the `StackPanel` lacks `IsHitTestVisible="False"`, blocking mouse hit tests across its bounds.

- `DataSphere/Helpers/Converters.cs:57-74`:
  ```csharp
  public class InverseBooleanToVisibilityConverter : IValueConverter
  {
      public object Convert(object value, Type targetType, object parameter, string language)
      {
          if (value is bool b && b)
          {
              return Visibility.Collapsed;
          }
          return Visibility.Visible;
      }
      ...
  }
  ```
  Lacks a converter for object nullability (e.g. `NullToVisibilityConverter`).

- `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml:90-112`:
  ```xml
  <!-- Data Rows List -->
  <ListView
      ItemsSource="{x:Bind ViewModel.DataPage.Rows, Mode=OneWay}"
      SelectionMode="None"
      Padding="0,4">
      <ListView.ItemTemplate>
          <DataTemplate x:DataType="models:TableRowData">
              <ItemsControl ItemsSource="{x:Bind Cells}">
                  ...
                  <ItemsControl.ItemTemplate>
                      <DataTemplate x:DataType="x:String">
                          <Border Width="140" Padding="8,6" BorderBrush="{ThemeResource CardStrokeColorDefaultBrush}" BorderThickness="0,0,0,1">
                              <TextBlock Text="{x:Bind}" TextTrimming="CharacterEllipsis" />
                          </Border>
                      </DataTemplate>
                  </ItemsControl.ItemTemplate>
  ```
  `SelectionMode="None"` disables row selection and item interaction. `TextBlock` without `IsTextSelectionEnabled="True"` prevents text selection and copying.

- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs:42-56, 172-196`:
  ```csharp
  var dbNode = CreateNode(db.Name, "\uE8B9", db); // Picture icon for Database
  ...
  var tablesCatNode = CreateNode(LanguageBase.GetLangValue("dbinf_tables_title"), "\uE82D", db); // Dictionary icon for Tables folder
  var tableNode = CreateNode(table.Name, "\uE82D", new TableNodeContext(db, table)); // Dictionary icon for Table
  args.Node.Children.Add(CreateNode(LanguageBase.GetLangValue("dbinf_views_title"), "\uE8B9", db)); // Picture icon for Views
  args.Node.Children.Add(CreateNode(LanguageBase.GetLangValue("dbinf_sps_title"), "\uE943", db)); // Code icon for SPs
  args.Node.Children.Add(CreateNode(LanguageBase.GetLangValue("dbinf_fncs_title"), "\uE8B7", db)); // Folder icon for Functions
  ```
  Incorrect icon glyphs mapped to schema explorer nodes.

- `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml:33` & `DatabaseViewControl.xaml:97`:
  Using `&#xE82D;` (Dictionary) instead of `&#xF0E2;` (GridView / Data Table).

## Root Cause Hypothesis

The bug is caused by three compounding defects:
1. **Type Mismatch in Converter**: `DatabaseViewControl.xaml` binds the `Visibility` of the placeholder `StackPanel` to `ViewModel.RightPanelContent` using `InverseBooleanToVisibilityConverter`. Because `RightPanelContent` is a `DataViewControl` (or `null`) rather than a `System.Boolean`, `value is bool b && b` in the converter is never satisfied, causing the converter to permanently output `Visibility.Visible`.
2. **Missing Interactivity in Data Viewport**: Even beneath the overlay, `DataViewControl.xaml` explicitly disables interaction by setting `SelectionMode="None"` on the `ListView` and rendering cell text in `TextBlock`s without `IsTextSelectionEnabled="True"`.
3. **Mismatched Segoe Fluent Icon Glyphs**: In `DatabaseViewControl.xaml.cs`, inappropriate glyph codes were assigned to schema tree nodes (`\uE8B9` Picture for databases and views, `\uE82D` Dictionary for tables, `\uE8B7` Folder for functions) instead of standard database management glyphs (`\uEDA2` Storage/HardDrive, `\uF0E2` GridView, `\uE890` View/Eye, `\uF168` Math/Function).

**Confidence**: High (100% verified via code inspection, XAML binding semantics, and diagnostic screenshot).

## Proposed Remediation

**Preferred Fix**:
1. **Add `NullToVisibilityConverter`** in `DataSphere/Helpers/Converters.cs`:
   - Returns `Visibility.Visible` when `value == null`.
   - Returns `Visibility.Collapsed` when `value != null`.
   - Register in `DataSphere/App.xaml`.
   - Update `DatabaseViewControl.xaml` to use `Converter={StaticResource NullToVisibilityConverter}` for the empty placeholder `StackPanel`.
2. **Enable Data Interactivity in `DataViewControl.xaml`**:
   - Change `ListView` `SelectionMode` from `None` to `Single`.
   - Set `IsTextSelectionEnabled="True"` on cell `TextBlock`s so users can highlight and copy cell values.
   - Add hover/selection styling to ensure rows highlight cleanly when clicked.
3. **Correct Tree View & Viewport Icon Glyphs**:
   - Database schema node: change `\uE8B9` to `\uEDA2` (HardDrive / Storage Disk).
   - Tables category folder ("Các bảng"): change `\uE82D` to `\uE8B7` (Folder).
   - Table node (`table.Name`): change `\uE82D` to `\uF0E2` (GridView / Data Table).
   - Views category ("Trình bày"): change `\uE8B9` to `\uE890` (View / Eye).
   - Functions category ("Các hàm"): change `\uE8B7` to `\uF168` (Function fx / Math).
   - Update `DataViewControl.xaml:33` and `DatabaseViewControl.xaml:97` icons to `&#xF0E2;` (GridView / Data Table).

**Files likely to change**:
- `DataSphere/Helpers/Converters.cs`
- `DataSphere/App.xaml`
- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml`
- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs`
- `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml`

**Tests to add or update**:
- Unit test for `NullToVisibilityConverter` verifying `Convert(null)` returns `Visibility.Visible` and `Convert(object)` returns `Visibility.Collapsed`.
- UI Automation verification via real desktop script confirming table selection hides the placeholder and row selection highlights.

## Risks & Considerations

- Ensure `NullToVisibilityConverter` handles whitespace strings, null objects, and empty collections gracefully if reused.
- Verify `IsTextSelectionEnabled="True"` in WinUI 3 `ListView` does not prevent row selection clicks.

## Open Questions

None.
