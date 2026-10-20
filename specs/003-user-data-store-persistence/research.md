# Phase 0: Research & Decision Log — User Preferences & State Persistence

**Feature**: `003-user-data-store-persistence`
**Date**: 2026-10-20
**Status**: Completed

## 1. Window Placement Persistence in Unpackaged WinUI 3

### Context & Problem
In WinUI 3 unpackaged mode (`<WindowsPackageType>None</WindowsPackageType>`), built-in `WinUIEx.PersistenceId` relies on `Windows.Storage.ApplicationData.Current.LocalSettings`, which fails with `InvalidOperationException` due to the lack of package identity. The application requires an independent file-based persistence mechanism using `UserDataStore`.

### Research & Findings
- `WinUIEx.WindowEx` wraps an underlying `Microsoft.UI.Windowing.AppWindow`.
- The physical position is accessible via `AppWindow.Position` (`PointInt32 { X, Y }`).
- The dimensions are accessible via `AppWindow.Size` (`SizeInt32 { Width, Height }`).
- The window state is controlled by `AppWindow.Presenter` (`OverlappedPresenter`).
  - Maximized check: `presenter?.State == OverlappedPresenterState.Maximized`.
  - Normal check: `presenter?.State == OverlappedPresenterState.Restored`.
- Restoration procedure:
  - If `IsWindow_Maximized` is true: invoke `presenter.Maximize()`.
  - If normal: invoke `AppWindow.MoveAndResize(new RectInt32(x, y, width, height))`.
- Screen boundary sanitization:
  - If a window was saved on a secondary display that is now disconnected, the saved coordinates `(X, Y)` could place the window completely off-screen.
  - Solution: Use Win32 `GetSystemMetrics` or `MonitorFromPoint` (`MONITOR_DEFAULTTONEAREST`) to verify that at least a portion of the window intersects an active display monitor. If not, fallback to centering on the primary monitor.

### Decisions
- **Decision**: Implement `WindowPlacementService` (or helper methods in `ShellWindow.xaml.cs` / `WindowSession`) that reads/writes `Window_Left`, `Window_Top`, `Window_Width`, `Window_Height`, and `IsWindow_Maximized` to `UserDataStore`.
- **Rationale**: Replicates the exact behavior previously proven on `main` while utilizing modern `AppWindow` APIs appropriate for WinUI 3.

---

## 2. Dynamic Theme Restoration & Real-time Live Switching

### Context & Problem
In `SettingsPage`, users can choose between "Light", "Dark", and "Default" (System Auto). When selected, `UserDataStore.SetValue("IThemeType", value)` is stored, but the visual theme is neither applied immediately to open windows nor restored during application launch.

### Research & Findings
- In WinUI 3, application theming can be configured per window content via `FrameworkElement.RequestedTheme`:
  - `ElementTheme.Light`
  - `ElementTheme.Dark`
  - `ElementTheme.Default` (inherits from Windows system setting).
- Setting `rootGrid.RequestedTheme` on `ShellWindow` dynamically cascades through all visual controls in that window without requiring a process restart.
- Titlebar caption button colors (`AppWindow.TitleBar.ButtonForegroundColor`, etc.) must be adjusted to match the requested theme so that titlebar buttons remain clearly legible in both Light and Dark themes.
- For multi-window sessions (such as torn-off tabs), all active windows registered in `IWindowManager` must receive the theme update simultaneously.

### Decisions
- **Decision**: Create an `IThemeService` (registered in DI as a Singleton) responsible for reading `IThemeType` from `UserDataStore`, applying it to newly opened windows upon initialization, and broadcasting live theme changes across all registered `WindowSession` windows.
- **Rationale**: Centralizes theme orchestration, decouples ViewModels from concrete `Window` instances (complying with Constitution Principle I), and guarantees instant multi-window synchronization.

---

## 3. Language Preference Startup Restoration

### Context & Problem
Language switching is handled at runtime via `LanguageBase.SetLanguage(code)` which calls `UserDataStore.SetValue("Language", code)`. However, during application startup, `LanguageBase.GetSetupLanguage()` is never invoked to initialize `TranslationSource.Instance.CurrentCulture`. As a result, the application restarts in the system culture rather than the user's persisted language preference.

### Research & Findings
- `TranslationSource.Instance.CurrentCulture` drives string resolution across all views through compiled/dynamic bindings.
- During early startup in `ApplicationHostService` (or `App.OnLaunched`), calling `TranslationSource.Instance.CurrentCulture = LanguageBase.GetSetupLanguage()` establishes the active culture before any UI windows or tabs are constructed.
- `GetSetupLanguage()` must be guarded against null/empty entries or invalid culture tags, defaulting to `CultureInfo.CurrentUICulture` or English (`"en"`).

### Decisions
- **Decision**: Ensure `LanguageBase.GetSetupLanguage()` safely retrieves `"Language"` from `UserDataStore`, and invoke it during `ApplicationHostService.StartAsync()` before `ShellWindow` activation.
- **Rationale**: Guarantees all tabs, dashboard cards, and navigation items render in the user's chosen language from the first displayed frame (Constitution Principle VII).

---

## 4. Robustness & Thread-Safety of UserDataStore

### Context & Problem
`UserDataStore` performs file I/O to `%LOCALAPPDATA%\DataSphere\userdata.json`. If multiple threads write concurrently, or if the file is corrupted, unhandled exceptions could crash the application.

### Research & Findings
- Dedicated static synchronization lock (`object _syncLock = new()`) prevents race conditions between in-memory dictionary reads/writes and disk writes.
- File saving should use an atomic write pattern (writing to a temporary file and moving, or synchronizing under the lock) to prevent partial writes during sudden power loss.
- In `GetValue<T>`, invalid JSON or missing keys must return sensible defaults (`default(T)`) without throwing exceptions.
- `SetValuePass` / `GetValuePass` correctly encrypts/decrypts strings using `PasswordEncryptor` (Constitution Principle III).

### Decisions
- **Decision**: Harden `UserDataStore` with strict null checks, thread synchronization on all operations, and error logging instead of unhandled crashes.
- **Rationale**: Fulfills Constitution Principle III & IV, ensuring zero credential leaks and 100% startup reliability.
