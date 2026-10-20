$ErrorActionPreference = "Stop"

$newEntries = @"
  <data name="btn_test_connection" xml:space="preserve">
    <value>Test Connection</value>
  </data>
  <data name="btn_new_connection" xml:space="preserve">
    <value>New Connection</value>
  </data>
  <data name="msg_test_connection_success" xml:space="preserve">
    <value>Connection successful!</value>
  </data>
  <data name="msg_test_connection_failed" xml:space="preserve">
    <value>Connection failed: {0}</value>
  </data>
  <data name="pagination_rows_per_page" xml:space="preserve">
    <value>Rows per page:</value>
  </data>
  <data name="pagination_page_info" xml:space="preserve">
    <value>Page {0} of {1} ({2} records)</value>
  </data>
  <data name="btn_refresh_table" xml:space="preserve">
    <value>Refresh</value>
  </data>
  <data name="lbl_total_records" xml:space="preserve">
    <value>Total records: {0}</value>
  </data>
  <data name="dialog_delete_connection_title" xml:space="preserve">
    <value>Delete Connection</value>
  </data>
  <data name="dialog_delete_connection_message" xml:space="preserve">
    <value>Are you sure you want to delete '{0}'?</value>
  </data>
  <data name="lbl_connection_database" xml:space="preserve">
    <value>Default Database</value>
  </data>
  <data name="lbl_optional" xml:space="preserve">
    <value>Optional</value>
  </data>
  <data name="lbl_collation" xml:space="preserve">
    <value>Collation</value>
  </data>
  <data name="lbl_charset" xml:space="preserve">
    <value>Character Set</value>
  </data>
  <data name="status_connecting" xml:space="preserve">
    <value>Connecting...</value>
  </data>
  <data name="status_testing" xml:space="preserve">
    <value>Testing connection...</value>
  </data>
  <data name="err_name_required" xml:space="preserve">
    <value>Connection name is required</value>
  </data>
  <data name="err_host_required" xml:space="preserve">
    <value>Host is required</value>
  </data>
  <data name="err_user_required" xml:space="preserve">
    <value>Username is required</value>
  </data>
  <data name="tab_connections_header" xml:space="preserve">
    <value>Connections</value>
  </data>
</root>
"@

$newEntriesVi = @"
  <data name="btn_test_connection" xml:space="preserve">
    <value>Kiểm tra kết nối</value>
  </data>
  <data name="btn_new_connection" xml:space="preserve">
    <value>Tạo kết nối mới</value>
  </data>
  <data name="msg_test_connection_success" xml:space="preserve">
    <value>Kết nối thành công!</value>
  </data>
  <data name="msg_test_connection_failed" xml:space="preserve">
    <value>Kết nối thất bại: {0}</value>
  </data>
  <data name="pagination_rows_per_page" xml:space="preserve">
    <value>Số dòng mỗi trang:</value>
  </data>
  <data name="pagination_page_info" xml:space="preserve">
    <value>Trang {0} trên {1} ({2} bản ghi)</value>
  </data>
  <data name="btn_refresh_table" xml:space="preserve">
    <value>Làm mới</value>
  </data>
  <data name="lbl_total_records" xml:space="preserve">
    <value>Tổng số bản ghi: {0}</value>
  </data>
  <data name="dialog_delete_connection_title" xml:space="preserve">
    <value>Xóa kết nối</value>
  </data>
  <data name="dialog_delete_connection_message" xml:space="preserve">
    <value>Bạn có chắc chắn muốn xóa '{0}' không?</value>
  </data>
  <data name="lbl_connection_database" xml:space="preserve">
    <value>Cơ sở dữ liệu mặc định</value>
  </data>
  <data name="lbl_optional" xml:space="preserve">
    <value>Tùy chọn</value>
  </data>
  <data name="lbl_collation" xml:space="preserve">
    <value>Bảng mã (Collation)</value>
  </data>
  <data name="lbl_charset" xml:space="preserve">
    <value>Bộ ký tự</value>
  </data>
  <data name="status_connecting" xml:space="preserve">
    <value>Đang kết nối...</value>
  </data>
  <data name="status_testing" xml:space="preserve">
    <value>Đang kiểm tra kết nối...</value>
  </data>
  <data name="err_name_required" xml:space="preserve">
    <value>Tên kết nối không được để trống</value>
  </data>
  <data name="err_host_required" xml:space="preserve">
    <value>Máy chủ không được để trống</value>
  </data>
  <data name="err_user_required" xml:space="preserve">
    <value>Tên người dùng không được để trống</value>
  </data>
  <data name="tab_connections_header" xml:space="preserve">
    <value>Kết nối</value>
  </data>
</root>
"@

$path = "DataSphere/Resources/Locales/String.resx"
$content = [System.IO.File]::ReadAllText($path)
if ($content -notmatch "btn_test_connection") {
    $updated = $content.TrimEnd().Replace("</root>", $newEntries)
    [System.IO.File]::WriteAllText($path, $updated, [System.Text.Encoding]::UTF8)
}

$pathEn = "DataSphere/Resources/Locales/String.en.resx"
$contentEn = [System.IO.File]::ReadAllText($pathEn)
if ($contentEn -notmatch "btn_test_connection") {
    $updatedEn = $contentEn.TrimEnd().Replace("</root>", $newEntries)
    [System.IO.File]::WriteAllText($pathEn, $updatedEn, [System.Text.Encoding]::UTF8)
}

$pathVi = "DataSphere/Resources/Locales/String.vi.resx"
$contentVi = [System.IO.File]::ReadAllText($pathVi)
if ($contentVi -notmatch "btn_test_connection") {
    $updatedVi = $contentVi.TrimEnd().Replace("</root>", $newEntriesVi)
    [System.IO.File]::WriteAllText($pathVi, $updatedVi, [System.Text.Encoding]::UTF8)
}

Write-Output "SUCCESS"
