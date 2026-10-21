# Feature Specification: High-Performance Data Pipeline, Server-Side Sorting, and In-Place Table Editor

**Feature Branch**: `007-table-editor-and-query-pipeline`

**Created**: 2026-10-21

**Status**: Draft

**Input**: User description: "với các tối ưu hóa của bạn tôi muốn bổ sung thêm việc có thể sort từ sql (xây dựng hoàn chỉnh để tương thích với nhiều loại database), hỗ trợ chỉnh sửa ô trực tiếp (có nút commit phía trên thanh công cụ Viewport Toolbar), hiện tại khi tôi nhấn truy vấn 1 bảng và ngay lập tức nhấn vào bảng khác thì hãy cho nó load ngay lập tức (bất đồng bộ, hủy tải và hủy thực thi lệnh sql trên bảng chưa hoàn tất ngay lập tức)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Instant Table Switching & Fast Query Cancellation (Priority: P1) 🎯 MVP

As a database administrator or developer exploring database schemas with multiple tables, when I select a table and then immediately click another table, I want the prior query and data loading pipeline to be cancelled immediately at both the C# task and database engine levels, so that the newly selected table loads instantaneously without waiting for the abandoned query or blocking the database connection.

**Why this priority**: Eliminates UI freeze, connection pool starvation, and latency spikes when browsing schemas. Without immediate query cancellation, rapid navigation causes queue bottlenecks and unresponsive UI.

**Independent Test**: Can be tested independently by querying a large table, immediately clicking another table within 100ms, and verifying that the first query aborts instantly while the second table renders without latency.

**Acceptance Scenarios**:

1. **Given** an active in-flight table query on Table A, **When** the user clicks Table B in the database navigation tree, **Then** the active `CancellationTokenSource` for Table A is cancelled immediately, any running SQL command is aborted via cancellation, and Table B begins fetching without delay.
2. **Given** an aborted query for Table A, **When** its cancellation completes, **Then** no abandoned records, stale columns, or error notifications from Table A leak into or overwrite the viewport of Table B.
3. **Given** rapid successive clicks across multiple tables (e.g. 5 tables in 2 seconds), **Then** each prior query is cleanly cancelled without leaking database sockets or leaving orphaned server threads, and only the final selected table displays records.

---

### User Story 2 - High-Performance Table Loading & Non-Blocking Row Estimation (Priority: P1)

As a data analyst opening tables with tens of thousands or millions of records, I want initial table records to appear in under 150 milliseconds without being blocked by expensive full-table count operations, and I want row allocations and column rendering to be optimized so that data displays with HeidiSQL-class responsiveness.

**Why this priority**: Running a synchronous `SELECT COUNT(*)` on large InnoDB tables forces full-table scans that take seconds, delaying data that is already retrieved. Decoupling row count estimation and optimizing memory batching provides instant table display.

**Independent Test**: Can be tested independently by opening a table containing $>50,000$ rows, observing that the first 100 rows render in $<150$ms with an estimated row count, while the exact count (if requested) calculates asynchronously in the background without delaying the view.

**Acceptance Scenarios**:

1. **Given** an open table request, **When** the query executes, **Then** the paginated record slice (`LIMIT @Limit OFFSET @Offset`) loads immediately, while total row count is populated instantly from schema metadata (`information_schema.TABLES.TABLE_ROWS` or dialect equivalent) without executing a blocking full-table scan.
2. **Given** a data reader streaming rows from the database, **When** rows are transferred into memory, **Then** collections are populated via pre-allocated batch lists rather than firing individual collection change notifications for every row.
3. **Given** sequential page navigation within the same table, **When** moving between pages, **Then** existing `DataGrid` column definitions are preserved and reused without tearing down and rebuilding the column visual tree.

---

### User Story 3 - Cross-Database Server-Side SQL Sorting (Priority: P1)

As a database analyst working with large datasets, I want clicking a column header in the DataGrid to sort the entire table dataset via a server-side SQL query (`ORDER BY column ASC/DESC`) executed on the database engine, so that I can see the true global minimum, maximum, and sorted order across all records rather than just sorting the current 100-row page slice in memory.

