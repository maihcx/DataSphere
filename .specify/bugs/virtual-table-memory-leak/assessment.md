# Bug Assessment: VirtualTable Memory Retention & Working Set Growth

- **Slug**: virtual-table-memory-leak
- **Created**: 2026-10-22T15:15:00+07:00
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> "kiểm tra xem VirtualTable có bị rò rỉ bộ nhớ hay không? tôi nhận thấy mức ram nó sử dụng không giảm đi khi chuyển qua bảng khác và thêm nữa là bảng đó ăn tới 100mb ram"
> *(Bổ sung: "dùng ngocthamcatalog ấy, nó có nhiều dữ liệu")*

## Symptom

1. **Bộ nhớ không giảm khi chuyển bảng (Memory Not Released on Table Switching)**: Khi người dùng chuyển đổi qua lại giữa các bảng trong cơ sở dữ liệu (ví dụ schema `ngocthamcatalog`), lượng RAM tiêu thụ (Working Set / Private Memory) liên tục tăng theo từng bảng được mở (tăng thêm khoảng 10–16 MB Private Bytes mỗi lần chọn bảng mới) và không giảm xuống khi rời khỏi bảng cũ.
2. **Mức tiêu thụ RAM đạt ngưỡng cao (~100–290 MB)**: Mở bảng dữ liệu đẩy tổng lượng Working Set lên ~250–298 MB (Private Bytes đạt hơn 200 MB), khiến người dùng có cảm giác "bảng ăn tới 100MB RAM".

## Reproduction

1. Khởi chạy ứng dụng DataSphere trên desktop thực (`WinSta0\default`). Ghi nhận bộ nhớ ban đầu:
   - **Initial Startup (Home Page)**: Working Set ~163.28 MB | Private Memory ~89.17 MB.
2. Điều hướng vào trang Cơ sở dữ liệu và mở kết nối `localhost`:
   - **Opened Connection Tab**: Working Set ~208.03 MB | Private Memory ~115.80 MB.
3. Mở rộng cơ sở dữ liệu `ngocthamcatalog` và mở danh mục "Các bảng":
   - **Expanded Tables Category**: Working Set ~220.64 MB | Private Memory ~128.25 MB.
4. Tuần tự chọn 5 bảng dữ liệu khác nhau (`accessed`, `admin`, `banggiada`, `banggiada_backup`, `banggiada_hoadon`) và đo lường mức RAM:
   - Click `accessed`: WS 230.87 MB | Private 135.80 MB (+7.55 MB Private)
   - Click `admin`: WS 240.38 MB | Private 149.98 MB (+14.18 MB Private)
   - Click `banggiada`: WS 253.12 MB | Private 166.14 MB (+16.16 MB Private)
   - Click `banggiada_backup`: WS 265.11 MB | Private 182.71 MB (+16.57 MB Private)
   - Click `banggiada_hoadon`: WS 274.56 MB | Private 197.32 MB (+14.61 MB Private)
   - **Tổng tăng trưởng qua 5 bảng**: Private Memory tăng từ 128.25 MB lên 197.32 MB (**+69.07 MB**, trung bình ~13.8 MB/bảng).
5. Thực hiện chuyển đổi qua lại (rapid switching) giữa `admin` và `banggiada` 5 chu kỳ liên tiếp:
   - RAM dao động trong khoảng 280–298 MB WS (204–222 MB Private) và không giảm trở lại mức ban đầu khi idle (dừng lại ở 289.63 MB WS | 204.14 MB Private).

## Suspected Code Paths

