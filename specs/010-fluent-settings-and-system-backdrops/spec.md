# Feature Specification: Fluent Settings Redesign, System Backdrops & Native WinUI 3 Theme Architecture

**Feature Branch**: `010-fluent-settings-and-system-backdrops`

**Created**: 2026-10-21T14:08:45+07:00

**Status**: Draft

**Input**: User description:
> "- giúp tôi sửa lỗi settings hiển thị trông kì quặc
> - giúp tôi thêm các hiệu ứng nền: Mica, Tabbed, Acrylic
> - tái thiết background và sử dụng màu hệ thống cho đồng nhất với thiết kế của winui3 (không sử dụng style riêng)"

---

## Clarifications

### Session 2026-10-21
- Q: Chúng ta nên áp dụng quy tắc bố cục nào để khắc phục lỗi trang Cài đặt bị lệch sang phải (để trống hơn 300px bên trái)? → A: Căn giữa đối xứng tự động chuẩn Fluent Design (Đặt ScrollViewer trong Grid Stretch, StackPanel HorizontalAlignment="Center", MaxWidth="900", lề hai bên co giãn đều).

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Clean & Responsive Settings Page Layout (Priority: P1) 🎯 MVP

As a user opening the application settings, I want a cleanly structured, balanced, and visually refined Settings page adhering to Windows 11 / WinUI 3 Fluent Design 2 standards, so that setting cards are well-spaced, controls (such as ComboBoxes) are never truncated with ellipses ("Mặc đị...", "Tiếng..."), and the page adapts gracefully across window sizes.

**Why this priority**: The current Settings page suffers from awkward layout margins, floating cards with improper width constraints, truncated control labels, and a visual titlebar gap showing desktop/background artifacts. Fixing this restores immediate usability and visual quality.

**Independent Test**: Navigate to the Settings tab ("Cài đặt") in any window size (narrow 800px to ultrawide), verify that cards have clean margins and padding, ComboBoxes display full text without truncation, and sections are clearly delineated.

**Acceptance Scenarios**:

1. **Given** the application is open in English or Vietnamese, **When** the user navigates to the Settings page, **Then** all setting cards are displayed with consistent padding, rounded corners, and properly aligned icons, titles, subtitles, and controls.
2. **Given** any supported language or theme, **When** the theme or language ComboBox is rendered, **Then** full option names (e.g., "Mặc định hệ thống", "Tiếng Việt", "English") are displayed completely without text truncation or ellipsis ("...").
3. **Given** the window is resized from minimum width (800px) to maximized, **Then** settings cards resize responsively with balanced, centered horizontal margins (auto-centered within `MaxWidth="900"`, eliminating any one-sided rightward drift or empty left margins).

---

### User Story 2 - Dynamic System Backdrops (Mica, Tabbed, Acrylic, Solid) (Priority: P1)

As a user customizing application aesthetics, I want to choose between standard Windows system backdrops:
- **Mica** (standard subtle tint reflecting desktop wallpaper)
- **Tabbed** (Mica Alt, deeper contrast optimized for tabbed titlebars like File Explorer / Edge)
- **Acrylic** (Desktop Acrylic frosted glass blur)
- **Solid / None** (pure solid system color)

and have the selected backdrop take effect immediately across all windows and persist across app restarts.

**Why this priority**: System backdrops are the defining hallmark of modern Windows 11 / WinUI 3 desktop applications. Allowing the user to toggle between Mica, Tabbed (Mica Alt), Acrylic, and Solid satisfies the user's explicit design request and elevates the application to Tier-1 Windows desktop UX.

**Independent Test**: Open Settings -> Personalization -> Backdrop (Hiệu ứng nền), select "Mica", "Tabbed (Mica Alt)", "Acrylic", or "Mặc định (Solid)". Verify the window backdrop updates in real time, reflects behind tabs and views, and re-applies automatically upon restarting the application.

**Acceptance Scenarios**:

1. **Given** Windows 11 environment, **When** the user selects "Mica" in Settings, **Then** the window switches to native `MicaBackdrop` (Base) and window root transparency allows the wallpaper tint to show through.
2. **Given** Windows 11 environment, **When** the user selects "Tabbed" in Settings, **Then** the window switches to `MicaBackdrop` with `MicaKind.BaseAlt`, providing higher contrast behind the tab strip.
3. **Given** any supported Windows environment, **When** the user selects "Acrylic" in Settings, **Then** the window switches to `DesktopAcrylicBackdrop` with desktop frosted blur.
4. **Given** a selected backdrop, **When** the application is closed and reopened, **Then** the user's backdrop preference is loaded from persistent storage and applied immediately during window creation.

---

### User Story 3 - Uniform System Theme Color Architecture (Zero Custom Styles) (Priority: P2)

As a user running light, dark, or system-managed theme modes, I want all window, titlebar, tab, and page surfaces to strictly utilize WinUI 3 system theme resources (`{ThemeResource ...}`) rather than custom hardcoded styles or static color brushes, so that light/dark contrast, elevation, borders, and accessibility high-contrast themes work seamlessly without color clashes or visual glitches.

**Why this priority**: Eliminates brittle custom style rules and hardcoded backgrounds (`#F3F3F3`, static borders) that break when switching themes or using backdrops. Establishes a maintainable, standard-compliant design token hierarchy.

**Independent Test**: Toggle between Light and Dark themes across various backdrops. Verify that cards use `CardBackgroundFillColorDefaultBrush`, text uses `TextFillColorPrimaryBrush` / `TextFillColorSecondaryBrush`, borders use `CardStrokeColorDefaultBrush`, and no hardcoded opaque rectangles block the backdrop.

