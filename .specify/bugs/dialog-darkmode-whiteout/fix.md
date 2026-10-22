# Bug Fix: ContentDialog Desynchronized from App Theme (Whiteout in Dark Mode)

- **Slug**: `dialog-darkmode-whiteout`
- **Fixed**: 2026-10-22T13:37:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Resolved the ContentDialog whiteout defect in Dark mode by introducing a centralized `ThemeSource` (`DataSphere.Utils.ThemeSource`) and declaring both an application-wide implicit `Style TargetType="ContentDialog"` in `App.xaml` and direct `RequestedTheme` bindings on dialogs. All popups and dialogs now dynamically inherit the application's active Fluent theme (Dark or Light) via pure XAML bindings without any procedural code-behind color assignment.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Utils/ThemeSource.cs` | added | Thread-safe, singleton `ThemeSource` implementing `INotifyPropertyChanged` to expose `CurrentElementTheme` for XAML bindings |
| `DataSphere/Services/ThemeService.cs` | modified | Synchronized `ThemeSource.Instance.CurrentElementTheme` during `Initialize()`, `SetTheme()`, and `ApplyThemeAndBackdrop()` |
| `DataSphere/App.xaml` | modified | Registered `<utils:ThemeSource x:Key="AppTheme" />` and defined global `<Style TargetType="ContentDialog">` setting `RequestedTheme` |
| `DataSphere/Views/Dialogs/ConnectionEditingDialog.xaml` | modified | Added `RequestedTheme="{Binding CurrentElementTheme, Source={StaticResource AppTheme}, Mode=OneWay}"` |
| `DataSphere/Views/Dialogs/DatabaseEditingDialog.xaml` | modified | Added `RequestedTheme="{Binding CurrentElementTheme, Source={StaticResource AppTheme}, Mode=OneWay}"` |

## Diff Highlights

### 1. `DataSphere/Utils/ThemeSource.cs`: Dynamic Theme Binding Provider
```csharp
public class ThemeSource : INotifyPropertyChanged
{
    private static ElementTheme currentElementTheme = ElementTheme.Default;
    public static ThemeSource Instance => instance.Value;

    public ElementTheme CurrentElementTheme
    {
        get => currentElementTheme;
        set
        {
            if (currentElementTheme != value)
            {
                currentElementTheme = value;
                NotifyAllInstances();
            }
        }
    }
}
```

### 2. `DataSphere/App.xaml`: Global Style & Resource Registration
```xml
<utils:TranslationSource x:Key="Localization" />
<utils:ThemeSource x:Key="AppTheme" />

<!-- Global ContentDialog Style Ensuring Full Theme Synchronization in Popup Layer -->
<Style TargetType="ContentDialog">
    <Setter Property="RequestedTheme" Value="{Binding CurrentElementTheme, Source={StaticResource AppTheme}, Mode=OneWay}" />
</Style>
```

### 3. `DataSphere/Views/Dialogs/ConnectionEditingDialog.xaml`: Explicit XAML Binding
```xml
<ContentDialog
    x:Class="DataSphere.Views.Dialogs.ConnectionEditingDialog"
    ...
    RequestedTheme="{Binding CurrentElementTheme, Source={StaticResource AppTheme}, Mode=OneWay}"
    Title="{Binding [dialog_connectset_title], Source={StaticResource Localization}, Mode=OneWay}">
```

## Visual Verification

- **Diagnostic (Before Fix)**:
  ![Diagnostic Whiteout](file:///D:/DEV/C%23DOTNET/DataSphere/.specify/bugs/dialog-darkmode-whiteout/01_diagnostic_dialog_dark_mode.png)
  *Symptom: Dialog rendered in Light mode with white background and black text despite dark app mode.*

- **Verified (After Fix)**:
  ![Verified Dark Mode Dialog](file:///D:/DEV/C%23DOTNET/DataSphere/.specify/bugs/dialog-darkmode-whiteout/02_verified_dialog_dark_mode.png)
  *Result: Dialog renders seamlessly in native WinUI 3 Fluent Dark theme with dark card background, dark input fields, and high-contrast typography.*

## Local Verification

- **Compilation**: `dotnet build DataSphere\DataSphere.csproj -c Debug` → 0 Errors, 0 Warnings (Build time: ~13.45s).
- **Automation Harness**: `scripts/reproduce-dialog-theme.ps1` executed on real desktop (`WinSta0\default`), navigated to `DatabasePage`, clicked "Tạo kết nối mới", and captured `PrintWindow(..., PW_RENDERFULLCONTENT)` screenshot.

## Deviations from Assessment

None. The preferred remediation (Option 1) was implemented exactly as proposed.

## Follow-ups

- Run `/speckit-bug-test slug=dialog-darkmode-whiteout` to generate the formal test verification report.