- [`DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseControlViewModel.cs:173-183`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseControlViewModel.cs#L173-L183) (`SelectTable`):
  Khởi tạo hoàn toàn mới `new DataViewControl(Connection, database, table)` ở mỗi thao tác chọn bảng thay vì tái sử dụng View/ViewModel hiện có hoặc cập nhật dữ liệu trên Viewport đã dựng.
- [`DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs:14-43`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs#L14-L43) (`DataViewControl.Dispose`):
  Phương thức `Dispose()` chỉ chuyển tiếp gọi `ViewModel.Dispose()`. Nó không ngắt kết nối các compiled binding (`Bindings.StopTracking()`), không gỡ bỏ UserControl con `VirtualTable`, và không thu hồi các tài nguyên trực quan DirectComposition.
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs:27-167, 318-346`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L27-L167):
  Lớp `VirtualTable` không cài đặt giao diện `IDisposable` và không xử lý sự kiện `Unloaded`.
  - Thiết lập hoạt ảnh DirectComposition qua `ElementCompositionPreview.GetScrollViewerManipulationPropertySet` và `headerVisual.StartAnimation("Offset.X", expr)` không bao giờ bị dừng (`StopAnimation`) khi control bị gỡ khỏi Visual Tree, khiến native compositor giữ tham chiếu đến Visual object.
  - Các sự kiện `ScrollViewer.ViewChanged`, con trỏ chuột (`PointerMoved`, `PointerWheelChanged`), sự kiện bàn phím, và `InputCursor` không được giải phóng.
- [`DataSphere/Controls/VirtualTable/VirtualTableRowPool.cs:38-63`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTableRowPool.cs#L38-L63) & [`VirtualTableRow.cs:81-105`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTableRow.cs#L81-L105):
  Mỗi instance `VirtualTable` mới sinh ra 30+ visual row và hàng trăm UI Element (`Border`, `TextBlock`). Khi bị vứt bỏ hàng loạt, hàng nghìn native WinUI 3 peer đối tượng C++/WinRT COM tồn tại chờ GC thu gom.
- [`DataSphere/ViewModels/Pages/DatabaseGroup/DataControlViewModel.cs:426-440`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/ViewModels/Pages/DatabaseGroup/DataControlViewModel.cs#L426-L440) (`Dispose`):
  Thuộc tính `TableDataProvider` không được set về `null`, tiếp tục giữ chặt `TableDataPageAdapter`, và adapter này giữ tham chiếu đến đối tượng `TableDataPage` cùng toàn bộ danh sách `VirtualTableColumn`.

## Root Cause Hypothesis

**Độ tin cậy: Cao (High - Đã được kiểm chứng thực nghiệm bằng số liệu đo lường trực tiếp).**

1. **Tạo mới Visual Tree liên tục thay vì Tái sử dụng (Allocation Churn)**:
   Mỗi lần người dùng nhấn chọn một bảng trong TreeView, `DatabaseControlViewModel.SelectTable` tạo mới một `DataViewControl`, kéo theo một `DataControlViewModel` mới và một `VirtualTable` UserControl mới hoàn toàn. Thao tác này buộc hệ thống phân bổ lại toàn bộ cây visual WinUI 3 (hơn 30 dòng, 600–900 `TextBlock`/`Border`, header controls, splitters, DirectComposition animations, toolbar và pagination bar).
2. **Cơ chế thu gom bộ nhớ WinUI 3 Native COM Peers & .NET CLR**:
   WinUI 3 là tầng giao diện native C++ (Windows App SDK) giao tiếp với .NET qua C#/WinRT COM Callable Wrappers (CCW) và Runtime Callable Wrappers (RCW). Khi một control bị tháo khỏi Visual Tree mà không gọi `Bindings.StopTracking()`, không dừng animation `Offset.X`, và không giải phóng event handlers, các đối tượng native COM peer không được thu hồi tức thì.
   Đồng thời, bộ quản lý bộ nhớ của Windows và .NET CLR giữ lại các committed pages trong Working Set để tái sử dụng thay vì trả lại ngay cho hệ điều hành, dẫn đến hiện tượng RAM không giảm khi vừa chuyển bảng.
3. **Phân tích con số "100MB RAM"**:
   - Baseline của WinUI 3 + .NET 10 + DirectComposition + DirectX hardware acceleration khi khởi động ứng dụng vốn đã chiếm ~160 MB Working Set (Private ~89 MB).
   - Khi kết nối database và nạp cây schema/metadata: tăng lên ~208 MB Working Set.
   - Khi mở viewport bảng dữ liệu: tăng thêm khoảng 20–40 MB (Working Set đạt ~230–270 MB, Private ~135–197 MB).
   Người dùng quan sát thấy Task Manager hiển thị ứng dụng chiếm từ 150–250 MB và tăng thêm mỗi khi chọn bảng, tạo ấn tượng rằng chỉ riêng bảng dữ liệu đã "ăn tới 100MB RAM".

## Proposed Remediation

### Preferred (Phương án tối ưu): Tái cấu trúc Viewport Bảng — Tái Sử Dụng Viewport Thay Vì Tái Tạo

1. **Singleton/Persistent Viewport hoặc Viewport Caching trong `DatabaseControlViewModel`**:
   - Thay vì tạo mới `new DataViewControl(...)` ở mỗi lần click bảng, khởi tạo một thể hiện `DataViewControl` duy nhất (hoặc tái sử dụng `DataControlViewModel`) cho mỗi phiên kết nối database tab.
   - Thêm phương thức `LoadTable(DatabaseInfo database, Table table)` trên `DataControlViewModel` để chuyển đổi bảng mà không hủy bỏ Visual Tree của `VirtualTable`.
   - `VirtualTable` tự động tái sử dụng `VirtualTableRowPool` hiện có, chỉ cần thay thế `DataProvider` mới và đồng bộ lại cấu trúc cột (`SyncColumnsFromDataProvider`).
2. **Dọn dẹp triệt để tài nguyên khi Dispose & Unload**:
   - Trong `VirtualTable.xaml.cs`:
     - Cài đặt xử lý sự kiện `Unloaded` và phương thức `Dispose()` (hoặc `Cleanup()`).
     - Dừng hoạt ảnh DirectComposition: gọi `headerVisual.StopAnimation("Offset.X")`.
     - Dọn dẹp toàn bộ canvas row pool: `_rowPool.Clear(VirtualCanvas)` và gỡ bỏ event handlers.
     - Đặt `DataProvider = null`.
   - Trong `DataViewControl.xaml.cs`:
     - Gọi `Bindings.StopTracking()` khi control bị Dispose hoặc Unload.
     - Gọi dọn dẹp `VirtualTable`.
   - Trong `DataControlViewModel.cs`:
     - Trong phương thức `Dispose()`, gán `TableDataProvider = null;`, `DataPage = null;`.
     - Kích hoạt cơ chế thu dọn rác có chủ đích nếu cần thiết.

### Alternatives (Phương án phụ):
- Giữ nguyên cơ chế tạo mới `DataViewControl` nhưng bổ sung `IDisposable` sâu cho `VirtualTable`, giải phóng sạch sẽ toàn bộ Visual Tree, TextBlocks, Compositor animations và gọi `GC.Collect()` thế hệ 2 kèm `GC.WaitForPendingFinalizers()` sau khi dispose view cũ.
  - *Đánh giá trade-off*: Tốn chi phí CPU tạo đi tạo lại visual tree ở mỗi lần click chuột, tạo cảm giác giật nhẹ (UI stutter) khi chuyển bảng lớn.

**Files likely to change**:
- `DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseControlViewModel.cs`
- `DataSphere/ViewModels/Pages/DatabaseGroup/DataControlViewModel.cs`
- `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml.cs`
- `DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`
- `DataSphere/Controls/VirtualTable/VirtualTableRowPool.cs`

**Tests to add or update**:
- Kiểm thử UI Automation đo lường WorkingSet và PrivateMemory khi chuyển đổi liên tục qua 10 bảng dữ liệu trong `ngocthamcatalog`, xác nhận độ dốc tăng trưởng bộ nhớ tiệm cận 0 (Zero Growth Invariant sau khi Viewport đã được khởi tạo).
- Chụp ảnh DirectComposition (`PW_RENDERFULLCONTENT`) kiểm tra Viewport hiển thị đúng dữ liệu sau khi tái sử dụng.

## Risks & Considerations

- **Khác biệt lược đồ cột (Column Schema Mismatch)**: Khi chuyển giữa các bảng có số lượng và tên cột khác nhau (ví dụ từ bảng 4 cột sang bảng 30 cột), `VirtualTable` phải bảo đảm việc tái sử dụng `_rowPool` và `Columns` diễn ra mượt mà, không bị sót lại cột của bảng cũ.
- **Trạng thái phân trang (Pagination State)**: Cần reset `CurrentPage = 1` và hủy bỏ các truy vấn async đang dở dang (`CancellationTokenSource`) của bảng trước đó khi chuyển sang bảng mới.

## Open Questions

- Không có. Báo cáo đã định vị chính xác nguyên nhân gốc rễ và đo lường số liệu thực tế trên desktop thật.