**Why this priority**: In-memory sorting only sorts the active paginated slice (e.g. 100 rows). Real-world database investigation requires server-side sorting that queries the full table dataset with dialect-agnostic safety.

**Independent Test**: Can be tested independently by clicking a column header, verifying that a parameterized query with `ORDER BY <quoted_column> ASC` is executed against the database, resetting pagination to Page 1 and displaying the true globally sorted dataset.

**Acceptance Scenarios**:

1. **Given** an unsorted table view, **When** the user clicks a column header, **Then** the application generates a dialect-quoted server query with `ORDER BY <column> ASC LIMIT @Limit OFFSET 0` and renders the sorted records with an upward arrow glyph (`↑`).
2. **Given** a column currently sorted ascending, **When** the user clicks the header again, **Then** the application executes `ORDER BY <column> DESC LIMIT @Limit OFFSET 0` and renders records with a downward arrow glyph (`↓`).
3. **Given** a column currently sorted descending, **When** the user clicks the header a third time, **Then** the sort clears back to natural database order (no `ORDER BY`) and the arrow glyph disappears.
4. **Given** an active server sort, **When** the user navigates between pages (e.g. Page 1 to Page 2), **Then** the `ORDER BY` clause is retained for subsequent page queries.

---

### User Story 4 - In-Place Grid Cell Editing & Viewport Toolbar Commit (Priority: P2)

As a database administrator, I want to edit cell values directly in the DataGrid by double-clicking or typing, have modified cells visually highlighted, and review and commit those changes to the database using a dedicated "Commit" button on the Viewport Toolbar, so that I can update records quickly without writing manual `UPDATE` queries.

**Why this priority**: Direct in-place editing is a standard feature of modern database tools. Providing clear dirty-state tracking with explicit Commit and Discard controls prevents accidental data overwrites and ensures transactional safety.

**Independent Test**: Can be tested independently by double-clicking a cell in a table with a primary key, entering a new value, observing the highlighted modified state and enabled Commit/Discard toolbar buttons, clicking "Commit", and verifying the record updates in the database.

**Acceptance Scenarios**:

1. **Given** a table with at least one primary key column, **When** the user double-clicks an editable cell or presses Enter, **Then** the cell enters edit mode allowing text modification.
2. **Given** a cell value has been modified, **When** the user moves focus or presses Enter, **Then** the cell is marked as dirty with a distinct visual indicator, and the "Commit" (Save) and "Discard" (Revert) buttons on the Viewport Toolbar become active.
3. **Given** pending cell modifications, **When** the user clicks "Commit", **Then** the system generates a parameterized SQL `UPDATE` statement targeting the row's primary key(s), executes it, refreshes the row status, and notifies the user of success.
4. **Given** pending cell modifications, **When** the user clicks "Discard", **Then** all staged edits are reverted to their original retrieved values, dirty indicators are cleared, and toolbar buttons return to disabled state.
5. **Given** a table lacking any primary key or unique index, **When** the table view loads, **Then** cells remain read-only with an informational status indicating that editing requires a unique identifier to prevent ambiguous updates.

---

### Edge Cases

