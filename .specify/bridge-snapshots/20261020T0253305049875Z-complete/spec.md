# Feature Specification: Database Connection Management & Selection

**Feature Branch**: `004-database-connection-management`

**Created**: 2026-10-20

**Status**: Clarified

**Input**: User description: "tại sao phần kết nối cơ sở dữ liệu lại không có gì để tôi chọn kết nối vậy??? bổ sung thêm là hãy thêm đầy đủ tất cả chức năng mà bạn đã xóa đi trong quá trình di chuyển sang WinUI3"

## Clarifications

### Session 2026-10-20

- Q: How should the database workspace and connection views be laid out in WinUI 3? → A: Inner Tabs (matching legacy `main` architecture): inside `DatabasePage`, an inner TabView hosts Tab 0 as anchored non-closable "Connections" (`ConnectViewControl`), and opening any connection creates a new closable inner sub-tab (`DatabaseViewControl`).
- Q: How should connection editing and database creation dialogs be presented in WinUI 3? → A: Native WinUI 3 `ContentDialog` with `dialog.XamlRoot = activeWindow.Content.XamlRoot` per Microsoft PowerToys WinUI 3 migration standards.
- Q: How should table data viewing (`DataViewControl`) be designed? → A: Paginated data viewer with row limit selector (100, 500, 1000 rows), refresh command, column definitions, and record preview in the right panel of the connection tab.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Database Connection List & Empty State Presentation (Priority: P1) 🎯 MVP

As a database administrator navigating to the Database tab, I want to see a clear list of my configured database connections (or an intuitive empty state with a "New Connection" action button when none exist), so that I can easily discover, select, and manage my database servers.

**Why this priority**: Without a connection list or selector, the Database tab is currently an empty placeholder where users cannot choose, see, or initiate any database connectivity. Delivering the connection list and empty state provides the essential interactive foundation for all database operations.

**Independent Test**: Open DataSphere and navigate to the Database tab. If no connections exist, confirm that a clean, styled empty-state view with an action button to create a connection is displayed. When connections exist, confirm that each connection item renders in the tree view with its name, database engine icon, host/port subtitle, and connection status.

**Acceptance Scenarios**:

1. **Given** zero database connections are configured in storage, **When** opening the Database tab, **Then** an informative empty-state view is presented with title, description, and an "Add Connection" button.
2. **Given** one or more database connections exist in persistent storage, **When** opening the Database tab, **Then** the connection tree is populated with connection name, host address, port, and engine icon.
3. **Given** the connection list is visible, **When** the user clicks a connection item, **Then** the item is selected, displaying its connection details and action commands (Connect, Edit, Delete).

---

### User Story 2 - Creating & Configuring New Database Connections (Priority: P1) 🎯 MVP

As a database engineer, I want to create a new database connection by entering server parameters (Connection Name, Host, Port, Username, Password, Database Name) and testing connectivity within a native `ContentDialog`, so that I can verify and safely save my database credentials.

**Why this priority**: Users must be able to add their own database instances (MySQL/MariaDB) to DataSphere to perform real query and management tasks. Testing connectivity before saving prevents misconfigured connections.

**Independent Test**: Click "New Connection". Enter valid connection details (e.g., host `127.0.0.1`, port `3306`, user `root`, password). Click "Test Connection"; confirm test success feedback. Click "Save"; verify that the connection immediately appears in the connection selector list and persists across application restarts.

**Acceptance Scenarios**:

1. **Given** the New Connection dialog is opened as a native WinUI 3 `ContentDialog` (with `XamlRoot` properly bound), **When** user enters valid database server credentials and clicks "Test Connection", **Then** a non-blocking asynchronous ping executes and displays a success confirmation badge.
2. **Given** the user inputs an unreachable host or invalid credentials, **When** clicking "Test Connection", **Then** an informative error message explaining the connection failure is presented within 5 seconds without freezing the UI.
3. **Given** valid connection parameters, **When** user clicks "Save", **Then** the configuration is persisted to storage with the password securely encrypted via standard application cryptography (`PasswordEncryptor`).
4. **Given** missing mandatory fields (such as Host or User), **When** user attempts to save, **Then** input validation highlights the missing fields and prevents saving.

---

### User Story 3 - Connecting, Disconnecting & Schema Discovery in Inner Tabs (Priority: P2)

As a database professional, I want to double-click or click "Connect" on a saved connection, so that DataSphere establishes an active session, opens a dedicated inner connection sub-tab, and retrieves available schemas, tables, views, and functions.

**Why this priority**: Establishing an active session and discovering database schemas is the gateway to executing queries, viewing tables, and managing data. Organizing each active connection into its own inner tab preserves multi-connection workflows matching the legacy application baseline.

