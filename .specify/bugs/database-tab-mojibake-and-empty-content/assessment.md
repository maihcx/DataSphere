# Bug Assessment: Database Tab Mojibake Title and Empty Inner Content Viewport

- **Slug**: database-tab-mojibake-and-empty-content
- **Created**: 2026-10-20T10:13:00+07:00
- **Source**: pasted text and user screenshot `media_1792465743353_f981120c.png`
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> "xem hình 1, cái title của tab có text trông kì quặc và nội dung thì không có gì để hiển thị"
>
> *(Referencing screenshot showing the Database page: The inner tab header displays corrupted text `Kế°t ná»'i`, and the entire viewport underneath is blank white space with no toolbar, buttons, or connection controls visible).*

## Symptom

1. **Inner Tab Header Mojibake**:
   - The first tab header in the Database management workspace displays `Kế°t ná»'i` instead of the proper Vietnamese string `"Kết nối"`.
   - Inspection of `String.vi.resx` reveals that 20 recently added connection management resource entries (lines 354–413) were corrupted by double-byte ANSI/UTF-8 Mojibake encoding during automated appending.
2. **Completely Empty Viewport (Content Not Rendered)**:
   - When viewing the Database tab, the content area below the inner tab strip is 100% blank.
   - The connection management controls—including the toolbar with "Tạo kết nối mới" (`New Connection`), "Thư mục" (`Folder`), and the empty state card ("Chưa có kết nối nào...")—are completely missing from the rendered view.

## Reproduction

1. Launch DataSphere.
2. Click on the **Cơ sở dữ liệu** (Database) card on `HomePage` or click its tab in the top tab strip.
3. Observe the Database page layout:
   - **Observed 1**: The inner tab displays corrupted text `Kế°t ná»'i`.
   - **Observed 2**: The main area below the tab strip is an empty white void; no toolbar, no buttons, and no empty state card are visible.
   - **Expected 1**: The inner tab displays the clean Vietnamese label `"Kết nối"`.
   - **Expected 2**: The viewport below renders `ConnectViewControl` hosting the connection command toolbar and the empty state card ("Danh sách kết nối: Chưa có kết nối nào. Hãy tạo kết nối mới...").

## Suspected Code Paths

1. `DataSphere/Resources/Locales/String.vi.resx:354-413`:
   - Keys `btn_test_connection`, `btn_new_connection`, `msg_test_connection_success`, ..., and `tab_connections_header` contain Mojibake characters:
     - `<value>Káº¿t ná»‘i</value>` instead of `<value>Kết nối</value>`
     - `<value>Kiá»ƒm tra káº¿t ná»‘i</value>` instead of `<value>Kiểm tra kết nối</value>`
     - `<value>Táº¡o káº¿t ná»‘i má»›i</value>` instead of `<value>Tạo kết nối mới</value>`
2. `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml:34-62`:
   - In `DatabasePage.xaml`, `<ContentControl>` was placed directly *inside* `<TabView>`:
     ```xml
     <Grid Grid.Row="1">
         <TabView x:Name="InnerTabView" TabItemsSource="{x:Bind ViewModel.InnerTabs, Mode=OneWay}" ...>
             <TabView.TabItemTemplate>...</TabView.TabItemTemplate>
             <!-- Active Tab Content Area -->
             <ContentControl Content="{x:Bind ViewModel.SelectedInnerTab.Content, Mode=OneWay}" ... />
         </TabView>
     </Grid>
     ```
   - In WinUI 3, `TabView` is an `ItemsControl` where unparented direct children are added to `TabView.TabItems`. Because `TabItemsSource` was bound, items in `TabItems` are ignored/hidden.
   - Concurrently, `TabViewItem` in `TabItemTemplate` does not set `Content="{x:Bind Content, Mode=OneWay}"`.
   - As a result, the `<ContentControl>` was orphaned inside `TabItems` and never attached to the visual tree, leaving the viewport completely empty.
3. `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml.cs:27-34`:
   - `DatabasePage` lacks `SelectionChanged` handler on `InnerTabView` to keep `ViewModel.SelectedInnerTab` synchronized when tabs change.

## Root Cause Hypothesis

- **Root Cause 1 (Mojibake Encoding)**:
  An update script appended localization entries into `String.vi.resx` without forcing UTF-8 file encoding for string literals in Windows PowerShell. The string `Kết nối` was encoded to UTF-8 bytes (`0x4B 0xE1 0xBA 0xBF 0x74 0x20 0x6E 0xE1 0xBB 0x91 0x69`) and mistakenly re-interpreted as Windows-1252/ANSI text (`Káº¿t ná»‘i`), rendering on screen as `Kế°t ná»'i`. All 20 entries appended to `String.vi.resx` suffered from the same corruption.
