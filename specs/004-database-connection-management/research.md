# Research: Database Connection Management & WinUI 3 Restoration

**Feature**: `004-database-connection-management`  
**Date**: 2026-10-20  
**Status**: Completed  

## 1. Executive Summary & Goals

This research addresses the restoration of the complete database management and connectivity subsystem in DataSphere, moving from the current placeholder view to full feature parity with the legacy platform (`main`), fully modernized for **.NET 10** and **WinUI 3 (Windows App SDK 2.5+)**.

Key architectural restoration objectives:
1. **Inner Tab Navigation**: Embed an inner `TabView` inside `DatabasePage`. Tab 0 is an anchored, non-closable "Connections" view (`ConnectViewControl`). Subsequent tabs are created dynamically whenever a connection session is opened (`DatabaseViewControl`).
2. **Native WinUI 3 ContentDialog Architecture**: Modal dialogs (`ConnectionEditingDialog`, `DatabaseEditingDialog`, and confirmation prompts) MUST use native `Microsoft.UI.Xaml.Controls.ContentDialog` with `dialog.XamlRoot = activeWindow.Content.XamlRoot` per Microsoft PowerToys WinUI 3 migration standards.
3. **Database Engine & Asynchronous Schema Discovery**: Restore `DatabaseConnectionFactory`, `IDatabaseConnection`, and `MySqlDatabaseConnection` for asynchronous non-blocking connection testing, session lifecycle, and schema tree discovery (Databases, Tables, Views, Functions, Procedures).
4. **Table Data Viewport with Pagination**: Implement `DataViewControl` with high-performance virtualized rendering, column headers, and pagination (100, 500, 1000 rows) via parameterized SQL queries (`LIMIT ... OFFSET ...`).
5. **Secure Credential Storage & Encryption**: Enforce zero-plain-text storage in `%LOCALAPPDATA%\DataSphere\connections.json` using `PasswordEncryptor` (AES-CBC), maintaining complete security compliance (Constitution Principle III).
6. **Zero Hardcoded Strings & Dynamic i18n**: All UI text and ViewModel notifications MUST bind dynamically to `TranslationSource` and `.resx` localization bundles (Constitution Principle VII).

---

## 2. Topic 1: Inner Tab Workspace (`DatabasePage` & `TabView`)

### Context & Problem
In the WPF implementation, `DatabasePage` hosted a custom `TabsControl` bound to `TabsViewer`. In WinUI 3, `TabView` is the native standard control for multi-tab user experiences. Furthermore, the application already has an outer `ShellWindow` hosting top-level Chrome tabs (Home, Settings, Database). The user explicitly clarified that inside `DatabasePage`, an inner tab control should be used:
- Tab 0: Non-closable "Connections" (`ConnectViewControl`).
- Tab 1..N: Closable connection sessions (`DatabaseViewControl`).

### Architectural Design
- **ViewModel**: `DatabaseViewModel` holds `ObservableCollection<InnerTabItemModel> InnerTabs` and `InnerTabItemModel? SelectedInnerTab`.
- **InnerTabItemModel**:
  - `Header`: Localized title (e.g., "Connections" or connection name like "Localhost (MySQL)").
  - `IconGlyph`: Fluent icon glyph (e.g., `\uE774` for MySQL, `\uE838` for folders).
  - `Content`: The instantiated UserControl (`ConnectViewControl` or `DatabaseViewControl`).
  - `IsClosable`: `false` for Tab 0, `true` for connection tabs.
  - `ConnectionKey`: Unique identifier matching `ConnectionModel.Key`.
- **Closing Behavior**: When a connection tab close request fires (`TabCloseRequested`), the corresponding `DatabaseViewControl` and its underlying `IDatabaseConnection` are gracefully disconnected and disposed (`IDisposable`), preventing connection leaks.

---

## 3. Topic 2: WinUI 3 `ContentDialog` & Dialog Service

### WinUI 3 `XamlRoot` Invariant
In WinUI 3, unlike WPF where dialogs could implicitly attach to `Application.Current.MainWindow`, invoking `ContentDialog.ShowAsync()` without assigning `dialog.XamlRoot` throws:
```text
System.InvalidOperationException: ContentDialog requires a XamlRoot to be set.
```
According to Microsoft PowerToys migration guidelines (`wpf-to-winui3-migration`), the correct pattern is:
```csharp
var dialog = new ConnectionEditingDialog(viewModel)
{
    XamlRoot = xamlRoot, // Obtained from calling control's XamlRoot or active Window.Content.XamlRoot
    Title = LanguageBase.GetLangValue("dialog_connectset_title"),
    PrimaryButtonText = LanguageBase.GetLangValue("save_title"),
    CloseButtonText = LanguageBase.GetLangValue("close_title"),
    DefaultButton = ContentDialogButton.Primary
};
var result = await dialog.ShowAsync();
```

### Dialog Service / Helper Abstraction
To keep ViewModels decoupled from WinUI visual types (`XamlRoot`, `ContentDialog`) per Clean MVVM (Constitution Principle I):
- Views (`ConnectViewControl`, `DatabaseViewControl`, `DatabasePage`) manage UI interaction and instantiate dialogs, or use an `IDialogService` that accesses the active window's `XamlRoot` via `IWindowManager`.
- Inside `ConnectionEditingDialog`:
  - Contains input fields for Name, Server Type (MySQL/MariaDB), Host, Port (default 3306), Username, Password, and default Database.
  - Features an asynchronous "Test Connection" button with an inline `ProgressRing` and status message (Success/Failure badge), satisfying FR-004.
  - Validates mandatory fields before allowing Primary Button click (`IsPrimaryButtonEnabled`).

