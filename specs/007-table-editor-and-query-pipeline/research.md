# Technical Research: High-Performance Data Pipeline, Server-Side Sorting, and In-Place Table Editor

**Feature**: `007-table-editor-and-query-pipeline`  
**Date**: 2026-10-21  

---

## 1. Instant Query Cancellation & Table Switching Architecture

### Context & Problem
When a user clicks a table in the database tree (or switches tabs), a database query is dispatched. If the user quickly clicks a second table, the first query continues running in the background. In MySQL/MariaDB, uncancelled queries hold connection locks and consume server thread resources. In the client, once the abandoned query finishes, its results can overwrite the newly selected view or trigger confusing error popups if the view has already detached.

### Research & Solution
- **ADO.NET & MySqlConnector Cancellation Protocol**:
  `MySqlConnector.MySqlCommand.ExecuteReaderAsync(CancellationToken)` actively integrates with `CancellationToken`. When a token is cancelled:
  - `MySqlConnector` attempts to send a `KILL QUERY <threadId>` packet to MySQL, terminating server-side execution immediately without disconnecting the socket.
  - The driver raises an `OperationCanceledException` (or `MySqlException` with error code `ER_QUERY_INTERRUPTED`).
- **Coordinated `CancellationTokenSource` in ViewModel**:
  `DataControlViewModel` manages an internal `CancellationTokenSource? _queryCts`:
  ```csharp
  public async Task LoadPageAsync(int page)
  {
      _queryCts?.Cancel();
      _queryCts?.Dispose();
      _queryCts = new CancellationTokenSource();
      var token = _queryCts.Token;

      try
      {
          var result = await _connection.GetTableDataPageAsync(_database.Name, _table.Name, page, PageSize, ActiveSort, token);
          if (!token.IsCancellationRequested)
          {
              DataPage = result;
          }
      }
      catch (OperationCanceledException)
      {
          // Clean abort: do not report errors or alter UI
      }
  }
  ```
- **Lifecycle Cleanliness on Disconnect/Dispose**:
  `Dispose()` on `DataViewControl` and `DataControlViewModel` cancels in-flight tokens immediately, ensuring instant release of resources when switching tables or closing tabs.

---

## 2. High-Performance Loading & Non-Blocking Row Estimation

### Context & Problem
In MySQL InnoDB, `SELECT COUNT(*)` requires a full index scan. On large tables ($>50,000$ rows), this takes hundreds of milliseconds or seconds, delaying the display of the first 100 rows which are already fetched.

### Research & Solution
1. **Metadata-Based Instant Row Estimation**:
   - Query `TABLE_ROWS` from `information_schema.TABLES WHERE TABLE_SCHEMA = @db AND TABLE_NAME = @table;`.
   - In MySQL InnoDB, this metadata is maintained continuously by the engine statistics and can be read in $<1$ ms ($O(1)$).
   - If the first page returns fewer rows than `PageSize`, the exact row count is immediately known (`TotalRecords = Rows.Count`).
   - If the table is larger, use `TABLE_ROWS` as the initial estimate and spawn an unawaited detached background task to compute exact count if needed, updating `TotalRecords` and `PageSummaryText` asynchronously on the UI thread when complete.
2. **Batch Collection Population**:
   - Instead of invoking `resultPage.Rows.Add(rowData)` inside the `while (reader.Read())` loop (which fires `INotifyCollectionChanged` 100 times), read all rows into a `List<TableRowData>` pre-allocated with `new List<TableRowData>(pageSize)`.
   - Assign the completed list in a single batch to `resultPage.Rows`.
3. **Column Recycling**:
   - In `DataViewControl.xaml.cs`, compare incoming column names and ordinals with existing `TableDataGrid.Columns`.
   - When navigating pages within the same table, skip `TableDataGrid.Columns.Clear()`. Retain the existing `DataGridTextColumn` instances and update only `TableDataGrid.ItemsSource`. This prevents WinUI 3 from tearing down and reconstructing the entire visual tree.

---

## 3. Cross-Database Server-Side SQL Sorting Architecture

### Context & Problem
Client-side in-memory sorting reorders only the currently loaded page (100 rows), which fails user expectations for finding global top-N records across the entire database. Furthermore, raw string concatenation of column names in `ORDER BY` introduces SQL injection vulnerabilities.

