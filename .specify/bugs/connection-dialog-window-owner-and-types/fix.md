# Bug Fix: Multi-Window Connection Dialog Parent Anchor & Missing Database Engine Type Selection

- **Slug**: connection-dialog-window-owner-and-types
- **Fixed**: 2026-10-20T10:58:30+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Resolved the multi-window dialog misplacement defect where connection dialogs launched from secondary windows rendered inside the primary window, and integrated full database engine selection support (MySQL, MariaDB, PostgreSQL) into `ConnectionEditingDialog` with automatic port switching, clean UTF-8 localization, and socket diagnostics.

## Changes

| File | Change | Notes |
|------|--------|-------|
| [`DataSphere/Services/Contracts/IWindowManager.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Services/Contracts/IWindowManager.cs) | modified | Added `ActiveWindowSession` property to track the focused window. |
| [`DataSphere/Services/WindowManager.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Services/WindowManager.cs) | modified | Subscribed to `Window.Activated` to dynamically update `ActiveWindowSession`, with fallback on window unregistration. |
| [`DataSphere/Utils/WindowHelper.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Utils/WindowHelper.cs) | modified | Made `GetForegroundWindow()` public static with XML doc comments. |
| [`DataSphere/Services/DialogService.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Services/DialogService.cs) | modified | Enhanced `ResolveXamlRoot()` to query foreground window handle, falling back to `ActiveWindowSession`, last window, and primary window. |
| [`DataSphere/Enum/DatabaseType.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Enum/DatabaseType.cs) | modified | Added `MariaDB` and `PostgreSql` to `DatabaseType` enum with XML doc comments. |
| [`DataSphere/Models/ConnectionModel.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Models/ConnectionModel.cs) | modified | Added `Database` property; updated `IconGlyph` and context menus for MariaDB and PostgreSQL. |
| [`DataSphere/Services/Database/DatabaseConnectionFactory.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Services/Database/DatabaseConnectionFactory.cs) | modified | Added `MariaDB` support (using `MySqlDatabaseConnection`) and descriptive handling for PostgreSQL. |
| [`DataSphere/ViewModels/Dialogs/ConnectionEditingViewModel.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/ViewModels/Dialogs/ConnectionEditingViewModel.cs) | modified | Added `DatabaseTypeOption`, `AvailableDatabaseTypes`, `SelectedDatabaseType`, automatic port adjustment (3306/5432), and socket reachability testing for PostgreSQL. |
| [`DataSphere/Views/Dialogs/ConnectionEditingDialog.xaml`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Dialogs/ConnectionEditingDialog.xaml) | modified | Added Fluent `ComboBox` for Database Type selection bound to `AvailableDatabaseTypes`. |
| [`DataSphere/Resources/Locales/String.resx`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Resources/Locales/String.resx) | modified | Added `lbl_database_type` and `msg_test_pg_socket`. |
| [`DataSphere/Resources/Locales/String.en.resx`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Resources/Locales/String.en.resx) | modified | Added `lbl_database_type` and `msg_test_pg_socket`. |
| [`DataSphere/Resources/Locales/String.vi.resx`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Resources/Locales/String.vi.resx) | modified | Added `lbl_database_type` and `msg_test_pg_socket` with strict UTF-8 without BOM encoding. |
| [`scratch/VerifyConnectionDialog/`](file:///d:/DEV/C%23DOTNET/DataSphere/scratch/VerifyConnectionDialog/) | added | Created 28-assertion verification test suite validating multi-window tracking, database type selection, and encoding. |

## Diff Highlights

### Dynamic Active Window & Foreground XamlRoot Resolution
```csharp
private XamlRoot? ResolveXamlRoot(object? explicitRoot = null)
{
    if (explicitRoot is XamlRoot xamlRoot) return xamlRoot;

    // Match native foreground window to registered window sessions
    IntPtr fgHandle = WindowHelper.GetForegroundWindow();
    if (fgHandle != IntPtr.Zero)
    {
        var fgWindow = _windowManager.Windows
            .FirstOrDefault(w => w.WindowInstance != null && w.WindowInstance.GetWindowHandle() == fgHandle)
            ?.WindowInstance;

        if (fgWindow?.Content?.XamlRoot != null) return fgWindow.Content.XamlRoot;
    }

    var activeSessionWindow = _windowManager.ActiveWindowSession?.WindowInstance;
    if (activeSessionWindow?.Content?.XamlRoot != null) return activeSessionWindow.Content.XamlRoot;

    var lastWindow = _windowManager.Windows.LastOrDefault(w => w.WindowInstance != null)?.WindowInstance;
    if (lastWindow?.Content?.XamlRoot != null) return lastWindow.Content.XamlRoot;

    var activeWindow = _windowManager.Windows.FirstOrDefault(w => w.WindowInstance != null)?.WindowInstance;
    return activeWindow?.Content?.XamlRoot;
}
```

### Database Type Selector ComboBox (`ConnectionEditingDialog.xaml`)
```xml
<!-- Database Engine Type -->
<ComboBox
    Header="{Binding [lbl_database_type], Source={StaticResource Localization}, Mode=OneWay}"
    ItemsSource="{x:Bind ViewModel.AvailableDatabaseTypes}"
    SelectedItem="{x:Bind ViewModel.SelectedDatabaseType, Mode=TwoWay}"
    HorizontalAlignment="Stretch" />
```

## Tests Added or Updated

- `scratch/VerifyConnectionDialog/Program.cs` (28 checks):
  - `TestDatabaseTypesEnum`: Verified `MySql`, `MariaDB`, `PostgreSql` defined on `DatabaseType`.
  - `TestConnectionEditingViewModel`: Verified 3 engine options, auto-port switching between 3306 and 5432, serialization to `ConnectionModel`, and round-trip initialization from existing models.
  - `TestDatabaseConnectionFactory`: Verified MySQL and MariaDB instantiation via `MySqlDatabaseConnection` and informative exception for PostgreSQL.
  - `TestWindowManagerActiveTracking`: Verified `ActiveWindowSession` tracking across multi-window registration and deregistration.
  - `TestResxIntegrity`: Verified strict UTF-8 encoding of `lbl_database_type` ("Loại cơ sở dữ liệu") with zero double-byte Mojibake.

## Local Verification

- Compilation: `dotnet build DataSphere\DataSphere.csproj -c Debug` → 0 Warning(s), 0 Error(s).
- Suite `VerifyConnectionDialog`: `dotnet run --project scratch\VerifyConnectionDialog\VerifyConnectionDialog.csproj` → 28 passed, 0 failed.
- Regression Suite `VerifyDatabaseView`: 14 passed, 0 failed.
- Regression Suite `VerifyTabTransfer`: 13 passed, 0 failed.
- Regression Suite `VerifyConnectionStorage`: 14 passed, 0 failed.
- Bridge Readiness: `powershell -ExecutionPolicy Bypass -File .\.specify\extensions\speckit-superpowers-bridge\scripts\powershell\bridge-status.ps1 -Readiness` → PASS.

## Deviations from Assessment

- None. All proposed remediations were implemented exactly as specified in `assessment.md`.

## Follow-ups

- Run `/speckit-bug-test slug=connection-dialog-window-owner-and-types` to execute the full verification report and capture visual UI evidence per Constitution Principle VIII.