---

## 4. Topic 3: Connection Hierarchy & Persistent Storage

### Data Model & Tree Representation
- `ConnectionModel` represents a connection or folder item. It supports recursive `Children` for folder nesting.
- Context menu actions:
  - For Folder: "New Connection" (`ctx_mysql_title`), "Rename" (`ctx_rename_title`), "Delete" (`ctx_delete_title`).
  - For MySQL Connection: "Connect" (`ctx_opencnn_title`), "Edit" (`ctx_edit_title`), "Rename" (`ctx_rename_title`), "Delete" (`ctx_delete_title`).
- Empty State: When `ConnectItems.Count == 0`, `ConnectViewControl` displays an empty state banner with icon `\uE774`, localized title, description, and a prominent "New Connection" button.

### Encryption at Rest (`connections.json`)
- Path: `%LOCALAPPDATA%\DataSphere\connections.json`.
- `ConnectionStorageService.SaveAsync(ObservableCollection<ConnectionModel>)`:
  - Recursively maps `ConnectionModel` instances.
  - Encrypts `Password` using `PasswordEncryptor.Encrypt(plainText)` before saving to disk.
- `ConnectionStorageService.LoadAsync()`:
  - Deserializes JSON from disk.
  - Decrypts `Password` using `PasswordEncryptor.Decrypt(cipherText)`.
  - Tolerates missing/corrupted files gracefully by returning an empty collection without throwing unhandled exceptions.

---

## 5. Topic 4: Database Object Explorer (`DatabaseViewControl`)

### Schema Hierarchy
When a connection is established:
1. `RootConnections` contains `ConnectionRoot` (displaying connection name and server status).
2. Level 1: Databases/Schemas retrieved via `connection.GetAllDatabasesAsync()`.
3. Level 2: Categories under each database:
   - Tables (`dbinf_tables_title`, `\uE82D`)
   - Views (`dbinf_views_title`, `\uE8B9`)
   - Stored Procedures (`dbinf_sps_title`, `\uE943`)
   - Functions (`dbinf_fncs_title`, `\uE8B7`)
   - Triggers (`dbinf_triggers_title`, `\uE713`)
   - Events (`dbinf_events_title`, `\uE787`)
4. Level 3: Tables under the Tables category, lazily loaded upon expanding or selecting the database.

### Actions & Context Menus
- On `ConnectionRoot`: "New Database" (`dbinf_database_title`), "Refresh" (`btn_refresh`), "Disconnect" (`btn_disconnect`).
- On `DatabaseInfo`: "Open", "Edit Database", "Drop Database" (with confirmation dialog), "Refresh".
- On `Table`: Double-click or select loads table rows into `DataViewControl` in the right panel.

---

## 6. Topic 5: Table Data Viewport & Pagination (`DataViewControl`)

### Native WinUI 3 Implementation
In WinUI 3, rather than introducing heavy third-party DataGrid packages with version conflicts, `DataViewControl` implements a clean, high-performance table viewer:
- **Header Row**: Dynamic column headers generated from table metadata (`Column.Name`, `Column.DataType`).
- **Data Rows**: `ListView` rendering dynamic row items (`TableRowData`), virtualized with `ScrollViewer`.
- **Pagination**:
  - Row limit selector: ComboBox with options (100, 500, 1000 rows).
  - Navigation: First, Previous, Next, Last page buttons.
  - Page indicator: e.g., "Page 1 of 42 (4,180 records)".
  - Refresh button: re-executes paginated query (`SELECT * FROM db.table LIMIT @Limit OFFSET @Offset`).
- **Performance & Memory Protection**:
  - Memory consumption is capped to the page size.
  - Uses `MySqlDataReader` asynchronously to stream results into `ObservableCollection<TableRowData>`.

---

## 7. Topic 6: Zero Hardcoded Strings & Dynamic Internationalization (i18n)

### Constitutional Rule (Principle VII)
All strings in C# and XAML must be dynamically localized:
- XAML: `Text="{Binding [key], Source={StaticResource Localization}, Mode=OneWay}"`.
- C#: `LanguageBase.GetLangValue(key, args)` or hook `TranslationSource.Instance.PropertyChanged`.
- Required resource bundles: `String.resx`, `String.en.resx`, `String.vi.resx`.
- Newly introduced keys:
  - `btn_test_connection`, `btn_new_connection`, `msg_test_connection_success`, `msg_test_connection_failed`.
  - `pagination_rows_per_page`, `pagination_page_info`, `btn_refresh_table`, `lbl_total_records`.
  - `dialog_delete_connection_title`, `dialog_delete_connection_message`.

---

## 8. Summary of Technical Decisions

| Aspect | Decision | Rationale |
|---|---|---|
| **Inner Tab Control** | Native WinUI 3 `TabView` inside `DatabasePage` | Matches legacy baseline; Tab 0 = non-closable connections, Tab 1..N = closable sessions. |
| **Dialog Architecture** | Subclassed WinUI 3 `ContentDialog` with explicit `XamlRoot` | Prevents `InvalidOperationException` and aligns with PowerToys standard. |
| **Database Driver** | `MySqlConnector` async non-blocking queries | High performance, maintains 60 FPS, supports `CancellationToken`. |
| **Password Storage** | `PasswordEncryptor` (AES-CBC) in `ConnectionStorageService` | Zero plaintext credentials on disk, 100% compliant with Constitution Principle III. |
| **Table Data Viewing** | Native `ListView` with dynamic columns & paging | Avoids deprecated/incompatible packages; ensures instant load and minimal memory footprint. |
| **Localization** | `TranslationSource` with indexer bindings | Zero hardcoded user strings; instant runtime language switching. |