**Independent Test**: Select a valid saved connection and click "Connect" (or double-click it). Verify that an inner sub-tab titled with the connection name is created and selected, displaying a hierarchical tree of databases and tables. Click "Disconnect"; verify the connection session is gracefully closed and the sub-tab can be closed.

**Acceptance Scenarios**:

1. **Given** a valid saved connection, **When** user double-clicks it or clicks "Connect", **Then** a loading indicator appears, and a new inner closable tab (`DatabaseViewControl`) opens for that connection.
2. **Given** a successful connection session, **When** connected, **Then** the database tree expands to show all databases/schemas available on the server, with nested child nodes for Tables, Views, Functions, and Procedures.
3. **Given** an active connected session, **When** user clicks "Disconnect" or closes the connection sub-tab, **Then** the connection is closed, resources are released, and socket connections are disposed.
4. **Given** a connection attempt to an unavailable server, **When** connection fails, **Then** an error bar or InfoBar displays the database engine error without application crash.

---

### User Story 4 - Database Schema Management (Priority: P2)

As a database administrator, I want to create, edit, and drop databases directly from the database tree, so that I can manage my server schemas without needing external command-line tools.

**Why this priority**: Core database operations (Create, Edit, Drop Database) were present on the legacy platform and are required for full database lifecycle management.

**Independent Test**: Right-click the root server connection node; choose "New Database"; enter database name and collation in the `DatabaseEditing` ContentDialog; confirm creation; verify the new database appears in the tree. Right-click a database and choose "Drop Database"; confirm the deletion dialog; verify it is removed from the server and tree.

**Acceptance Scenarios**:

1. **Given** an active connection, **When** user chooses "New Database", **Then** a `DatabaseEditing` ContentDialog opens allowing selection of database name, character set, and collation.
2. **Given** valid database specifications, **When** user confirms creation, **Then** the database is created via SQL execution and the schema tree refreshes automatically.
3. **Given** an existing database node, **When** user chooses "Drop Database", **Then** a ContentDialog with warning prompts the user for confirmation before executing the drop command.

---

### User Story 5 - Table Data Viewport & Pagination (Priority: P2)

As a data analyst, I want to double-click a table in the database tree to view its rows in a paginated data viewer with column metadata and row limit controls, so that I can inspect and explore table contents efficiently.

**Why this priority**: Browsing table data is the primary reason users connect to a database. Fast, paginated rendering prevents memory exhaustion on large production tables.

**Independent Test**: In the database tree, expand a database and double-click a table. Verify that the right panel of the connection tab loads the `DataViewControl`, displaying the table's columns and rows with pagination controls (e.g., 100 rows per page) and a Refresh command.

**Acceptance Scenarios**:

1. **Given** an expanded database tree, **When** user clicks or double-clicks a table, **Then** the right panel loads `DataViewControl` for that table.
2. **Given** table data is loading, **When** query execution completes, **Then** column headers and rows are rendered with proper data types.
3. **Given** large tables, **When** browsing, **Then** pagination limits queries (e.g. `LIMIT 100 OFFSET 0`), and page navigation controls allow viewing subsequent pages without locking the UI.
4. **Given** user clicks "Refresh", **When** invoked, **Then** table data is re-queried and refreshed.

---

### User Story 6 - Editing, Renaming & Deleting Connections (Priority: P2)

As a user maintaining multiple database environments, I want to edit connection parameters, rename connections inline, or delete obsolete connections, so that my database workspace remains organized and accurate.

**Why this priority**: Server credentials, ports, or hostnames frequently change; users need full lifecycle management for their connection catalog.

**Independent Test**: Right-click a connection in the selector. Choose "Edit", change the display name or port, and click "Save"; verify the updated details reflect immediately. Choose "Delete", confirm the prompt; verify the connection is removed from the UI and disk.

**Acceptance Scenarios**:

1. **Given** an existing connection, **When** user right-clicks and chooses "Edit Connection", **Then** the configuration ContentDialog opens pre-populated with existing parameters (with password safely decrypted for editing).
2. **Given** an existing connection, **When** user chooses "Delete Connection", **Then** a confirmation dialog prompts the user before removing the connection from memory and persistent storage (`connections.json`).
3. **Given** an inline rename action, **When** user edits the name and presses Enter, **Then** the name updates immediately in memory and is saved to storage.

---

### Edge Cases

