# Implementation Plan: Database Connection Management & Selection

**Branch**: `004-database-connection-management` | **Date**: 2026-10-20 | **Spec**: [`spec.md`](spec.md)

**Input**: Feature specification from [`specs/004-database-connection-management/spec.md`](spec.md)

---

## Summary

This plan restores the full database connection management and exploration ecosystem in DataSphere, transitioning from the temporary placeholder view to complete architectural feature parity with the legacy platform (`main`), fully modernized for **.NET 10** and **WinUI 3 (Windows App SDK 2.5+)**.

Key architectural deliverables:
1. **Inner Tab Workspace**: Inside `DatabasePage`, embed a WinUI 3 `TabView`. Tab 0 is an anchored, non-closable "Connections" explorer (`ConnectViewControl`). Subsequent tabs represent active database sessions (`DatabaseViewControl`) that can be individually closed and disposed.
2. **Native WinUI 3 ContentDialogs**: Re-implement `ConnectionEditingDialog` and `DatabaseEditingDialog` using native `ContentDialog` with mandatory `dialog.XamlRoot = activeWindow.Content.XamlRoot` binding per Microsoft PowerToys standards.
3. **Transparent Password Encryption**: Persist connection configurations to `%LOCALAPPDATA%\DataSphere\connections.json` with AES-CBC encryption using `PasswordEncryptor`, ensuring zero plaintext credentials on disk.
4. **Asynchronous Non-Blocking Engine**: Re-integrate `MySqlConnector` for async connection tests (<5s timeout), schema introspection (Databases, Tables, Views, Functions, Procedures), and connection disposal without freezing the UI thread.
5. **Paginated Table Viewport (`DataViewControl`)**: High-performance tabular viewer in the right panel displaying columns, virtualized rows, and pagination controls (100, 500, 1000 rows).
6. **Strict Constitution Compliance**: 100% US English XML doc comments, zero hardcoded user-facing strings (dynamic binding to `TranslationSource` with English and Vietnamese resource bundles), and 0-error compilation.

---

## Technical Context

**Language/Version**: C# (LangVersion `preview`), .NET 10 (`net10.0-windows10.0.26100.0`).  
**Primary Dependencies**: `Microsoft.WindowsAppSDK` (v2.5.1), `WinUIEx` (v2.9.3), `CommunityToolkit.Mvvm` (v8.4.0), `Microsoft.Extensions.Hosting` (v10.0.0), `MySqlConnector` (v2.4.0), `System.IO.Hashing` (v10.0.0).  
**Storage**: `%LOCALAPPDATA%\DataSphere\connections.json` (encrypted credentials with AES-CBC).  
**Testing**: Headless verification console harness (`scratch/VerifyUserDataStore/`), manual WinUI 3 interactive scenarios.  
**Target Platform**: Windows 10/11 desktop (x64, ARM64).  
**Project Type**: Windows App SDK (WinUI 3) modern desktop application.  
**Performance Goals**: 60 FPS UI responsiveness (<16ms frame time); database connection test timeout <5s; table data pagination query <500ms for 100,000+ row tables.  
**Constraints**: Zero plain-text passwords in storage or logs; zero blocking Win32 modal calls (`MessageBox.Show`); explicit `XamlRoot` assignment for every `ContentDialog`.  
**Scale/Scope**: Multi-connection management, multi-tab inner session navigation, schema discovery across multiple database engines (MySQL, MariaDB).  

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-evaluated post-design.*

