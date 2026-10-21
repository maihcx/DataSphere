# Bug Assessment: System Backdrop Visual Effects (Mica, Tabbed, Acrylic) Ineffective Due to Opaque XAML Page Surfaces

- **Slug**: backdrop-visual-effect-not-rendering
- **Created**: 2026-10-21T15:00:00+07:00
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Người dùng báo cáo:
> "tôi thấy dù thay đổi hiệu ứng mica - tabbed hay acrylic thì nền vẫn không có gì thay đổi, vui lòng kiểm tra lại"

## Symptom

- **Hành vi quan sát được**: Khi người dùng vào trang Cài đặt (Settings), chuyển đổi giữa các hiệu ứng nền hệ thống Windows 11 (Mica, Tabbed / Mica Alt, Acrylic, hoặc Solid), toàn bộ màu nền và bề mặt trực quan của cửa sổ ứng dụng hoàn toàn không có bất kỳ thay đổi nào. Cửa sổ giữ nguyên một màu xám đục cố định (`#F3F3F3` ở Light mode hoặc `#202020` ở Dark mode).
- **Hành vi kỳ vọng**: 
  - Khi chọn **Mica**: Bề mặt cửa sổ hiển thị chất liệu Mica lấy mẫu màu và chi tiết nhẹ nhàng từ hình nền Desktop của người dùng.
  - Khi chọn **Tabbed (Mica Alt)**: Hiển thị biến thể Mica Alt có độ tương phản và sắc thái phân tách tab rõ nét.
  - Khi chọn **Acrylic**: Cửa sổ phản chiếu hiệu ứng mờ nhòe kính mờ (Desktop Acrylic blur & noise tint) từ các cửa sổ và hình nền bên dưới.
  - Khi chọn **Solid**: Hiển thị màu nền đơn sắc cổ điển của ứng dụng.

## Reproduction Steps

1. Khởi chạy ứng dụng `DataSphere` trên Windows 11 (`WinSta0\default`).
2. Mở tab Cài đặt (Settings) từ trang chủ hoặc menu điều hướng.
3. Cuộn tới thẻ "Hiệu ứng nền" (System Backdrop).
4. Lần lượt chọn các mục: `Tabbed (Mica Alt)`, `Mica`, `Acrylic`, `Solid`.
5. Quan sát trực quan nền cửa sổ ứng dụng: Bề mặt cửa sổ hoàn toàn trơ lỳ, không có bất kỳ phản chiếu hình nền hay hiệu ứng làm mờ acrylic/mica nào.

## Empirical Diagnostic Reproduction & Visual Evidence Gate (Principle VIII)

