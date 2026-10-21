# Bug Fix: Dark Theme White Background Desynchronization and DWM Window Attribute Decoupling

- **Slug**: dark-theme-backdrop-desynchronization
- **Fixed**: 2026-10-21T15:34:30+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Khắc phục triệt để lỗi chế độ Tối (Dark Mode) bị nền xám trắng (`#F3F3F3`) làm mất tương phản hiển thị chữ (white-on-white) bằng giải pháp chuẩn 100% WinUI 3 C# & XAML (không sử dụng bất kỳ lệnh Win32 P/Invoke nào theo yêu cầu người dùng). Đã sử dụng cơ chế Dependency Property Precedence thuần túy của WinUI 3: `WindowRoot` mang Style Setter `{ThemeResource ApplicationPageBackgroundThemeBrush}`, kết hợp hợp nhất điều phối `ApplyThemeAndBackdrop` trong `ThemeService`. Khi ở chế độ Đơn sắc (Solid), `ClearValue` tự động kích hoạt Style Setter giúp XAML tự động vẽ `#202020` ở Dark Mode và `#F3F3F3` ở Light Mode; khi bật hiệu ứng nền (Mica/Tabbed/Acrylic), giá trị cục bộ `Transparent` đảm bảo ánh sáng DWM xuyên thấu hoàn hảo.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Views/Windows/ShellWindow.xaml` | Modified | Khai báo `<Grid.Style>` với `Setter Property="Background" Value="{ThemeResource ApplicationPageBackgroundThemeBrush}"` trên `WindowRoot` |
| `DataSphere/Services/Contracts/IThemeService.cs` | Modified | Thêm định nghĩa phương thức hợp nhất `ApplyThemeAndBackdrop(object window)` |
| `DataSphere/Services/ThemeService.cs` | Modified | Hợp nhất điều phối Theme & Backdrop vào `ApplyThemeAndBackdrop`; loại bỏ hoàn toàn tra cứu tĩnh `Application.Current.Resources`; dùng `rootPanel.ClearValue` cho Solid |
| `DataSphere/Views/Windows/ShellWindow.xaml.cs` | Modified | Đăng ký cả hai sự kiện `ThemeChanged` và `BackdropChanged` gọi qua `ApplyThemeAndBackdrop(this)` |
| `DataSphere/Services/ApplicationHostService.cs` | Modified | Gọi một lệnh hợp nhất `_themeService.ApplyThemeAndBackdrop(shellWindow)` khi kích hoạt cửa sổ |
| `scripts/reproduce-dark-mode-issue.ps1` | Added | Script tái hiện và chụp ảnh DirectComposition kiểm thử Dark Mode |
| `scripts/set-dark-solid.ps1` / `scripts/set-light-solid.ps1` / `scripts/restore-default-settings.ps1` | Added | Helper scripts chuyển đổi nhanh cấu hình thử nghiệm |

## Diff Highlights

### 1. `ShellWindow.xaml`:
```xml
    <Grid x:Name="WindowRoot">
        <Grid.Style>
            <Style TargetType="Grid">
                <Setter Property="Background" Value="{ThemeResource ApplicationPageBackgroundThemeBrush}" />
            </Style>
        </Grid.Style>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
        </Grid.RowDefinitions>
```

### 2. `ThemeService.cs`:
```csharp
    public void ApplyThemeAndBackdrop(object window)
    {
        if (window is Window win)
        {
            var elementTheme = GetElementTheme(_currentTheme);

            if (win.Content is FrameworkElement fe)
            {
                fe.RequestedTheme = elementTheme;
            }

            if (win.AppWindow?.TitleBar != null)
            {
                switch (elementTheme)
                {
                    case ElementTheme.Light:
                        win.AppWindow.TitleBar.ButtonForegroundColor = Colors.Black;
                        win.AppWindow.TitleBar.ButtonHoverForegroundColor = Colors.Black;
                        break;
                    case ElementTheme.Dark:
                        win.AppWindow.TitleBar.ButtonForegroundColor = Colors.White;
                        win.AppWindow.TitleBar.ButtonHoverForegroundColor = Colors.White;
                        break;
                    default:
                        win.AppWindow.TitleBar.ButtonForegroundColor = null;
                        win.AppWindow.TitleBar.ButtonHoverForegroundColor = null;
                        break;
                }
            }

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

            if (win.Content is Panel rootPanel)
            {
                if (win.SystemBackdrop != null)
                {
                    rootPanel.Background = new SolidColorBrush(Colors.Transparent);
                }
                else
                {
                    rootPanel.ClearValue(Panel.BackgroundProperty);
                }
            }
        }
    }
```

## Local Verification

- **Biên dịch**: `dotnet build DataSphere\DataSphere.csproj -c Debug` → **0 Warning(s), 0 Error(s)**.
- **Kiểm định màu sắc điểm ảnh thực nghiệm (Pixel Inspection Gate)**:
  - Khi cấu hình `Dark + Solid`: Điểm ảnh nền đo được là `Color [A=255, R=32, G=32, B=32]` (`#202020` - màu tối WinUI 3 chuẩn xác). Chữ trắng và thẻ card nổi bật hoàn hảo trên nền tối.
  - Khi cấu hình `Light + Solid`: Điểm ảnh nền đo được là `Color [A=255, R=243, G=243, B=243]` (`#F3F3F3` - màu sáng WinUI 3 chuẩn xác).

## Deviations from Assessment

- Áp dụng 100% chuẩn WinUI 3 thuần túy bằng XAML Style Setter và `ClearValue`, loại bỏ hoàn toàn ý tưởng gọi Win32 P/Invoke `DwmSetWindowAttribute` theo đúng chỉ thị làm rõ của người dùng.

## Follow-ups

- Chạy `/speckit-bug-test slug=dark-theme-backdrop-desynchronization` để hoàn thành quy trình nghiệm thu.