| Principle | Requirement | Compliance Analysis | Status |
|---|---|---|---|
| **Principle I: Clean MVVM & Type Safety** | ViewModels must be UI-agnostic; no visual imports in ViewModels; `[ObservableProperty]` and `[RelayCommand]` utilized; UI thread dispatching via `DispatcherQueue`. | ViewModels (`DatabaseViewModel`, `ConnectControlViewModel`, `DatabaseControlViewModel`, `DataControlViewModel`) contain no references to `Microsoft.UI.Xaml.Controls`. Dialogs receive data models. | **PASS** |
| **Principle II: Modern Fluent UI / UX** | WinUI 3 Fluent Design 2; Mica/Acrylic backdrop; native `TabView` and `ContentDialog`; no Win32 `MessageBox.Show`. | Inner tab strip uses native `TabView`; all dialogs use `ContentDialog` with `XamlRoot` set. | **PASS** |
| **Principle III: Credential Protection** | Encrypted credentials at rest; parameterized queries; zero plaintext in logs. | `ConnectionStorageService` uses `PasswordEncryptor.Encrypt(plainText)` before saving to `connections.json`. SQL queries use parameterized builder. | **PASS** |
| **Principle IV: High Performance** | Async non-blocking I/O; cancellation support; deterministic disposal; query paging. | All database calls use `async`/`await` with `CancellationToken`; `DataViewControl` enforces `LIMIT ... OFFSET ...` paging; `IDatabaseConnection` implements `IDisposable`. | **PASS** |
| **Principle V: English Technical Docs** | 100% XML doc comments in technical US English on all public/internal symbols. | All newly created and modified classes, interfaces, methods, properties, and RelayCommands have complete XML doc comments. | **PASS** |
| **Principle VI: Spec-Driven Development** | Spec-Kit + Superpowers discipline via `speckit-superpowers-bridge`. | Requirements clarified in `spec.md`; architectural design in `plan.md`; verified by bridge status. | **PASS** |
| **Principle VII: Zero Hardcoded Strings & i18n** | All user text bound to `TranslationSource` and `.resx` bundles; dynamic runtime switching without app restart. | All UI text binds via indexer syntax `{Binding [key], Source={StaticResource Localization}}`; new keys added to `String.resx`, `String.en.resx`, `String.vi.resx`. | **PASS** |

---

## Project Structure

### Documentation (this feature)

```text
specs/004-database-connection-management/
├── plan.md              # Implementation plan (this document)
├── research.md          # Phase 0 architectural research & WinUI 3 solutions
├── data-model.md        # Phase 1 data modeling & entity relationships
├── quickstart.md        # Phase 1 developer verification and testing steps
├── contracts/           # Phase 1 service & interface contracts
│   ├── IDatabaseConnection.md
│   ├── IConnectionStorageService.md
│   └── IDialogService.md
└── tasks.md             # Phase 2 task breakdown (/speckit-tasks)
```

### Source Code (repository root)

```text
DataSphere/
├── Models/
│   ├── ConnectionModel.cs                           # Hierarchical connection node with runtime actions
│   ├── InnerTabItemModel.cs                         # Model representing inner sub-tabs in DatabasePage
│   ├── TableDataPage.cs                             # Paginated table dataset and row cells
│   └── Database/
│       ├── ConnectionRoot.cs                        # Active connection root in object explorer
│       ├── DatabaseInfo.cs                          # Catalog schema entity with categories
│       ├── DatabaseCategory.cs                      # Structural categories (Tables, Views, etc.)
│       └── Table.cs                                 # Table definition, columns, keys
├── Services/
│   ├── ConnectionStorageService.cs                  # Encrypted storage (connections.json)
│   ├── DialogService.cs                             # WinUI 3 ContentDialog coordinator with XamlRoot
│   ├── Contracts/
│   │   └── IDialogService.cs                        # Dialog service contract
│   └── Database/
│       ├── DatabaseConnectionFactory.cs             # Factory for creating database connections
│       ├── Interface/
│       │   ├── IDatabaseConnection.cs               # Connection interface
│       │   └── IDatabaseQueryExecutor.cs            # Query execution contract
│       └── Connection/
│           └── MySqlDatabaseConnection.cs           # Async MySqlConnector implementation
├── ViewModels/
│   ├── Pages/
│   │   └── DatabaseGroup/
│   │       ├── DatabaseViewModel.cs                 # Coordinates inner TabView (Tabs 0..N)
│   │       ├── ConnectControlViewModel.cs           # Manages connection tree & empty state
│   │       ├── DatabaseControlViewModel.cs          # Active session schema tree & commands
│   │       └── DataControlViewModel.cs              # Paginated table data viewer
│   └── Dialogs/
│       ├── ConnectionEditingViewModel.cs            # Connection configuration & async ping
│       └── DatabaseEditingViewModel.cs              # Database creation/collation configuration
├── Views/
│   ├── Pages/
│   │   └── DatabaseGroup/
│   │       ├── DatabasePage.xaml                    # Inner TabView container
│   │       ├── DatabasePage.xaml.cs
│   │       ├── ConnectViewControl.xaml              # Connection explorer tree & empty state
│   │       ├── ConnectViewControl.xaml.cs
│   │       ├── DatabaseViewControl.xaml             # Object explorer & split table viewer
│   │       ├── DatabaseViewControl.xaml.cs
│   │       ├── DataViewControl.xaml                 # Paginated tabular records viewport
│   │       └── DataViewControl.xaml.cs
│   └── Dialogs/
│       ├── ConnectionEditingDialog.xaml             # Native WinUI 3 ContentDialog
│       ├── ConnectionEditingDialog.xaml.cs
│       ├── DatabaseEditingDialog.xaml               # Native WinUI 3 ContentDialog
│       └── DatabaseEditingDialog.xaml.cs
└── Resources/Locales/
    ├── String.resx                                  # Neutral string bundle
    ├── String.en.resx                               # English localization
    └── String.vi.resx                               # Vietnamese localization
```

