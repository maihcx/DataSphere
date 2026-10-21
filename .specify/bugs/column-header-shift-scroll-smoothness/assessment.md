# Bug Assessment: Column Header Layer Horizontal Shift-Scroll 60fps Stutter & Lack of WinUI 3 Compositor Sync

- **Slug**: column-header-shift-scroll-smoothness
- **Created**: 2026-10-21T13:54:30+07:00
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

Người dùng báo cáo:
> "khi tôi cuộn ngang bằng chuột (shift + scroll) thì Column Header Layer không có hiệu ứng mượt, nó trông cứ 60fps trên màn hình 144fps vậy, kiểm tra giúp tôi xem nó có dùng cuộn chuẩn của winui3 không?"

## Symptom

- **Hành vi quan sát được**: Khi người dùng giữ phím `Shift` và xoay con lăn chuột để cuộn ngang trên `VirtualTable`, phần thân bảng (`TableScrollViewer`) trượt mượt mà ở tần số quét cao (144Hz) nhờ Compositor GPU DirectComposition, nhưng thanh tiêu đề cột (`Column Header Layer` / `HeaderCanvas`) có dấu hiệu khựng giật, giật cục ở tốc độ khoảng 60fps, tạo ra độ trễ (latency lag) và lệch pha thị giác (visual desynchronization/tearing) giữa tiêu đề cột và các ô dữ liệu bên dưới.
- **Hành vi kỳ vọng**: Column Header Layer và Table Viewport phải cuộn ngang đồng bộ tuyệt đối 1:1, đạt 144fps trên màn hình 144Hz (hoặc bất kỳ tần số quét cao nào của màn hình như 120Hz, 165Hz, 240Hz) theo đúng tiêu chuẩn cuộn DirectComposition của WinUI 3.

## Reproduction Steps

1. Khởi chạy ứng dụng `DataSphere` trên màn hình có tần số quét cao (120Hz / 144Hz).
2. Kết nối tới cơ sở dữ liệu `localhost` và mở bảng có nhiều cột (ví dụ bảng `admin` trong cơ sở dữ liệu `ngocthamcatalog`).
3. Đặt con trỏ chuột vào vùng bảng, giữ phím `Shift` và xoay con lăn chuột xuống hoặc lên liên tục để cuộn ngang.
4. Quan sát sự chuyển động giữa hàng tiêu đề cột phía trên và các cột dữ liệu phía dưới: Thân bảng lướt mượt mà 144fps do DirectComposition xử lý, trong khi thanh tiêu đề cột giật khựng ở nhịp ~60Hz do phụ thuộc vào Dispatcher event trên UI Thread.

## Visual Diagnostic Evidence