- **Root Cause 2 (Misplaced ContentControl inside TabView)**:
  In `DatabasePage.xaml`, `<ContentControl>` was mistakenly declared as an inner element of `<TabView>`. In WinUI 3, `TabView` does not support placing layout content directly inside its body; doing so routes the element into `TabView.TabItems`. Because `TabItemsSource` is populated, `TabItems` is not rendered. By contrast, the application shell [`ShellWindow.xaml`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Windows/ShellWindow.xaml#L22-L64) correctly separates the `TabView` header (Row 0) and the `ContentPresenter` viewport (Row 1). Because `DatabasePage.xaml` did not follow this pattern, `ConnectViewControl` was never displayed.

Confidence: High (100% verified against XAML visual tree hierarchy and resource file analysis).

## Proposed Remediation

**Preferred**:

1. **Fix `DataSphere/Resources/Locales/String.vi.resx`**:
   - Replace all 20 corrupted resource entries (lines 354–413) with proper UTF-8 Vietnamese strings:
     - `tab_connections_header`: `Kết nối`
     - `btn_test_connection`: `Kiểm tra kết nối`
     - `btn_new_connection`: `Tạo kết nối mới`
     - `msg_test_connection_success`: `Kết nối thành công!`
     - `msg_test_connection_failed`: `Kết nối thất bại: {0}`
     - `pagination_rows_per_page`: `Số dòng mỗi trang:`
     - `pagination_page_info`: `Trang {0} trên {1} ({2} bản ghi)`
     - `btn_refresh_table`: `Làm mới`
     - `lbl_total_records`: `Tổng số bản ghi: {0}`
     - `dialog_delete_connection_title`: `Xóa kết nối`
     - `dialog_delete_connection_message`: `Bạn có chắc chắn muốn xóa '{0}' không?`
     - `lbl_connection_database`: `Cơ sở dữ liệu mặc định`
     - `lbl_optional`: `Tùy chọn`
     - `lbl_collation`: `Bảng mã (Collation)`
     - `lbl_charset`: `Bộ ký tự`
     - `status_connecting`: `Đang kết nối...`
     - `status_testing`: `Đang kiểm tra kết nối...`
     - `err_name_required`: `Tên kết nối không được để trống`
     - `err_host_required`: `Máy chủ không được để trống`
     - `err_user_required`: `Tên người dùng không được để trống`

2. **Fix `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml`**:
   - Structure `Grid.Row="1"` with two dedicated rows:
     - `RowDefinition Height="Auto"` for `InnerTabView`.
     - `RowDefinition Height="*"` for `ContentControl`.
   - Move `<ContentControl>` outside `<TabView>` and assign it to `Grid.Row="1"`.
   - Wire `SelectionChanged="InnerTabView_SelectionChanged"` on `InnerTabView`.

3. **Update `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml.cs`**:
   - Add the `InnerTabView_SelectionChanged` event handler:
     ```csharp
     private void InnerTabView_SelectionChanged(object sender, SelectionChangedEventArgs e)
     {
         if (InnerTabView.SelectedItem is InnerTabItemModel selected && !Equals(ViewModel.SelectedInnerTab, selected))
         {
             ViewModel.SelectedInnerTab = selected;
         }
     }
     ```

**Files likely to change**:
- `DataSphere/Resources/Locales/String.vi.resx`
- `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml`
- `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml.cs`

**Tests to add or update**:
- Headless verification script testing:
  - `LanguageBase.GetLangValue("tab_connections_header")` returns `"Kết nối"`.
  - `String.vi.resx` contains zero double-encoded Mojibake characters.
  - `DatabaseViewModel` creates `tab0` with non-null `Content` (`ConnectViewControl`).

## Risks & Considerations

- **Resource File Encoding**: Must ensure `String.vi.resx` is saved as clean UTF-8 without BOM or double-encoded characters.
- **Layout Expansion**: Ensure `<ContentControl>` in `Grid.Row="1"` has `HorizontalContentAlignment="Stretch"` and `VerticalContentAlignment="Stretch"` so `ConnectViewControl` and `DatabaseViewControl` properly fill the window width and height.

## Open Questions

- None. Both bugs are pinpointed directly in code and resource files.
