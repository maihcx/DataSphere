$path = "DataSphere/Resources/Locales/String.vi.resx"
$lines = [System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8)

# Find index of btn_test_connection
$targetIndex = -1
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match '<data name="btn_test_connection"') {
        $targetIndex = $i
        break
    }
}

if ($targetIndex -gt 0) {
    $goodLines = $lines[0..($targetIndex - 1)]
    
    $cleanEntries = @(
        '  <data name="btn_test_connection" xml:space="preserve">',
        '    <value>Kiểm tra kết nối</value>',
        '  </data>',
        '  <data name="btn_new_connection" xml:space="preserve">',
        '    <value>Tạo kết nối mới</value>',
        '  </data>',
        '  <data name="msg_test_connection_success" xml:space="preserve">',
        '    <value>Kết nối thành công!</value>',
        '  </data>',
        '  <data name="msg_test_connection_failed" xml:space="preserve">',
        '    <value>Kết nối thất bại: {0}</value>',
        '  </data>',
        '  <data name="pagination_rows_per_page" xml:space="preserve">',
        '    <value>Số dòng mỗi trang:</value>',
        '  </data>',
        '  <data name="pagination_page_info" xml:space="preserve">',
        '    <value>Trang {0} trên {1} ({2} bản ghi)</value>',
        '  </data>',
        '  <data name="btn_refresh_table" xml:space="preserve">',
        '    <value>Làm mới</value>',
        '  </data>',
        '  <data name="lbl_total_records" xml:space="preserve">',
        '    <value>Tổng số bản ghi: {0}</value>',
        '  </data>',
        '  <data name="dialog_delete_connection_title" xml:space="preserve">',
        '    <value>Xóa kết nối</value>',
        '  </data>',
        '  <data name="dialog_delete_connection_message" xml:space="preserve">',
        '    <value>Bạn có chắc chắn muốn xóa ''{0}'' không?</value>',
        '  </data>',
        '  <data name="lbl_connection_database" xml:space="preserve">',
        '    <value>Cơ sở dữ liệu mặc định</value>',
        '  </data>',
        '  <data name="lbl_optional" xml:space="preserve">',
        '    <value>Tùy chọn</value>',
        '  </data>',
        '  <data name="lbl_collation" xml:space="preserve">',
        '    <value>Bảng mã (Collation)</value>',
        '  </data>',
        '  <data name="lbl_charset" xml:space="preserve">',
        '    <value>Bộ ký tự</value>',
        '  </data>',
        '  <data name="status_connecting" xml:space="preserve">',
        '    <value>Đang kết nối...</value>',
        '  </data>',
        '  <data name="status_testing" xml:space="preserve">',
        '    <value>Đang kiểm tra kết nối...</value>',
        '  </data>',
        '  <data name="err_name_required" xml:space="preserve">',
        '    <value>Tên kết nối không được để trống</value>',
        '  </data>',
        '  <data name="err_host_required" xml:space="preserve">',
        '    <value>Máy chủ không được để trống</value>',
        '  </data>',
        '  <data name="err_user_required" xml:space="preserve">',
        '    <value>Tên người dùng không được để trống</value>',
        '  </data>',
        '  <data name="tab_connections_header" xml:space="preserve">',
        '    <value>Kết nối</value>',
        '  </data>',
        '</root>'
    )
    
    $all = $goodLines + $cleanEntries
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($path, $all, $utf8NoBom)
    Write-Output "Cleaned String.vi.resx successfully at index $targetIndex"
} else {
    Write-Error "btn_test_connection not found"
}