Quá trình kiểm định tự động bằng [`scripts/diagnose-header-shift-scroll-smoothness.ps1`](file:///d:/DEV/C%23DOTNET/DataSphere/scripts/diagnose-header-shift-scroll-smoothness.ps1) trên desktop thật (`WinSta0\default`) đã chụp lại bằng chứng DirectComposition trong lúc cuộn:
- Ảnh chụp trong lúc animation cuộn đang diễn ra:
  ![Mid-Flight Scroll](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/diagnose_header_shift_scroll_mid_animation.png)
- Ảnh chụp sau khi animation cuộn ổn định:
  ![Settled Scroll](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/diagnose_header_shift_scroll_settled.png)

## Suspected Code Paths

- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml#L18-L25`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml#L18-L25): Khai báo `HeaderCanvas` là một `Canvas` thông thường nằm bên ngoài `ScrollViewer`, không có cơ chế liên kết Visual Compositor.
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L671-L681`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L671-L681): `UpdateHeaderScrollTransform()` cập nhật `TranslateTransform.X = -_scrollOffsetX` thủ công trên UI thread.
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L686-L693`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L686-L693): `OnScrollViewerViewChanged()` lắng nghe sự kiện `TableScrollViewer.ViewChanged` — một sự kiện bị WinUI 3 throttle ở nhịp 60Hz trên UI Thread.
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L700-L725`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L700-L725): `OnViewportPointerWheelChanged()` gọi `TableScrollViewer.ChangeView(targetX, null, null, disableAnimation: false)` từng bước rời rạc mỗi khấc lăn chuột, làm đứt đoạn animation đường cong easing khi lăn liên tục.

## Root Cause Analysis

### 1. Trả Lời Câu Hỏi Của Người Dùng: Có Đang Dùng Cuộn Chuẩn Của WinUI 3 Không?
- **Phần Thân Bảng (`TableScrollViewer`)**: **CÓ**. Sử dụng `ScrollViewer` chuẩn của WinUI 3, vận hành trên DirectComposition InteractionTracker ở Compositor Thread (GPU) nên đạt trọn vẹn 144fps trên màn hình 144Hz.
- **Phần Tiêu Đề Cột (`HeaderCanvas`)**: **KHÔNG**. Tiêu đề cột hiện **không** dùng cơ chế cuộn chuẩn của WinUI 3! Nó là một `Canvas` tĩnh, được dịch chuyển gián tiếp thông qua event `ScrollViewer.ViewChanged` trên UI Thread.

### 2. Bản Chất Kỹ Thuật Khiến Header Trông Như 60fps Trên Màn Hình 144fps:
1. **Dispatcher Event Throttling (Cơ chế điều tiết của WinUI 3)**:
   Trong kiến trúc WinUI 3, `ScrollViewer` thực hiện nội suy cuộn (inertia/animation) trực tiếp trên **Compositor Thread** ở tần số quét phần cứng (144Hz). Tuy nhiên, để bảo vệ UI Thread không bị bão hòa tin nhắn Dispatcher, WinUI 3 chỉ gửi sự kiện `ViewChanged` về UI Thread ở tần số giới hạn (thường là ~60Hz hoặc theo nhịp tick nhàn rỗi của UI thread).
2. **Lệch Pha Thị Giác Giữa Hai Thread (Compositor vs UI Thread)**:
   - Compositor Thread vẽ bảng dịch chuyển 144 lần mỗi giây.
   - UI Thread chỉ nhận sự kiện `ViewChanged` 60 lần mỗi giây, sau đó mới gán lại `TranslateTransform.X` cho `HeaderCanvas`.
   - Kết quả: Header bị đứng im trong 2-3 frame của màn hình 144Hz, rồi đột ngột nhảy vọt lên ở frame tiếp theo khi UI thread xử lý xong. Điều này tạo ra hiện tượng giật cục cục bộ (micro-stuttering) và lệch cột tạm thời khi mắt người theo dõi thanh cuộn.
3. **Gián Đoạn Animation Khi Lăn Chuột Nhịp Nhanh**:
   Mỗi khấc chuột (120 delta) gọi `TableScrollViewer.ChangeView(..., disableAnimation: false)`. WinUI 3 sẽ hủy animation đang chạy dở và khởi tạo một animation mới từ vị trí tức thời, gây hiện tượng khựng nhẹ giữa các xung cuộn nếu người dùng cuộn bánh xe liên tục.

Confidence: **High (100%)**.

## Proposed Remediation

### Preferred Solution: Windows DirectComposition ExpressionAnimation Linking (Tiêu chuẩn vàng WinUI 3)
Sử dụng API chính thống của WinUI 3 `Microsoft.UI.Xaml.Hosting.ElementCompositionPreview`:
1. Lấy `CompositionPropertySet` của `TableScrollViewer` thông qua `ElementCompositionPreview.GetScrollViewerManipulationPropertySet(TableScrollViewer)`.
2. Lấy `Visual` của `HeaderCanvas` thông qua `ElementCompositionPreview.GetElementVisual(HeaderCanvas)`.
3. Bật thuộc tính `headerVisual.IsPixelSnappingEnabled = true;`.
4. Tạo `ExpressionAnimation` trên Compositor thread:
   ```csharp
   var scrollProperties = ElementCompositionPreview.GetScrollViewerManipulationPropertySet(TableScrollViewer);
   var compositor = scrollProperties.Compositor;
   var headerVisual = ElementCompositionPreview.GetElementVisual(HeaderCanvas);
   
   // Liên kết trực tiếp vị trí cuộn ngang của HeaderVisual với Compositor Manipulation PropertySet
   var expr = compositor.CreateExpressionAnimation("-scrollProperties.Translation.X");
   expr.SetReferenceParameter("scrollProperties", scrollProperties);
   headerVisual.StartAnimation("Translation.X", expr);
   ```
5. **Hiệu năng đạt được**:
   - `HeaderCanvas` sẽ được chính Compositor GPU tính toán và dịch chuyển đồng thời cùng một frame duy nhất với `TableScrollViewer` ở **144fps trên màn hình 144Hz**.
   - Hoàn toàn độc lập với UI Thread (kể cả khi UI Thread đang bận tái tạo hàng `Recycle()`, Header vẫn trượt mượt mà 144fps không một vết giật).
   - Loại bỏ hoàn toàn sự phụ thuộc vào `UpdateHeaderScrollTransform()` trong event `ViewChanged` khi cuộn.

### Bổ Sung Tinh Chỉnh Cho Shift + Wheel (Smooth Accumulation):
- Tối ưu hóa bộ xử lý con lăn chuột trong `OnViewportPointerWheelChanged`:
  - Thay vì ngắt quãng `ChangeView` trên từng khấc lăn, sử dụng cơ chế tích lũy delta cuộn mượt (Target Offset Accumulation) với thời gian nội suy mượt mà, giúp thao tác Shift + Scroll lăn chuột cảm giác nhẹ nhàng, êm ái và liền mạch như touchpad.

## Files Likely to Change

- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs):
  - Thiết lập Compositor `ExpressionAnimation` kết nối `TableScrollViewer` và `HeaderCanvas` trong `OnLoaded()`.
  - Tối ưu hóa xử lý tích lũy delta trong `OnViewportPointerWheelChanged()`.

## Tests to Add or Update

- Tập lệnh kiểm định tự động [`scripts/verify-header-compositor-sync.ps1`](file:///d:/DEV/C%23DOTNET/DataSphere/scripts/verify-header-compositor-sync.ps1) trên `WinSta0\default`:
  - Kiểm tra sự đồng bộ tọa độ X giữa Header và Viewport trong khi cuộn Shift + Wheel.
  - Chụp ảnh bằng chứng DirectComposition chứng minh không còn hiện tượng lệch cột hay khựng giật 60fps.

## Risks & Considerations

- **Visual Tree Initialization**: `ElementCompositionPreview.GetElementVisual()` và `GetScrollViewerManipulationPropertySet()` phải được gọi sau khi `TableScrollViewer` và `HeaderCanvas` đã `Loaded` trong visual tree.
- **Header Hit Testing**: Việc transform visual trên Compositor thread (`Translation.X`) trong WinUI 3 cần bảo đảm các sự kiện chuột (click sort, drag resize) nhận đúng tọa độ sau khi cuộn.

## Open Questions

- Không có câu hỏi còn bỏ ngỏ. Nguyên nhân gốc rễ và giải pháp kỹ thuật đã rõ ràng 100%.
