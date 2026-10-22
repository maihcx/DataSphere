# Bug Assessment: ContentDialog Desynchronized from App Theme (Whiteout in Dark Mode)

- **Slug**: `dialog-darkmode-whiteout`
- **Created**: 2026-10-22T13:33:00+07:00
- **Source**: "popup trong hình khi ở chế độ darkmode thì nó vẫn là màu trắng, giúp tôi fix bằng xaml nhé, theme thì đừng fix bằng C# behind" (with uploaded screenshot)
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

The user reported that the connection setup popup (`ConnectionEditingDialog`), when running in Dark Mode, fails to follow the dark theme and remains completely white:
> *"popup trong hình khi ở chế độ darkmode thì nó vẫn là màu trắng, giúp tôi fix bằng xaml nhé, theme thì đừng fix bằng C# behind"*

The user also provided photographic evidence showing the main application window rendered with a dark acrylic backdrop and dark title bar, while the centered "Thiết lập kết nối" ContentDialog appears with a glaring white background, black text, and light-themed input boxes.

## Symptom

When the application is configured in Dark mode (with Acrylic, Mica, Tabbed, or Solid backdrops), launching any `ContentDialog` (e.g. "Thiết lập kết nối" via `NewConnectionCommand` or "Tạo cơ sở dữ liệu") displays a dialog styled in full Light Theme (`#F3F3F3` background, black typography, light text inputs) instead of the expected WinUI 3 Fluent dark theme card, breaking visual cohesion and causing high contrast strain.

## Reproduction

1. Launch DataSphere with Dark theme configured (`IThemeType = "Dark"` in `userdata.json`).
2. Navigate to the Database Page (`DatabasePage`).
3. Click the "Tạo kết nối mới" (New Connection) toolbar button to invoke `ShowConnectionEditingDialogAsync()`.
4. Observe the displayed `ConnectionEditingDialog`.
5. **Expected**: The dialog appears in native WinUI 3 Dark theme (dark card background, light text, dark input controls).
6. **Observed**: The dialog appears with a white `#F3F3F3` container and Light theme inputs.

### Diagnostic Evidence