**Acceptance Scenarios**:

1. **Given** any active system backdrop (Mica / Acrylic), **When** inspecting the visual tree, **Then** `ShellWindow.WindowRoot` and main view containers use `Background="Transparent"`, while individual cards use semi-transparent `CardBackgroundFillColorDefaultBrush`.
2. **Given** the user changes theme from Light to Dark, **Then** cards, text, icons, borders, and backdrops update synchronously and immediately with zero hardcoded visual artifacts.
3. **Given** the titlebar drag region in `ShellWindow`, **When** the tab strip is rendered, **Then** the background is transparent and caption buttons (minimize, maximize, close) blend cleanly without black or opaque blocks.

---

### Edge Cases

- **Windows 10 Compatibility / Unsupported Backdrops**: If the operating system or graphics driver does not support Mica or Desktop Acrylic, the backdrop system MUST automatically fall back gracefully to standard solid `ApplicationPageBackgroundThemeBrush` without crashing.
- **Window Deactivation**: In WinUI 3, Mica and Acrylic automatically transition to fallback solid colors when the window loses focus. The app must allow native system behavior without conflicting manual color overrides.
- **Multiple Windows (Tab Tear-off)**: When tabs are torn off into independent windows, newly spawned windows must inherit the active system backdrop and theme preferences instantly.
- **Dynamic Localization**: All new backdrop labels ("Mica", "Tabbed (Mica Alt)", "Acrylic", "Mặc định (Solid)", card titles, and summaries) MUST be localized in `String.resx`, `String.en.resx`, and `String.vi.resx` without any hardcoded user-facing strings in C# or XAML (Constitution Principle VII).

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a "Hiệu ứng nền" / "Backdrop Effect" setting card in the Settings page under the Personalization section.
- **FR-002**: System MUST support 4 backdrop choices:
  1. `Mica`: Windows 11 Mica (Base)
  2. `Tabbed`: Windows 11 Mica Alt (`MicaKind.BaseAlt`)
  3. `Acrylic`: Desktop Acrylic (`DesktopAcrylicBackdrop`)
  4. `Solid`: Standard opaque background without backdrop effects
- **FR-003**: System MUST persist the chosen backdrop preference in `UserDataStore` (key: `ISystemBackdropType`) and restore it on subsequent launches.
- **FR-004**: System MUST apply the backdrop dynamically to the active `ShellWindow` and any secondary windows managed by `IWindowManager`.
- **FR-005**: System MUST ensure `ShellWindow.WindowRoot` has a transparent background when a backdrop is active so the backdrop illuminates through the title bar, tab strip, and page viewports.
- **FR-006**: System MUST redesign `SettingsPage.xaml` using standard WinUI 3 Fluent card guidelines:
  - Root container MUST be `<Grid HorizontalAlignment="Stretch" VerticalAlignment="Stretch">` enclosing `<ScrollViewer HorizontalAlignment="Stretch" HorizontalScrollBarVisibility="Disabled" VerticalScrollBarVisibility="Auto">`.
  - Child content MUST be `<StackPanel HorizontalAlignment="Center" MaxWidth="900" Padding="24,24,24,32" Spacing="16">` so cards are always centered symmetrically with equal margins, completely eliminating the 300px rightward drift bug.
  - Setting cards with proper icon margins, title/description vertical stacking, and right-aligned controls.
  - ComboBoxes with minimum width (>= 200px) and proper horizontal alignment so localized text is never clipped or truncated.
  - About section card styled uniformly with the setting cards.
- **FR-007**: System MUST eliminate all custom hardcoded background colors and styles in `ShellWindow` and `SettingsPage`, using exclusively standard WinUI 3 `{ThemeResource ...}` brushes.
- **FR-008**: System MUST provide complete Vietnamese and English localization entries for all backdrop names, setting titles, and descriptions without hardcoded strings.

### Key Entities

- **BackdropOptionItem**: Model representing a selectable backdrop option containing:
  - `Key`: string identifier (`"Mica"`, `"Tabbed"`, `"Acrylic"`, `"Solid"`).
  - `DisplayName`: Localized title displayed in UI ComboBox.
  - `Summary`: Localized description of the backdrop appearance.
- **IThemeService / ThemeService**: Service managing active application theme and system backdrop state, broadcasting changes to open windows.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of setting cards in the Settings page display full, untruncated text in both Vietnamese and English across all supported window resolutions (from 800x500 to maximized).
- **SC-002**: Switching between Mica, Tabbed, Acrylic, and Solid in Settings updates the window surface in under 100ms without visual tearing or application restart.
- **SC-003**: 0 hardcoded color values (Hex codes or static brushes) remain in `SettingsPage.xaml` or `ShellWindow.xaml`.
- **SC-004**: Project compiles with 0 errors and 0 warnings under .NET 10 preview.
- **SC-005**: Verified on real desktop (`WinSta0\default`) via UI Automation script with DirectComposition screenshot evidence captured in the artifacts directory.

---

## Assumptions

- Windows 11 build 22000+ natively supports `MicaBackdrop` and `MicaKind.BaseAlt`. On Windows 10, WinUI 3 automatically falls back or provides Acrylic/Solid.
- `WinUIEx.WindowEx` provides direct integration or standard `Microsoft.UI.Xaml.Window.SystemBackdrop` can be set cleanly.
- Backdrop settings are user-scoped and should be stored alongside theme and language preferences in `UserDataStore`.
