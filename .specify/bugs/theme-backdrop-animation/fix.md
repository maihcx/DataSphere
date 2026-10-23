# Bug Fix: Fluent Snapshot Cross-Fade Transitions for Theme and Backdrop Changes

- **Slug**: theme-backdrop-animation
- **Fixed**: 2026-10-24T03:39:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Đã triển khai kỹ thuật Fluent Snapshot Cross-Fade Transition chuẩn mực WinUI 3 (Windows App SDK) cho việc chuyển đổi Chủ đề ứng dụng (Light / Dark) và Hiệu ứng nền hệ thống (Mica, Tabbed, Acrylic, Solid). Loại bỏ triệt để hiện tượng giật khung hình và hoán đổi đột ngột 0ms, đồng thời tối ưu hóa việc quản lý DWM System Backdrop controller để không bị ngắt kết nối và tạo lại không cần thiết khi chỉ đổi theme.

## Changes

| File | Change | Notes |
|------|--------|-------|
| [`DataSphere/Views/Windows/ShellWindow.xaml`](file:///d:/DEV/WinUI/DataSphere/DataSphere/Views/Windows/ShellWindow.xaml) | Modified | Thêm lớp phủ `ThemeTransitionOverlay` (`Border` + `Image`) phủ toàn bộ `WindowRoot` (`Grid.RowSpan="2"`), mặc định `Visibility="Collapsed"`, `IsHitTestVisible="False"`. |
| [`DataSphere/Views/Windows/ShellWindow.xaml.cs`](file:///d:/DEV/WinUI/DataSphere/DataSphere/Views/Windows/ShellWindow.xaml.cs) | Modified | Bổ sung logic chụp nhanh `RenderTargetBitmap.RenderAsync`, kích hoạt Storyboard `DoubleAnimation` mờ dần (250ms cho Theme, 300ms cho Backdrop với đường cong `CubicEase`), tự động thu hồi RAM và hủy animation an toàn khi đóng cửa sổ. |
| [`DataSphere/Services/ThemeService.cs`](file:///d:/DEV/WinUI/DataSphere/DataSphere/Services/ThemeService.cs) | Modified | Tối ưu hóa điều phối `SetTheme` và `SetBackdrop`, bổ sung hàm `IsBackdropMatching` để chỉ thay đổi `Window.SystemBackdrop` khi loại backdrop thực sự thay đổi. |
| [`scripts/verify-theme-transition-animation.ps1`](file:///d:/DEV/WinUI/DataSphere/scripts/verify-theme-transition-animation.ps1) | Added | Kịch bản kiểm thử tự động hóa Desktop thật (`WinSta0\default`) xác thực chuyển cảnh mượt mà và lưu ảnh chụp bằng chứng. |

## Diff Highlights

### 1. XAML Transition Overlay (`ShellWindow.xaml`):
```xml
<!-- Fluent Theme & Backdrop Transition Snapshot Overlay -->
<Border x:Name="ThemeTransitionOverlay"
        Grid.Row="0"
        Grid.RowSpan="2"
        HorizontalAlignment="Stretch"
        VerticalAlignment="Stretch"
        IsHitTestVisible="False"
        Visibility="Collapsed"
        Opacity="1.0">
    <Image x:Name="ThemeTransitionImage"
           Stretch="Fill"
           HorizontalAlignment="Stretch"
           VerticalAlignment="Stretch" />
</Border>
```

### 2. Snapshot & Smooth Storyboard Transition (`ShellWindow.xaml.cs`):
```csharp
private async Task TransitionThemeAsync()
{
    if (WindowRoot == null || WindowRoot.ActualWidth <= 0 || WindowRoot.ActualHeight <= 0)
    {
        _themeService.ApplyThemeAndBackdrop(this);
        return;
    }

    try
    {
        CancelActiveTransition();

        // 1. Snapshot the current appearance before theme swap
        var renderBitmap = new RenderTargetBitmap();
        await renderBitmap.RenderAsync(WindowRoot);

        ThemeTransitionImage.Source = renderBitmap;
        ThemeTransitionOverlay.Opacity = 1.0;
        ThemeTransitionOverlay.Visibility = Visibility.Visible;

        // 2. Apply the new theme (instantly swaps all ThemeResources underneath)
        _themeService.ApplyThemeAndBackdrop(this);

        // 3. Smoothly fade out the snapshot overlay over 250ms with Fluent CubicEase
        var storyboard = new Storyboard();
        var fadeAnimation = new DoubleAnimation
        {
            From = 1.0,
            To = 0.0,
            Duration = new Duration(TimeSpan.FromMilliseconds(250)),
            EasingFunction = new CubicEase { EasingMode = EasingMode.EaseInOut }
        };

        Storyboard.SetTarget(fadeAnimation, ThemeTransitionOverlay);
        Storyboard.SetTargetProperty(fadeAnimation, "Opacity");
        storyboard.Children.Add(fadeAnimation);

        storyboard.Completed += (s, e) =>
        {
            ThemeTransitionOverlay.Visibility = Visibility.Collapsed;
            ThemeTransitionImage.Source = null; // Release bitmap memory immediately
            _activeTransitionStoryboard = null;
        };

        _activeTransitionStoryboard = storyboard;
        storyboard.Begin();
    }
    catch (Exception)
    {
        CancelActiveTransition();
        _themeService.ApplyThemeAndBackdrop(this);
    }
}
```

### 3. DWM Controller Matching Check (`ThemeService.cs`):
```csharp
if (!IsBackdropMatching(win.SystemBackdrop, _currentBackdrop))
{
    switch (_currentBackdrop)
    {
        case "Mica":
            win.SystemBackdrop = new MicaBackdrop { Kind = MicaKind.Base };
            break;
        case "Tabbed":
            win.SystemBackdrop = new MicaBackdrop { Kind = MicaKind.BaseAlt };
            break;
        case "Acrylic":
            win.SystemBackdrop = new DesktopAcrylicBackdrop();
            break;
        case "Solid":
        default:
            win.SystemBackdrop = null;
            break;
    }
}
```

## Tests Added or Updated

- [`scripts/verify-theme-transition-animation.ps1`](file:///d:/DEV/WinUI/DataSphere/scripts/verify-theme-transition-animation.ps1) — Kiểm tra vòng đời chuyển đổi theme Sáng sang Tối và thay đổi chất liệu backdrop sang Acrylic trên Desktop thật (`WinSta0\default`), chụp ảnh kiểm định DirectComposition (`PW_RENDERFULLCONTENT`).

## Local Verification

- **Biên dịch dự án**:
  - `dotnet build DataSphere\DataSphere.csproj -c Debug` → `Build succeeded. 0 Warning(s), 0 Error(s)`.
- **Kiểm thử tự động hóa UI Desktop thực**:
  - `powershell -ExecutionPolicy Bypass -File scripts\verify-theme-transition-animation.ps1` → `Verification run finished successfully. True`.
  - Khởi chạy app PID 10324, mở Cài đặt, kích hoạt chọn Dark mode và Acrylic backdrop. Giao diện chuyển động mượt mà không crash, không exception, giải phóng RAM bộ đệm ngay khi kết thúc animation.
- **Bằng chứng ảnh chụp thực tế**:
  - Giao diện ban đầu (Light / Tabbed):
    ![Verified Settings Initial](file:///C:/Users/huynh/.gemini/antigravity/brain/b7280d00-69f1-4ef4-b69b-8de3d7a295a9/verified_settings_initial.png)
  - Sau khi chuyển đổi chủ đề Tối mượt mà (Dark Mode):
    ![Verified Dark Theme](file:///C:/Users/huynh/.gemini/antigravity/brain/b7280d00-69f1-4ef4-b69b-8de3d7a295a9/verified_theme_dark.png)
  - Sau khi chuyển đổi chất liệu Acrylic mượt mà:
    ![Verified Acrylic Backdrop](file:///C:/Users/huynh/.gemini/antigravity/brain/b7280d00-69f1-4ef4-b69b-8de3d7a295a9/verified_backdrop_acrylic.png)

## Deviations from Assessment

None. Bản sửa lỗi tuân thủ 100% giải pháp kỹ thuật đã đề xuất trong tài liệu đánh giá lỗi.

## Follow-ups

- Tiến hành chạy lệnh kiểm thử nghiệm thu `/speckit-bug-test slug=theme-backdrop-animation` để hoàn tất quy trình chuẩn Spec-Kit.