- **User Report Evidence**:
  ![User Defect Image](file:///D:/DEV/C%23DOTNET/DataSphere/.specify/bugs/dialog-darkmode-whiteout/user_defect_dialog_white.png)

- **Automated Live Reproduction Screenshot** (`WinSta0\default`):
  ![Diagnostic Reproduction](file:///D:/DEV/C%23DOTNET/DataSphere/.specify/bugs/dialog-darkmode-whiteout/01_diagnostic_dialog_dark_mode.png)

## Suspected Code Paths

- `DataSphere/Services/ThemeService.cs:215-218` — `ThemeService` only sets `RequestedTheme` on `win.Content` (`WindowRoot`).
- `DataSphere/Services/DialogService.cs:77-80` — `ShowConnectionEditingDialogAsync` creates `ConnectionEditingDialog` and assigns its `XamlRoot`, but does not bridge theme inheritance.
- `DataSphere/Views/Dialogs/ConnectionEditingDialog.xaml:2-14` — `ConnectionEditingDialog` does not bind `RequestedTheme`, defaulting to `ElementTheme.Default`.
- `DataSphere/Views/Dialogs/DatabaseEditingDialog.xaml:2-14` — `DatabaseEditingDialog` lacks `RequestedTheme` binding, exhibiting the same defect.
- `DataSphere/App.xaml:7-33` — `App.xaml` currently has `TranslationSource` for i18n, but lacks a centralized `ThemeSource` and global `Style TargetType="ContentDialog"`.

## Root Cause Hypothesis

**Confidence: High (Confirmed by WinUI 3 architectural invariants)**

In WinUI 3, `Microsoft.UI.Xaml.Window` does not derive from `FrameworkElement` and lacks a window-level `RequestedTheme` property. Theme changes are consequently applied to `(win.Content as FrameworkElement).RequestedTheme = elementTheme` (i.e. `WindowRoot`).

However, `ContentDialog` is **not** a descendant of `WindowRoot` in the XAML visual tree. When `dialog.ShowAsync()` is called, WinUI 3 inserts the dialog into a separate visual tree root hosted by `XamlRoot` known as `PopupRoot`. Because `PopupRoot` is a sibling, not a child of `WindowRoot`, it does not inherit `WindowRoot.RequestedTheme`. Instead, `ContentDialog.RequestedTheme` defaults to `ElementTheme.Default`. On Windows systems running in Light mode, `ElementTheme.Default` resolves against the OS theme, forcing the `ContentDialog` to pull exclusively from the Light ThemeDictionary (`ContentDialogBackground = #F3F3F3`).

## Proposed Remediation

### Preferred (Option 1 as selected by user): App-level `ThemeSource` + XAML Style & Binding

1. **Create `DataSphere.Utils.ThemeSource`**:
   Implement a thread-safe, singleton `ThemeSource` (following the exact pattern of `TranslationSource`), implementing `INotifyPropertyChanged` and exposing `CurrentElementTheme`.
2. **Synchronize `ThemeSource` in `ThemeService`**:
   In `ThemeService.ApplyThemeAndBackdrop()`, update `ThemeSource.Instance.CurrentElementTheme = elementTheme`.
3. **Declare `ThemeSource` in `App.xaml`**:
   Add `<utils:ThemeSource x:Key="AppTheme" />` to `<Application.Resources>`.
4. **Define implicit `ContentDialog` Style and explicit dialog bindings**:
   - In `App.xaml`:
     ```xml
     <Style TargetType="ContentDialog">
         <Setter Property="RequestedTheme" Value="{Binding CurrentElementTheme, Source={StaticResource AppTheme}, Mode=OneWay}" />
     </Style>
     ```
   - In `ConnectionEditingDialog.xaml` & `DatabaseEditingDialog.xaml`:
     ```xml
     RequestedTheme="{Binding CurrentElementTheme, Source={StaticResource AppTheme}, Mode=OneWay}"
     ```
   This guarantees that both implicit style inheritance and explicit XAML bindings propagate the application's active theme dynamically, with zero C# code-behind color assignment.

### Alternatives

- **Alternative 1 (Pure Code-Behind in `DialogService`)**: Assign `dialog.RequestedTheme = (root.Content as FrameworkElement)?.ActualTheme ?? ElementTheme.Default;` in `DialogService.cs`.
  *Trade-off*: Violates the user's explicit preference ("giúp tôi fix bằng xaml nhé, theme thì đừng fix bằng C# behind").
- **Alternative 2 (Hardcode `RequestedTheme="Dark"` in XAML)**:
  *Trade-off*: Breaks Light mode support when the user toggles theme preferences in Settings.

### Files likely to change:
- `DataSphere/Utils/ThemeSource.cs` (new)
- `DataSphere/App.xaml`
- `DataSphere/Services/ThemeService.cs`
- `DataSphere/Views/Dialogs/ConnectionEditingDialog.xaml`
- `DataSphere/Views/Dialogs/DatabaseEditingDialog.xaml`

### Tests to add or update:
- Live UI Automation script `scripts/verify-dialog-theme.ps1` verifying both Dark Mode and Light Mode dialog rendering on `WinSta0\default`.

## Risks & Considerations

- **Binding timing**: `ContentDialog` is constructed before `ShowAsync()`. Ensuring `ThemeSource.Instance.CurrentElementTheme` is initialized prior to first dialog display guarantees no initial flash of incorrect theme.
- **Dynamic theme switching**: When user switches theme while a dialog is open (rare, but possible), `ThemeSource.NotifyAllInstances()` will instantly notify XAML bindings to switch the dialog's theme dynamically.

## Open Questions

- None. Both root cause and remediation architecture are completely validated and confirmed by the user.
