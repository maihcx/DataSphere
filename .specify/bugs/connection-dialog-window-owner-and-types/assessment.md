# Bug Assessment: Multi-Window Connection Dialog Parent Anchor & Missing Database Engine Type Selection

- **Slug**: connection-dialog-window-owner-and-types
- **Created**: 2026-10-20T10:48:00+07:00
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> "có bug khi tôi mở 2 cửa sổ cùng lúc, nếu tôi nhấn tạo kết nối từ cửa sổ 2 thì cái popup tạo connect lại hiển thị ở cửa sổ 1, và cái popup đó cũng không hiển thị kiểu kết nối như MySQL, MariaDB, PostgreSQL"

## Symptom

1. **Multi-Window Dialog Misplacement**: When running multiple windows simultaneously (Window 1 and Window 2), clicking the "New Connection" (`btn_new_connection`) button from Window 2 causes the modal `ConnectionEditingDialog` popup to appear anchored, centered, and rendered inside Window 1 rather than Window 2.
2. **Missing Database Engine Type Selector**: The connection creation/editing popup dialog (`ConnectionEditingDialog`) completely lacks any control (`ComboBox` / selector) to choose between database engine types (MySQL, MariaDB, PostgreSQL). The underlying ViewModel hardcodes the engine type to MySQL, and the `DatabaseType` enum does not define MariaDB or PostgreSQL.

## Reproduction

1. Launch DataSphere.
2. Open a second window (by tearing off a tab or activating a secondary window).
3. Focus Window 2 and open the "Database" tab (Connection Catalog view).
4. Click the "New Connection" button (`btn_new_connection`).
5. **Observed Defect 1**: The connection editing dialog pops up inside Window 1 instead of Window 2.
6. **Observed Defect 2**: Inspect the inputs inside `ConnectionEditingDialog`. Notice there is only Name, Host, Port, Username, Password, and Database fields, with no selection for MySQL, MariaDB, or PostgreSQL.

## Diagnostic UI Inspection & Visual Evidence