- **Unreachable Host / Network Timeout**: When a connection test or connect action targets a dead IP or port, the system MUST enforce a 5-second cancellation timeout and display a friendly timeout message without hanging the application.
- **Corrupted `connections.json`**: If the stored connections file contains invalid JSON or truncated bytes, the system MUST catch deserialization exceptions, fall back to an empty collection, and allow users to create new connections without crashing.
- **Empty Password Allowed**: Some local development database configurations (e.g., local root user on dev environments) have no password. The system MUST allow saving and connecting with an empty password if specified.
- **Rapid Double-Clicking / Concurrent Connection Attempts**: Clicking "Connect" multiple times rapidly MUST debounce or lock so only a single connection task executes at a time.
- **Multi-Monitor / Dialog Positioning**: The connection editing dialog MUST be centered over the active shell window and support standard Light and Dark themes seamlessly with `dialog.XamlRoot = activeWindow.Content.XamlRoot`.
- **Large Result Sets / Memory Management**: Table data viewing MUST use parameterized paging (`LIMIT` / `OFFSET`) to avoid fetching million-row tables into memory.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST implement an inner tab workspace (`DatabasePage`) containing an anchored non-closable "Connections" tab (`ConnectViewControl`) at Tab 0 and dynamically opened connection tabs (`DatabaseViewControl`).
- **FR-002**: The system MUST render an informative empty state view with a "New Connection" action button when zero connections exist in storage.
- **FR-003**: The system MUST provide a native WinUI 3 `ContentDialog` for creating and editing database connections (`ConnectionEditing`) with fields: Name, Server Type (MySQL/MariaDB), Host, Port (default 3306), Username, Password, and default Database name, with `dialog.XamlRoot` explicitly assigned.
- **FR-004**: The system MUST provide an asynchronous "Test Connection" command inside the connection dialog with non-blocking execution and clear pass/fail status messaging.
- **FR-005**: The system MUST persist connection records in `%LOCALAPPDATA%\DataSphere\connections.json` using `ConnectionStorageService`.
- **FR-006**: The system MUST transparently encrypt all connection passwords using `PasswordEncryptor` before writing `connections.json` to disk, ensuring zero plain-text passwords in storage.
- **FR-007**: The system MUST establish database sessions asynchronously via `MySqlConnector` without freezing or degrading UI frame rate (< 16ms per frame).
- **FR-008**: The system MUST display an object explorer tree inside `DatabaseViewControl` showing Databases/Schemas, Tables, Views, Functions, and Procedures.
- **FR-009**: The system MUST support Database Management operations: New Database (via `DatabaseEditing` ContentDialog with Charset/Collation options), Edit Database properties, and Drop Database with confirmation.
- **FR-010**: The system MUST support Table Data Viewing (`DataViewControl`) in the right panel of the connection tab, displaying table records with pagination (100, 500, 1000 rows) and refresh capability.
- **FR-011**: The system MUST allow users to disconnect from an active session, cleanly disposing connection objects, sockets, and memory cache.
- **FR-012**: The system MUST provide context menu actions for each connection: Connect, Disconnect, Edit, and Delete (with confirmation dialog), plus inline renaming.
- **FR-013**: All user-facing strings (dialog headers, field labels, button titles, empty state text, error messages) MUST bind to `TranslationSource` resource strings with zero hardcoded literals (Constitution Principle VII).
- **FR-014**: All ViewModels MUST adhere strictly to Clean MVVM, CommunityToolkit.Mvvm source generators (`[ObservableProperty]`, `[RelayCommand]`), and have 100% US English XML doc comments (Constitution Principles I & V).

### Key Entities

- **Connection Configuration (`ConnectionModel`)**: Represents a database connection record containing Name, Key (unique ID), Database Type (MySQL, MariaDB), Host, Port, Username, encrypted Password, and default Database.
- **Database Schema (`DatabaseInfo`)**: Represents a database catalog/schema retrieved from an active server connection, hosting collections of Tables, Views, Functions, and Procedures.
- **Table Definition (`Table`)**: Represents a database table entity with column metadata and row count.
- **Connection Session State**: Represents the current connection lifecycle: `Disconnected`, `Connecting`, `Connected`, or `Error`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can create, test, and save a new MySQL database connection in under 60 seconds.
- **SC-002**: 100% of saved connection entries persist accurately across application restarts.
- **SC-003**: Zero plain-text passwords exist in `connections.json` on disk (verified through security review).
- **SC-004**: Testing an unreachable database connection times out and reports an error in under 5 seconds without blocking the UI thread or causing frame drops below 60 FPS.
- **SC-005**: Zero unhandled exceptions or crashes occur when `connections.json` is missing or corrupted.
- **SC-006**: Opening a table with 100,000+ rows displays the first page of 100 rows in under 500 milliseconds via paginated SQL queries.
- **SC-007**: 100% of UI elements and dialog messages support dynamic English and Vietnamese language switching without requiring application restarts.

## Assumptions

- Database connectivity utilizes `MySqlConnector` for MySQL and MariaDB instances.
- Inner tabs inside `DatabasePage` allow working on multiple database server connections concurrently.
- All modal dialogs use native WinUI 3 `ContentDialog` with `XamlRoot` set to the active window root.