---

## Implementation Phases

### Phase 1: Core Storage & Model Restoration
- Enhance `ConnectionStorageService` to transparently encrypt passwords using `PasswordEncryptor.Encrypt()` on `SaveAsync` and decrypt on `LoadAsync`.
- Add `InnerTabItemModel` for managing inner `TabView` tabs.
- Add `TableDataPage` and `TableRowData` for paginated tabular data viewing.
- Verify headless test harness passes credential encryption and serialization tests.

### Phase 2: Native ContentDialog Infrastructure
- Create `ConnectionEditingDialog` (subclassing `ContentDialog`) with fields: Connection Name, Database Type, Host, Port, Username, Password, default Database.
- Implement `ConnectionEditingViewModel` with input validation and non-blocking asynchronous `TestConnectionCommand` with status indicator.
- Create `DatabaseEditingDialog` with Database Name, Character Set, and Collation selector.
- Implement confirmation dialog helper in `DialogService` ensuring explicit `dialog.XamlRoot` assignment.

### Phase 3: Inner Tab Workspace & Connections View
- Refactor `DatabaseViewModel` to expose `ObservableCollection<InnerTabItemModel> InnerTabs` and `InnerTabItemModel? SelectedInnerTab`.
- Initialize Tab 0 as anchored, non-closable "Connections" tab hosting `ConnectViewControl`.
- Implement `ConnectViewControl` (WinUI 3 `UserControl`) with:
  - Connection TreeView supporting folders and MySQL instances.
  - Context menu actions: New Connection, Add Folder, Edit, Rename, Delete.
  - Empty-state view with "New Connection" action button when `ConnectItems.Count == 0`.
- Wire `startConnectionCallback` to spawn a new closable inner connection tab in `DatabaseViewModel`.

### Phase 4: Schema Explorer & Database Management
- Implement `DatabaseControlViewModel` for managing active sessions, retrieving server databases via `connection.GetAllDatabasesAsync()`, and populating categories (Tables, Views, SPs, Functions).
- Implement `DatabaseViewControl` with left panel `TreeView`, draggable `GridSplitter`, and right panel hosting table content.
- Implement database lifecycle operations: New Database, Edit Database, and Drop Database with confirmation dialog.
- Implement tab close handling: when an inner connection tab is closed, gracefully disconnect and dispose `IDatabaseConnection`.

### Phase 5: Paginated Table Data Viewport
- Implement `DataControlViewModel` executing paginated queries (`SELECT * FROM db.table LIMIT @Limit OFFSET @Offset`).
- Implement `DataViewControl` with:
  - Dynamic column header row.
  - Virtualized `ListView` for record rows.
  - Bottom pagination controls: rows per page ComboBox (100, 500, 1000), previous/next page navigation, total record count display, and Refresh button.

### Phase 6: Dynamic Localization (i18n) & Polish
- Ensure all newly introduced UI text, dialog headers, buttons, error messages, and empty-state labels are defined in `String.resx`, `String.en.resx`, and `String.vi.resx`.
- Verify runtime language switching between English and Vietnamese updates all database controls dynamically.
- Verify 100% US English XML doc comments on all new/modified symbols.
- Verify `dotnet build DataSphere\DataSphere.csproj -c Debug` produces 0 errors and 0 warnings.

---

## Verification Gates

1. **Compilation Gate**: `dotnet build DataSphere\DataSphere.csproj -c Debug` must exit with code 0 (0 errors, 0 warnings).
2. **Headless Verification Gate**: `dotnet run --project scratch/VerifyUserDataStore/VerifyUserDataStore.csproj` passes all encryption and storage assertions.
3. **Security Gate**: Security audit confirms zero plaintext passwords in `connections.json` or debug output.
4. **Documentation Gate**: 100% of public/internal classes, methods, properties, and RelayCommands have standard US English XML doc comments.
5. **i18n Gate**: Zero hardcoded strings in XAML or C#; dynamic switching verified.
