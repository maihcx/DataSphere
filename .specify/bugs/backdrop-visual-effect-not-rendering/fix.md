# Bug Fix: System Backdrop Visual Effects (Mica, Tabbed, Acrylic) Ineffective Due to Opaque XAML Page Surfaces

- **Slug**: backdrop-visual-effect-not-rendering
- **Fixed**: 2026-10-21T15:10:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Khắc phục triệt để lỗi hiệu ứng nền hệ thống Windows 11 (Mica, Tabbed / Mica Alt, Acrylic) không hiển thị do các lớp XAML gốc (`ShellWindow.WindowRoot`, `ShellTabView`, `Page`, `ScrollViewer`, `StackPanel`, `UserControl`) mang cọ nền đặc 100% `{ThemeResource ApplicationPageBackgroundThemeBrush}` che lấp toàn bộ DirectComposition DWM surface bên dưới. Đã chuyển toàn bộ các lớp chứa sang `Background="Transparent"`, hỗ trợ hiển thị xuyên thấu hiệu ứng nền và hoàn thiện cơ chế khôi phục màu nền đặc khi người dùng chọn chế độ `Solid`.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Views/Windows/ShellWindow.xaml` | Modified | Chuyển `WindowRoot.Background` và `ShellTabView.Background` sang `Transparent`, đặt `ContentPresenter.Background="Transparent"` |
| `DataSphere/Views/PagesBottom/SettingsPage.xaml` | Modified | Đặt `Background="Transparent"` cho `<Page>`, root `<Grid>`, `<ScrollViewer>` và `<StackPanel>` |
| `DataSphere/Views/Pages/HomePage.xaml` | Modified | Đặt `Background="Transparent"` cho `<Page>`, `<ScrollViewer>` và `<StackPanel>` |
| `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml` | Modified | Đặt `Background="Transparent"` cho `<Page>` và root `<Grid>` |
| `DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml` | Modified | Đặt `Background="Transparent"` cho root `<Grid>` |
| `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml` | Modified | Đặt `Background="Transparent"` cho root `<Grid>` |
| `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml` | Modified | Đặt `Background="Transparent"` cho root `<Grid>` |
| `DataSphere/App.xaml` | Modified | Bổ sung `ResourceDictionary.ThemeDictionaries` đặt `TabViewBackground="Transparent"` cho Default, Light, Dark themes |
| `DataSphere/Services/ThemeService.cs` | Modified | Đảm bảo khi chọn `Solid`, gán lại `ApplicationPageBackgroundThemeBrush` cho `WindowRoot`; đồng bộ cập nhật backdrop khi đổi theme |
| `scripts/verify-fluent-settings-and-backdrops.ps1` | Modified | Phạm vi hóa UI Automation tìm kiếm dropdown list items theo process PID `pi.dwProcessId` và nhận diện mục Solid độc lập ngôn ngữ |
| `scripts/compare-backdrop-diff.ps1` | Added | Script kiểm định độ lệch pixel thực nghiệm giữa các chế độ nền |

## Diff Highlights

### 1. `ShellWindow.xaml`:
```xml
    <Grid x:Name="WindowRoot" Background="Transparent">
        ...
        <TabView
            x:Name="ShellTabView"
            Grid.Row="0"
            Background="Transparent"
            ... />
        <ContentPresenter
            Grid.Row="1"
            Background="Transparent"
            Content="{x:Bind ViewModel.SelectedTab.Content, Mode=OneWay}"
            ... />
    </Grid>
```

### 2. `SettingsPage.xaml`:
```xml
<Page
    x:Class="DataSphere.Views.PagesBottom.SettingsPage"
    ...
    Background="Transparent">
    <Grid HorizontalAlignment="Stretch" VerticalAlignment="Stretch" Background="Transparent">
        <ScrollViewer ... Background="Transparent">
            <StackPanel ... Background="Transparent">
                ...
```

### 3. `ThemeService.cs`:
```csharp
    if (win.Content is Panel rootPanel)
    {
        if (win.SystemBackdrop != null)
        {
            rootPanel.Background = new SolidColorBrush(Colors.Transparent);
        }
        else
        {
            if (Application.Current.Resources.TryGetValue("ApplicationPageBackgroundThemeBrush", out var brush) && brush is Brush appBackgroundBrush)
            {
                rootPanel.Background = appBackgroundBrush;
            }
            else
            {
                rootPanel.ClearValue(Panel.BackgroundProperty);
            }
        }
    }
```

## Local Verification

- **Biên dịch .NET 10 WPF / WinUI 3**:
  `dotnet build DataSphere\DataSphere.csproj -c Debug` → **0 Warning(s), 0 Error(s)**.
- **Kiểm thử tự động hóa Desktop thực (`WinSta0\default`)**:
  `powershell -ExecutionPolicy Bypass -File scripts\verify-fluent-settings-and-backdrops.ps1` → **ALL FLUENT SETTINGS AND SYSTEM BACKDROP TESTS PASSED!**
- **Đo lường độ lệch điểm ảnh thực nghiệm (Pixel Difference)**:
  `powershell -ExecutionPolicy Bypass -File scripts\compare-backdrop-diff.ps1`:
  - `Tabbed vs Solid Diff`: **63,245 / 66,600 sampled pixels (94.96 %)**.
  - Vùng nền đã chuyển đổi rõ rệt giữa chất liệu nền hệ thống WinUI 3 (`#F9F9F9`) và màu nền đặc cổ điển (`#F3F3F3`).

## Deviations from Assessment

- Bổ sung cấu hình `ResourceDictionary.ThemeDictionaries` trong `App.xaml` để override `TabViewBackground` thành `Transparent` ở tầng toàn cục ứng dụng.
- Đặt `Background="Transparent"` cho cả `<ScrollViewer>` và `<StackPanel>` bên trong các trang để ngăn ngừa các container trung gian che khuất backdrop.

## Follow-ups

- Chạy `/speckit-bug-test slug=backdrop-visual-effect-not-rendering` để thực hiện nghiệm thu toàn diện và xuất báo cáo kiểm định hoàn tất.
