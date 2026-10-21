# Research: Fluent Settings Redesign, System Backdrops & WinUI 3 Theme Architecture

**Feature**: `010-fluent-settings-and-system-backdrops`
**Date**: 2026-10-21T14:13:00+07:00

---

## 1. Technical Decisions & Research Findings

### Decision 1: WinUI 3 Native SystemBackdrop Integration (`MicaBackdrop` & `DesktopAcrylicBackdrop`)
- **What was chosen**: Use native Windows App SDK / WinUI 3 `Microsoft.UI.Xaml.Media.SystemBackdrop` implementations directly on `WindowEx` / `ShellWindow`:
  1. `Mica (Base)`: `new MicaBackdrop { Kind = MicaKind.Base }`
  2. `Tabbed (Mica Alt)`: `new MicaBackdrop { Kind = MicaKind.BaseAlt }`
  3. `Acrylic`: `new DesktopAcrylicBackdrop()`
  4. `Solid (None)`: `null` with fallback to `ApplicationPageBackgroundThemeBrush`.
- **Rationale**:
  - `MicaKind.BaseAlt` ("Tabbed") is specifically designed by Microsoft for multi-tabbed applications (such as Windows File Explorer, Edge, Windows Terminal) to provide stronger visual contrast behind the tab strip.
  - `MicaKind.Base` provides the standard subtle wallpaper tint for modern Windows 11 apps.
  - `DesktopAcrylicBackdrop` provides the frosted blur glass effect, compatible across Windows 11 and Windows 10 (1809+).
  - Setting `Window.SystemBackdrop` is hardware-accelerated, runs on the Compositor thread, and automatically handles window focus deactivation (switching to solid when inactive) and battery saver / high-contrast modes.
- **Alternatives considered**:
  - `WinUIEx.WindowEx.Backdrop`: `WindowEx` wraps WinUI 3 backdrops, but calling native `Window.SystemBackdrop` directly provides 100% type safety and allows setting `MicaKind.BaseAlt` (Tabbed), which `WinUIEx` older wrappers might abstract away.

---

### Decision 2: Window Root Background Transparency & Layered Elevation
- **What was chosen**:
  - In `ShellWindow.xaml`, change `WindowRoot` background from hardcoded/opaque `{ThemeResource ApplicationPageBackgroundThemeBrush}` to `{x:Bind ViewModel.WindowRootBackground, Mode=OneWay}` (or `Transparent` when any system backdrop is active, and `{ThemeResource ApplicationPageBackgroundThemeBrush}` only when Solid is selected).
  - In `SettingsPage.xaml`, ensure the page background is `Transparent` so the window backdrop illuminates through the page.
- **Rationale**:
  - If the window root or page root has an opaque background, the backdrop will be rendered by the compositor beneath the XAML surface and completely obscured.
  - When backdrops are enabled, standard Fluent Design dictates that the window root is `Transparent`, while elevated cards use semi-transparent layered brushes:
    - Card Background: `{ThemeResource CardBackgroundFillColorDefaultBrush}` (lightly tinted with blur).
    - Card Stroke: `{ThemeResource CardStrokeColorDefaultBrush}`.
    - Card Hover/Subtle: `{ThemeResource CardBackgroundFillColorSecondaryBrush}`.
- **Fix for the "Weird Black Box" in Titlebar**:
  - In the user's screenshot, because `ExtendsContentIntoTitleBar = true` and `CustomDragRegion` had `Background="Transparent"`, but NO system backdrop was attached to the window, the titlebar was literally a transparent cutout to whatever window was running behind `DataSphere` on the desktop!
  - Attaching a proper `SystemBackdrop` (`Mica` or `DesktopAcrylic`) renders the system material continuously across the entire window area (including behind the title bar and tab strip), completely eliminating the transparent hole / black box glitch.

---