### Research & Solution
1. **`IDatabaseDialect` Abstraction**:
   Define a reusable contract for database-specific SQL dialect rules:
   ```csharp
   public interface IDatabaseDialect
   {
       string DatabaseType { get; }
       string QuoteIdentifier(string identifier);
       string BuildSelectPageQuery(string database, string table, int offset, int limit, ColumnSortDescriptor? sort);
       string BuildUpdateRowQuery(string database, string table, IReadOnlyDictionary<string, object?> changedValues, IReadOnlyDictionary<string, object?> primaryKeys);
   }
   ```
2. **Identifier Quoting & Dialect Rules**:
   - **MySQL / MariaDB (`MySqlDialect`)**:
     Identifier quoting: `` `database`.`table` `` and `` `column` ``.
     Pagination: `LIMIT @Limit OFFSET @Offset`.
   - **PostgreSQL / SQLite (`PostgreSqlDialect`, `SqliteDialect`)**:
     Identifier quoting: `"database"."table"`.
   - **SQL Server (`SqlServerDialect`)**:
     Identifier quoting: `[database].[table]`.
3. **Safe Parameterized Query Generation**:
   The `ORDER BY` clause quotes the column identifier safely via `QuoteIdentifier(sort.ColumnName)`. Direction is restricted to strict enum (`ASC` or `DESC`).

---

## 4. In-Place Grid Cell Editing & Viewport Toolbar Commit

### Context & Problem
Users expect to click into cells, modify text directly, and commit edits to the database without writing manual `UPDATE` queries. Data integrity requires dirty state tracking and primary key verification.

### Research & Solution
1. **DataGrid In-Place Editing Support**:
   - Set `IsReadOnly="False"` on `CommunityToolkit.WinUI.UI.Controls.DataGrid`.
   - Configure `DataGridTextColumn.IsReadOnly` based on table metadata (primary key columns can be editable with old-PK tracking; generated columns remain read-only).
   - Hook `CellEditEnding` to inspect original vs updated values.
2. **Dirty Tracking & Data Model**:
   `TableRowData` maintains:
   - `List<string> Cells`: Active display values.
   - `List<string> OriginalCells`: Snapshot from database query.
   - `bool IsDirty`: True if any cell in the row was modified.
   - `HashSet<int> ModifiedColumnIndices`: Indices of changed columns.
3. **Viewport Toolbar Actions**:
   - **Commit Button** (`btn_commit_changes`): Enabled when `ViewModel.CanCommit == true`. Generates parameterized `UPDATE` query:
     ```sql
     UPDATE `database`.`table` 
     SET `col_a` = @p0, `col_b` = @p1 
     WHERE `pk_col` = @k0;
     ```
   - **Discard Button** (`btn_discard_changes`): Enabled when `ViewModel.CanDiscard == true`. Reverts `Cells` from `OriginalCells`, clears dirty indicators, and disables buttons.
4. **Primary Key Requirement**:
   - In-place editing is only allowed for tables with one or more primary key columns (`Table.PrimaryKeys.Count > 0`).
   - For tables without a primary key, `DataGrid.IsReadOnly` is set to `True`, and an informational banner or tooltip clarifies that primary keys are required to uniquely identify records.

---

## 5. Technology Stack Decisions Summary

| Component | Selected Strategy | Rationale |
|---|---|---|
| **Query Cancellation** | `CancellationTokenSource` linked to `MySqlCommand.ExecuteReaderAsync` | Clean aborts, server-side `KILL QUERY`, no socket leaks |
| **Row Count Estimation** | `TABLE_ROWS` from `information_schema` + async background exact count | Sub-millisecond initial page rendering; eliminates InnoDB table scan delay |
| **Server-Side Sorting** | `IDatabaseDialect` with safe identifier quoting + `ORDER BY` | Extensible for MySQL, MariaDB, PostgreSQL, SQLite, SQL Server |
| **In-Place Editing** | `DataGrid` native editing + `TableRowData` original snapshot tracking | Familiar desktop UX, transactional safety, visual dirty indicators |
| **Commit/Discard** | Viewport Toolbar buttons + parameterized `UPDATE` queries | Clean MVVM commands, explicit user confirmation, SQL injection immune |
| **Dynamic i18n** | `TranslationSource` + UTF-8 `.resx` files | Strict adherence to Constitution Principle VII |