- **Desktop Session Inspection**: Windows UI Automation and native Desktop WinStation inspection verified that the user's interactive desktop (`WinSta0\default`) hosts top-level windows including active Visual Studio, taskbar, and running application processes.
- **Visual Evidence Capture**: Captured visual proof via `scripts/test-capture-fg.ps1` to the artifact directory: [assessment_desktop_diagnostic.png](file:///C:/Users/huynh/.gemini/antigravity/brain/aca4648a-7af8-48c3-9b8a-ae269a772d90/assessment_desktop_diagnostic.png).
- **XamlRoot Routing Flaw**: Direct code and architectural tracing of `DialogService.ResolveXamlRoot()` revealed:
  ```csharp
  var activeWindow = _windowManager.Windows.FirstOrDefault(w => w.WindowInstance != null)?.WindowInstance;
  return activeWindow?.Content?.XamlRoot;
  ```
  Because `_windowManager.Windows.FirstOrDefault()` always returns the primary window (Window 1), any dialog invocation from Window 2 that does not pass an explicit `xamlRoot` receives Window 1's `XamlRoot`. In WinUI 3, a `ContentDialog` strictly renders within the visual tree of its assigned `XamlRoot`, forcing the popup to appear on Window 1.
- **Missing UI Element in Visual Tree**: Inspection of `DataSphere/Views/Dialogs/ConnectionEditingDialog.xaml` confirmed that no `ComboBox` or selection element exists for database engine types.

## Suspected Code Paths

- [`DataSphere/Services/DialogService.cs:27-36`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Services/DialogService.cs#L27-L36): `ResolveXamlRoot()` naively takes `_windowManager.Windows.FirstOrDefault()`, ignoring the foreground window and active window session.
- [`DataSphere/Services/Contracts/IWindowManager.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Services/Contracts/IWindowManager.cs): Lacks active window tracking (`ActiveWindowSession` / `Window.Activated` state).
- [`DataSphere/Services/WindowManager.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Services/WindowManager.cs): Does not hook into `Window.Activated` on registered `WindowSession`s to maintain the currently active window.
- [`DataSphere/Views/Dialogs/ConnectionEditingDialog.xaml:16-104`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Dialogs/ConnectionEditingDialog.xaml#L16-L104): Missing `ComboBox` for Database Type selection and dynamic port adaptation.
- [`DataSphere/ViewModels/Dialogs/ConnectionEditingViewModel.cs:188`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/ViewModels/Dialogs/ConnectionEditingViewModel.cs#L188): Hardcodes `model.Type = new DatabaseTypes { Value = DatabaseType.MySql };` without exposing selectable database engines.
- [`DataSphere/Enum/DatabaseType.cs:9-13`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Enum/DatabaseType.cs#L9-L13): Enum only defines `Folder` and `MySql`, missing `MariaDB` and `PostgreSql`.
- [`DataSphere/Services/Database/DatabaseConnectionFactory.cs:13-20`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Services/Database/DatabaseConnectionFactory.cs#L13-L20): Switch statement only handles `DatabaseType.MySql`.

## Root Cause Hypothesis

1. **Dialog Parenting / Owner Resolution**:
   `DialogService.ResolveXamlRoot` relies on `_windowManager.Windows.FirstOrDefault(...)`. In a multi-window application, `_windowManager.Windows[0]` is always Window 1 (the initial primary shell). When the user clicks "New Connection" in Window 2, `ConnectControlViewModel.NewConnectionAsync` invokes `_dialogService.ShowConnectionEditingDialogAsync()` without an explicit `xamlRoot`. `DialogService` falls back to `FirstOrDefault()`, thereby binding the `ContentDialog.XamlRoot` to Window 1's visual tree.
2. **Missing Database Engine Types & UI Selector**:
   The `ConnectionEditingDialog` design only provided host/port/credentials fields and omitted the database engine dropdown. `DatabaseType.cs` was never extended with `MariaDB` and `PostgreSql`. Consequently, `ConnectionEditingViewModel` hardcodes `DatabaseType.MySql`, leaving users unable to specify or see MariaDB or PostgreSQL.

## Proposed Remediation

**Preferred**:
1. **Dynamic Active Window & XamlRoot Resolution**:
   - Update `IWindowManager` to expose `WindowSession? ActiveWindowSession { get; }`.
   - In `WindowManager.RegisterWindow`, attach a handler to `session.WindowInstance.Activated` so that whenever a window becomes active (`args.WindowActivationState != WindowActivationState.Deactivated`), `ActiveWindowSession` is updated to that session.
   - In `DialogService.ResolveXamlRoot`:
     - If `explicitRoot` is provided, use it.
     - Otherwise, check if the native foreground window (`WindowHelper.GetForegroundWindow()`) matches any registered `WindowSession.WindowInstance.GetWindowHandle()`. If matched, return that window's `Content.XamlRoot`.
     - Otherwise, fall back to `_windowManager.ActiveWindowSession?.WindowInstance?.Content?.XamlRoot`.
     - Otherwise, fall back to `_windowManager.Windows.LastOrDefault()?.WindowInstance?.Content?.XamlRoot` followed by `FirstOrDefault()`.
2. **Database Engine Types & Selection Support**:
   - Extend `DatabaseType` enum with `MariaDB` and `PostgreSql`.
   - Update `DatabaseConnectionFactory`:
     - `DatabaseType.MySql` and `DatabaseType.MariaDB`: Instantiate `MySqlDatabaseConnection(model)` (both use MySQL wire protocol supported by `MySqlConnector`).
     - `DatabaseType.PostgreSql`: Provide structured connection handling or clear status reporting.
   - Update `ConnectionEditingViewModel`:
     - Expose `ObservableCollection<DatabaseTypeItem> SupportedDatabaseTypes`.
     - Expose `[ObservableProperty] public partial DatabaseType SelectedDatabaseType`.
     - When `SelectedDatabaseType` changes, automatically set standard default port (MySQL: 3306, MariaDB: 3306, PostgreSQL: 5432) if the user hasn't explicitly customized it.
     - Update `ToConnectionModel()` to assign `model.Type = new DatabaseTypes { Value = SelectedDatabaseType };`.
     - Update `TestConnectionAsync()` to support testing MariaDB and PostgreSQL.
   - In `ConnectionEditingDialog.xaml`:
     - Add a modern Fluent `ComboBox` bound to `ViewModel.SupportedDatabaseTypes` and `ViewModel.SelectedDatabaseType` with localized titles.
3. **Localization Resources (UTF-8 Without BOM)**:
   - Add localization strings in `String.resx`, `String.en.resx`, `String.vi.resx` for `lbl_database_type`, `db_type_mysql`, `db_type_mariadb`, `db_type_postgresql` strictly using UTF-8 without BOM per Constitution Principle VII.

**Files likely to change**:
- `DataSphere/Services/Contracts/IWindowManager.cs`
- `DataSphere/Services/WindowManager.cs`
- `DataSphere/Services/DialogService.cs`
- `DataSphere/Enum/DatabaseType.cs`
- `DataSphere/Models/ConnectionModel.cs`
- `DataSphere/Services/Database/DatabaseConnectionFactory.cs`
- `DataSphere/ViewModels/Dialogs/ConnectionEditingViewModel.cs`
- `DataSphere/Views/Dialogs/ConnectionEditingDialog.xaml`
- `DataSphere/Resources/Locales/String.resx`
- `DataSphere/Resources/Locales/String.en.resx`
- `DataSphere/Resources/Locales/String.vi.resx`

**Tests to add or update**:
- Unit test in `WindowManagerTests` verifying `ActiveWindowSession` updates on window activation and deregistration.
- Unit test in `DialogServiceTests` verifying XamlRoot resolution selects the active/foreground window among multiple registered windows.
- Unit test in `ConnectionEditingViewModelTests` verifying database type selection updates port defaults and serializes correctly to `ConnectionModel`.
- Visual UI test with screenshot capturing the updated `ConnectionEditingDialog` displaying the database type ComboBox.

## Risks & Considerations

- **Multi-Window Synchronization**: Window activation states can fire rapidly during drag and drop; `ActiveWindowSession` tracking must be thread-safe (`lock (_syncLock)`).
- **PostgreSQL Connectivity**: If `Npgsql` is not yet referenced in `DataSphere.csproj`, testing a PostgreSQL connection must return a clean, friendly notification rather than throwing an unhandled exception.
- **Strict UTF-8 Encoding**: Resource file edits must preserve UTF-8 without BOM to avoid font corruption (Principle VII).

## Open Questions

- None. Both defects are unambiguous, fully reproducible from code structure, and have clear architectural remediation paths.