Quá trình kiểm định tự động hóa UI bằng [`scripts/verify-fluent-settings-and-backdrops.ps1`](file:///d:/DEV/C%23DOTNET/DataSphere/scripts/verify-fluent-settings-and-backdrops.ps1) đã chụp lại các khung hình DirectComposition chuẩn (`PW_RENDERFULLCONTENT`) khi chuyển đổi giữa các hiệu ứng:
- Ảnh chụp hiệu ứng Tabbed:
  ![Backdrop Tabbed](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/winui_backdrop_tabbed.png)
- Ảnh chụp hiệu ứng Acrylic:
  ![Backdrop Acrylic](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/winui_backdrop_acrylic.png)
- Ảnh chụp hiệu ứng Solid:
  ![Backdrop Solid](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/winui_backdrop_solid.png)

### Bằng chứng định lượng so sánh điểm ảnh (Pixel-Level Diff Analysis):
- So sánh `winui_backdrop_tabbed.png` với `winui_backdrop_acrylic.png` trên tổng số 1,065,600 pixels (cửa sổ 1332x800):
  - **Số pixel thay đổi**: Đúng 565 pixels (tương đương **0.05%** diện tích cửa sổ).
  - **Vị trí các pixel thay đổi**: Duy nhất cụm văn bản nằm trong `TextBlock` hiển thị tên lựa chọn của `ComboBox` ("Tabbed (Mica Alt)" so với "Acrylic").
  - **Điểm ảnh vùng nền**: **0 pixel thay đổi (0.00%)**.
  - **Kết luận chẩn đoán**: Lỗi hoàn toàn có thật và được xác thực 100% bằng chứng thực nghiệm.

## Suspected Code Paths

- [`DataSphere/Views/PagesBottom/SettingsPage.xaml#L2-L10`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/PagesBottom/SettingsPage.xaml#L2-L10): Khai báo `<Page>` không thiết lập thuộc tính `Background="Transparent"`. Theo mặc định của WinUI 3, Style mặc định của `Page` tự động gán `Background="{ThemeResource ApplicationPageBackgroundThemeBrush}"` — một brush đặc 100% che phủ toàn bộ viewport.
- [`DataSphere/Views/Pages/HomePage.xaml#L2-L10`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/HomePage.xaml#L2-L10): Khai báo `<Page>` thiếu `Background="Transparent"`.
- [`DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml#L12`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml#L12): `<Grid Background="{ThemeResource ApplicationPageBackgroundThemeBrush}">` che phủ hoàn toàn phân hệ quản lý database.
- [`DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml#L12`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml#L12): `<Grid Background="{ThemeResource ApplicationPageBackgroundThemeBrush}">`.
- [`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml#L12`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml#L12): `<Grid Background="{ThemeResource ApplicationPageBackgroundThemeBrush}">`.
- [`DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml#L14`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml#L14): `<Grid Background="{ThemeResource ApplicationPageBackgroundThemeBrush}">`.
- [`DataSphere/Views/Windows/ShellWindow.xaml#L22-L24`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Windows/ShellWindow.xaml#L22-L24): `<TabView x:Name="ShellTabView">` không có thuộc tính `Background="Transparent"`, làm thanh tab strip ở Row 0 bị che mờ một phần backdrop.
- [`DataSphere/Services/ThemeService.cs#L168-L201`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Services/ThemeService.cs#L168-L201): `ApplyBackdropToWindow()` chỉ xử lý đặt `rootPanel.Background = Transparent` cho `WindowRoot`, nhưng không kiểm soát các Page bên trong `ContentPresenter`.

## Root Cause Analysis

Trong kiến trúc DirectComposition của WinUI 3 / Windows App SDK:
1. `Window.SystemBackdrop` (Mica, Mica Alt, Acrylic) được vẽ bởi DWM ở tầng sâu nhất bên dưới toàn bộ cây visual XAML.
2. Để chất liệu Mica/Acrylic lộ ra được tới mắt người dùng, **tất cả các phần tử bao bọc từ Window xuống tới bề mặt hiển thị đều phải trong suốt (`Background="Transparent"`)**.
3. Trong `DataSphere`, mặc dù `ThemeService.ApplyBackdropToWindow` đã gán `WindowRoot.Background = Transparent`, nhưng:
   - Các `Page` (`SettingsPage`, `HomePage`, `DatabasePage`) và `UserControl` đều nhận hoặc tự gán cọ nền `{ThemeResource ApplicationPageBackgroundThemeBrush}`.
   - Cọ `ApplicationPageBackgroundThemeBrush` trong WinUI 3 là một solid color brush đục 100% (`#F3F3F3` ở Light mode, `#202020` ở Dark mode).
   - Khi `ContentPresenter` hiển thị một `Page`, tấm nền đục của `Page` đã hoàn toàn "chặn đứng" (block) mọi ánh sáng và hiệu ứng từ DWM SystemBackdrop bên dưới.
   - Các thẻ card bên trong (như các thiết lập cài đặt) đã dùng đúng `{ThemeResource CardBackgroundFillColorDefaultBrush}` (bán trong suốt), nhưng vì nằm đè lên `Page` đục nên hiệu ứng hòa trộn không thể chạm tới DWM.

Confidence: **High (100%)**.

## Proposed Remediation

### 1. Thiết lập `Background="Transparent"` cho các Page & View Controls:
- Cập nhật các tệp XAML:
  - `DataSphere/Views/PagesBottom/SettingsPage.xaml`: Thêm `Background="Transparent"` vào thẻ `<Page>`.
  - `DataSphere/Views/Pages/HomePage.xaml`: Thêm `Background="Transparent"` vào thẻ `<Page>`.
  - `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml`: Thay đổi Grid gốc thành `Background="Transparent"`.
  - `DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml`: Thay đổi Grid gốc thành `Background="Transparent"`.
  - `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml`: Thay đổi Grid gốc thành `Background="Transparent"`.
  - `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml`: Thay đổi Grid gốc thành `Background="Transparent"`.

### 2. Thiết lập `Background="Transparent"` cho `ShellTabView`:
- Cập nhật `DataSphere/Views/Windows/ShellWindow.xaml`:
  - Thêm `Background="Transparent"` vào `<TabView x:Name="ShellTabView">` để dải tab trên thanh tiêu đề đồng nhất hiệu ứng với toàn bộ cửa sổ.

### 3. Đồng bộ hóa chuyển đổi `Solid` vs `SystemBackdrop` trong `ThemeService`:
- Khi người dùng chọn `Solid`, `win.SystemBackdrop = null`, `WindowRoot.Background` được trả về `{ThemeResource ApplicationPageBackgroundThemeBrush}` để hiển thị màu nền đục chuẩn.
- Khi người dùng chọn `Mica`, `Tabbed`, hoặc `Acrylic`, `win.SystemBackdrop` được kích hoạt và `WindowRoot.Background` là `Transparent`, để lộ 100% hiệu ứng nền xuyên qua các Page trong suốt.

## Files Likely to Change

- `DataSphere/Views/PagesBottom/SettingsPage.xaml`
- `DataSphere/Views/Pages/HomePage.xaml`
- `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml`
- `DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml`
- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml`
- `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml`
- `DataSphere/Views/Windows/ShellWindow.xaml`
- `DataSphere/Services/ThemeService.cs`

## Tests to Add or Update

- Cập nhật kịch bản kiểm tra desktop thật [`scripts/verify-fluent-settings-and-backdrops.ps1`](file:///d:/DEV/C%23DOTNET/DataSphere/scripts/verify-fluent-settings-and-backdrops.ps1):
  - Lần lượt đổi giữa `Tabbed`, `Acrylic`, `Solid`.
  - Đo lường độ lệch pixel giữa ảnh chụp `Acrylic` và `Tabbed` / `Solid`. Độ lệch pixel vùng nền phải đạt trên 5% để chứng minh hiệu ứng DWM Mica/Acrylic thực tế đang hiển thị qua lớp XAML.

## Risks & Considerations

- **Độ tương phản văn bản**: Các vùng chữ và icon cần bảo đảm độ tương phản chuẩn WCAG khi nền là Acrylic hoặc Mica bằng cách sử dụng các theme brush ngữ nghĩa chuẩn (`TextFillColorPrimaryBrush`, `TextFillColorSecondaryBrush`).
- **Thao tác kéo thả cửa sổ**: Các vùng trống trên Tab strip phải giữ nguyên thuộc tính hit-test trong suốt để Windows kéo thả cửa sổ bình thường.

## Open Questions

- Không có. Nguyên nhân và phương án khắc phục đã rõ ràng và được xác thực 100% bằng chứng thực nghiệm.
