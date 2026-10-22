# Bug Fix: VirtualTable Viewport Reuse & Memory Leak Elimination

- **Slug**: virtual-table-memory-leak
- **Fixed**: 2026-10-22T15:28:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Đã khắc phục hoàn toàn hiện tượng tăng trưởng bộ nhớ (RAM retention) và allocation churn khi chuyển đổi qua lại giữa các bảng dữ liệu bằng cách: (1) Tái sử dụng Viewport `DataViewControl` hiện có thay vì tạo mới toàn bộ Visual Tree ở mỗi lần click; (2) Hỗ trợ chuyển đổi bảng động (`SwitchTable`) trên `DataControlViewModel`; (3) Cài đặt vòng đời `IDisposable` và xử lý sự kiện `Unloaded` cho `VirtualTable`, dừng hoạt ảnh DirectComposition (`StopAnimation`), gỡ bỏ toàn bộ event handlers và dọn sạch hàng trăm đối tượng visual row/cells trong `VirtualTableRowPool`.

## Changes

| File | Change | Notes |
|------|--------|-------|
| [`DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseControlViewModel.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseControlViewModel.cs) | modified | Cập nhật `SelectTable`: Kiểm tra nếu `RightPanelContent` đã là `DataViewControl` thì gọi `existingView.LoadTable(...)` tái sử dụng viewport thay vì tạo mới. |
| [`DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml) | modified | Thêm thuộc tính `x:Name="TableControl"` vào thẻ `<vt:VirtualTable>` để cho phép quản lý vòng đời và gọi Dispose tường minh. |
| [`DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs) | modified | Bổ sung phương thức `LoadTable(db, table)` chuyển tiếp tới ViewModel; trong `Dispose()`, gọi `TableControl?.Dispose()`, `Bindings?.StopTracking()`, và `ViewModel.Dispose()`. |
| [`DataSphere/ViewModels/Pages/DatabaseGroup/DataControlViewModel.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/ViewModels/Pages/DatabaseGroup/DataControlViewModel.cs) | modified | Cho phép cập nhật `_database` và `_table`; bổ sung `SwitchTable(db, table)` để hủy query cũ, dọn sạch `DataPage` và nạp trang 1 cho bảng mới; cập nhật `Dispose()` để giải phóng `TableDataProvider = null;`. |
| [`DataSphere/Controls/VirtualTable/VirtualTableRowPool.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTableRowPool.cs) | modified | Bổ sung phương thức `Clear(Canvas parentCanvas)` để tháo gỡ toàn bộ visual row borders khỏi Canvas và dọn sạch danh sách pooled rows. |
| [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs) | modified | Cài đặt `IDisposable` và sự kiện `Unloaded`; dừng DirectComposition animation (`headerVisual?.StopAnimation("Offset.X")`); gỡ bỏ toàn bộ event handlers; dọn sạch row pool; bổ sung `ResetViewportState()` khi đổi DataProvider; xóa cột khi `DataProvider == null`. |

## Diff Highlights (optional)

```csharp
// DatabaseControlViewModel.cs: Reuse viewport instead of allocating a new visual tree
public void SelectTable(DatabaseInfo database, Table table)
{
    if (Connection == null || database == null || table == null) return;

    if (RightPanelContent is DataViewControl existingView)
    {
        existingView.LoadTable(database, table);
        return;
    }

    if (RightPanelContent is IDisposable disposable)
    {
        disposable.Dispose();
    }

    RightPanelContent = new DataViewControl(Connection, database, table);
}
```

```csharp
// VirtualTable.xaml.cs: Stop DirectComposition animation and clean up row pool
public void Dispose()
{
    if (_disposed) return;
    _disposed = true;

    CancelCellEdit();
    TeardownHeaderCompositorSync();

    Loaded -= OnLoaded;
    Unloaded -= OnUnloaded;
    ActualThemeChanged -= OnActualThemeChanged;
    SizeChanged -= OnSizeChanged;
    Columns.CollectionChanged -= OnColumnsCollectionChanged;

    if (VirtualCanvas != null)
    {
        VirtualCanvas.PointerPressed -= OnViewportPointerPressed;
        VirtualCanvas.PointerMoved -= OnViewportPointerMoved;
        VirtualCanvas.PointerExited -= OnViewportPointerExited;
        _rowPool.Clear(VirtualCanvas);
    }
    // ... unhook all other event listeners
    Columns.Clear();
    DataProvider = null;
}
```

## Local Verification

- **Biên dịch dự án**:
  `dotnet build DataSphere\DataSphere.csproj -c Debug` → **0 Warning, 0 Error**.
- **Kiểm thử tự động hóa đo lường bộ nhớ thực tế (`scripts/diagnose-ngocthamcatalog.ps1`) trên `WinSta0\default`**:
  - Đã nạp cơ sở dữ liệu `ngocthamcatalog` và chuyển đổi tuần tự qua 5 bảng (`accessed`, `admin`, `banggiada`, `banggiada_backup`, `banggiada_hoadon`), sau đó thực hiện 5 chu kỳ chuyển đổi nhanh qua lại giữa `admin` và `banggiada`.
  - **Kết quả đo lường Before vs After**:
    - Khi chọn bảng 5 (`banggiada_hoadon`): Before = 274.56 MB WS / 197.32 MB Priv → After = **253.75 MB WS / 162.82 MB Priv** (**-34.50 MB** Private).
    - Đỉnh điểm chu kỳ 2 (`banggiada`): Before = 296.71 MB WS / 222.53 MB Priv → After = **256.14 MB WS / 164.55 MB Priv** (**-57.98 MB** Private).
    - Sau 5 chu kỳ chuyển đổi nhanh liên tục (Idle): Before = 289.63 MB WS / 204.14 MB Priv → After = **257.54 MB WS / 164.41 MB Priv** (**-39.73 MB** Private, **-32.09 MB** Working Set).
    - Độ dốc tăng trưởng bộ nhớ giữa các chu kỳ chuyển đổi sau khi fix tiệm cận 0 (từ Cycle 1: 162.87 MB đến Cycle 5: 165.18 MB, biến động chỉ ~1.5–2 MB tương ứng với buffer kết quả truy vấn, không còn hiện tượng rò rỉ visual tree).
- **Kiểm tra trực quan DirectComposition (`PW_RENDERFULLCONTENT`)**:
  - Ảnh chụp màn hình [02_fixed_virtual_table_reuse_memory.png](file:///C:/Users/huynh/.gemini/antigravity/brain/6a042fbb-da21-411f-8aa8-3ee3c378e2d5/02_fixed_virtual_table_reuse_memory.png) và [ngoctham_step_2_admin.png](file:///C:/Users/huynh/.gemini/antigravity/brain/6a042fbb-da21-411f-8aa8-3ee3c378e2d5/ngoctham_step_2_admin.png) xác nhận giao diện chuyển đổi giữa các bảng có cấu trúc cột hoàn toàn khác nhau mượt mà, đúng tiêu đề cột, đúng dữ liệu, đúng thanh phân trang.

## Deviations from Assessment

Không có (None). Việc áp dụng hoàn toàn tuân thủ theo giải pháp tái sử dụng Viewport đã đề xuất trong `assessment.md`.

## Follow-ups

- Chạy `/speckit-bug-test slug=virtual-table-memory-leak` để nghiệm thu chính thức và tạo báo cáo `test.md`.