### Decision 3: Standard WinUI 3 Settings Card Pattern (Zero Truncation)
- **What was chosen**:
  - Standardize all setting cards in `SettingsPage.xaml`:
    - Responsive outer container: `<ScrollViewer><StackPanel MaxWidth="900" Margin="24,20,24,32" Spacing="12">`.
    - Card Container: `<Border Background="{ThemeResource CardBackgroundFillColorDefaultBrush}" BorderBrush="{ThemeResource CardStrokeColorDefaultBrush}" BorderThickness="1" CornerRadius="8" Padding="16,14">`.
    - 3-column Grid layout:
      - Column 0 (`Width="Auto"`): `FontIcon` (Size 20, Foreground `{ThemeResource TextFillColorPrimaryBrush}`, Margin `0,0,16,0`).
      - Column 1 (`Width="*"`): Text container (`TextBlock` with `BodyStrongTextBlockStyle`, description with `CaptionTextBlockStyle` Foreground `{ThemeResource TextFillColorSecondaryBrush}`, `TextWrapping="Wrap"`).
      - Column 2 (`Width="Auto"`): Control container (`ComboBox` with `MinWidth="200"`, `HorizontalAlignment="Right"`, `VerticalAlignment="Center"`).
- **Rationale**:
  - Setting `MinWidth="200"` (increased from 160) and removing cramped right padding guarantees that localized strings in Vietnamese ("Mặc định hệ thống", "Tiếng Việt") and English ("System Default", "English") have abundant room and are NEVER truncated with ellipses (`"Mặc đị..."`, `"Tiếng..."`).
  - `MaxWidth="900"` with centered alignment provides a comfortable reading measure that matches the native Windows 11 Settings application.

---

### Decision 4: Centralized Theme & Backdrop Service Extension (`IThemeService`)
- **What was chosen**:
  - Extend `IThemeService` and `ThemeService` in `DataSphere/Services/`:
    - Property: `string CurrentBackdrop { get; }` (values: `"Mica"`, `"Tabbed"`, `"Acrylic"`, `"Solid"`).
    - Method: `void SetBackdrop(string backdrop);`
    - Event: `event EventHandler<string>? BackdropChanged;`
    - Persistence: Persist in `UserDataStore.SetValue("ISystemBackdropType", backdrop)`.
  - In `ShellWindow.xaml.cs`:
    - Subscribe to `IThemeService.BackdropChanged` to apply the backdrop immediately.
    - Call `ApplyBackdrop(themeService.CurrentBackdrop)` in constructor.
  - In `SettingsViewModel.cs`:
    - Expose `ObservableCollection<BackdropOptionItem> BackdropList { get; }` and `BackdropOptionItem? SelectedBackdrop { get; set; }`.
    - Update localized strings dynamically when language changes.
- **Rationale**:
  - Decouples UI from persistence and multi-window lifecycle.
  - When secondary windows are opened (or tabs torn off into new windows via `IWindowManager`), they automatically register with `IThemeService` and apply the active backdrop consistently.

---

### Decision 5: Complete Dynamic Internationalization (Constitution Principle VII)
- **What was chosen**:
  - Add localized entries to `String.resx`, `String.en.resx`, `String.vi.resx` in UTF-8 without BOM:
    - `page_settings_backdrop_title`: "Hiệu ứng nền" / "Backdrop Effect"
    - `page_settings_backdrop_summary`: "Chọn hiệu ứng chất liệu nền hệ thống (Mica, Tabbed, Acrylic)" / "Select system background material effect (Mica, Tabbed, Acrylic)"
    - `backdrop_mica`: "Mica (Tiêu chuẩn)" / "Mica (Standard)"
    - `backdrop_tabbed`: "Tabbed (Mica Alt)" / "Tabbed (Mica Alt)"
    - `backdrop_acrylic`: "Acrylic (Kính mờ)" / "Acrylic (Frosted Glass)"
    - `backdrop_solid`: "Mặc định (Đơn sắc)" / "Solid (Default)"
- **Rationale**:
  - 100% compliant with Constitution Principle VII (Zero hardcoded user-facing strings).