- **Fast Sequential Table Clicks**: Rapid switching between tables (e.g. 5 tables in 1 second) must cancel all prior tasks without socket leaks, deadlocks, or task cancellation unhandled exceptions.
- **Uncommitted Edits on Navigation/Sort/Page Change**: If the user attempts to sort, change pages, or switch tables while uncommitted edits exist, the application must prompt the user to Commit or Discard to prevent silent data loss.
- **Modifying Primary Key Values**: If a user edits a primary key column, the generated `UPDATE` statement must reference the original primary key value in the `WHERE` clause (`WHERE pk = @old_pk`) to avoid updating incorrect records.
- **Database NULL vs Empty String**: The editor must allow distinguishing between setting a cell value to `NULL` (e.g. typing `NULL` or pressing Delete on empty) versus an empty string `""`.
- **Network Disconnection During Commit**: If the connection drops while committing, changes must remain staged as dirty in memory and an error dialog must notify the user without losing entered data.
- **Multi-Dialect Identifier Quoting**: SQL identifiers must be escaped according to dialect rules (backticks for MySQL/MariaDB, double quotes for PostgreSQL/SQLite, square brackets for SQL Server) to prevent syntax errors and injection vulnerabilities.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST support instant cancellation of in-flight table queries when switching tables or closing views, cancelling both C# asynchronous tasks and active database commands via `CancellationToken`.
- **FR-002**: System MUST optimize table loading performance by decoupling row count calculation from initial record retrieval, using schema metadata (`TABLE_ROWS`) or asynchronous background counting to prevent full-table `COUNT(*)` scans from blocking the first page.
- **FR-003**: System MUST batch row collection additions to minimize UI layout passes and prevent per-row `CollectionChanged` events.
- **FR-004**: System MUST preserve and reuse existing `DataGrid` column definitions across pagination queries on the same table.
- **FR-005**: System MUST provide a dialect-agnostic SQL builder abstraction that safely generates parameterized queries with proper identifier escaping (backticks for MySQL/MariaDB).
- **FR-006**: System MUST support server-side SQL sorting across the entire table dataset, cycling through Ascending (`ASC`), Descending (`DESC`), and Natural/Clear upon header clicks.
- **FR-007**: System MUST support in-place grid cell editing for tables with primary keys, supporting standard desktop interaction (double-click, Enter, direct typing).
- **FR-008**: System MUST track modified cells and rows in memory as pending edits, presenting visual dirty indicators and enabling "Commit" and "Discard" actions on the Viewport Toolbar.
- **FR-009**: System MUST execute parameterized `UPDATE` queries using dialect-safe syntax and primary key predicates upon user invocation of the "Commit" action.
- **FR-010**: System MUST safeguard uncommitted edits by warning users before performing destructive operations (e.g. sorting, changing page, switching table).
- **FR-011**: System MUST preserve dynamic internationalization (i18n) by obtaining all new button labels, tooltips, and dialog messages from `TranslationSource` with zero hardcoded strings.

---

### Key Entities

- **IDatabaseDialect**: Contract encapsulating database-specific syntax rules, including identifier quoting, pagination syntax, metadata row count extraction, and parameterized update generation.
- **PendingCellEdit**: Encapsulates a staged modification to a single cell, capturing column index, column name, original value, proposed new value, and target row primary key identity.
- **TableEditorState**: Tracks the active collection of pending edits, modified row indices, can-commit state, and can-discard state for the current table view.
- **QueryExecutionToken**: Encapsulates an active query lifecycle with coordinated `CancellationTokenSource` and reference to the underlying database command for instant cancellation.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Switching between tables cancels prior queries and begins loading the new table in $<50$ milliseconds.
- **SC-002**: Initial table rendering for tables of any size (including tables with $>100,000$ rows) displays the first 100 rows in $<150$ milliseconds by eliminating synchronous `SELECT COUNT(*)` blocking.
- **SC-003**: Server-side column sorting triggers and completes on 10,000-row database tables in $<200$ milliseconds on local connections.
- **SC-004**: In-place cell edits can be staged and committed to the database with a single click, updating the database record with verified parameterized queries.
- **SC-005**: 100% of new user-facing strings comply with dynamic i18n via `.resx` resources with zero hardcoded text.
- **SC-006**: All cancellation, sorting, and cell editing interactions are validated on the real desktop station (`WinSta0\default`) via automated UI testing with DirectComposition visual confirmation.

---

## Assumptions

- Target database engines include MySQL and MariaDB initially, with architecture cleanly decoupled via dialect contracts for future PostgreSQL, SQLite, and SQL Server support.
- Cell editing is supported for tables with one or more primary key columns. Tables lacking primary keys are marked read-only with an informational status notice.
- Cell editing focuses on standard scalar types (integers, floats, decimals, strings, dates, booleans) in v1; complex binary blobs or geometric types remain read-only or raw text.
