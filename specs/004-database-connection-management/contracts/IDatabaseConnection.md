# Contract: IDatabaseConnection

**Namespace**: `DataSphere.Services.Database.Interface`  
**Implements**: `IDisposable`  

## 1. Overview
Defines the core database abstraction contract for opening, testing, executing queries, retrieving schema metadata, and closing database server connections asynchronously.

## 2. Interface Definition

```csharp
namespace DataSphere.Services.Database.Interface
{
    /// <summary>
    /// Contract for asynchronous database connectivity, metadata introspection, and SQL execution.
    /// </summary>
    public interface IDatabaseConnection : IDisposable
    {
        /// <summary>
        /// Gets a value indicating whether the underlying database session is currently open.
        /// </summary>
        bool IsConnected { get; }

        /// <summary>
        /// Asynchronously establishes a connection session to the database server.
        /// </summary>
        /// <param name="cancellationToken">Cancellation token for aborting connection handshakes.</param>
        /// <returns><c>true</c> if connected successfully; otherwise, <c>false</c>.</returns>
        Task<bool> ConnectAsync(CancellationToken cancellationToken = default);

        /// <summary>
        /// Asynchronously closes and releases all connection resources and sockets.
        /// </summary>
        Task DisconnectAsync();

        /// <summary>
        /// Tests connectivity against the server using provided connection credentials.
        /// </summary>
        /// <param name="cancellationToken">Cancellation token enforced with timeout (e.g. 5 seconds).</param>
        /// <returns><c>true</c> if server accepted credentials; otherwise, <c>false</c>.</returns>
        Task<bool> TestConnectionAsync(CancellationToken cancellationToken = default);

        /// <summary>
        /// Retrieves all databases/schemas available to the authenticated user on the server.
        /// </summary>
        /// <param name="cancellationToken">Cancellation token for async cancellation.</param>
        /// <returns>Collection of DatabaseInfo instances.</returns>
        Task<ObservableCollection<DatabaseInfo>?> GetAllDatabasesAsync(CancellationToken cancellationToken = default);

        /// <summary>
        /// Retrieves all table definitions within the specified database schema.
        /// </summary>
        /// <param name="databaseName">The database schema name.</param>
        /// <param name="cancellationToken">Cancellation token for async cancellation.</param>
        /// <returns>Collection of Table instances.</returns>
        Task<ObservableCollection<Table>?> GetAllTablesAsync(string databaseName, CancellationToken cancellationToken = default);

        /// <summary>
        /// Retrieves detailed column metadata, primary keys, and foreign keys for a specific table.
        /// </summary>
        /// <param name="tableName">The table name.</param>
        /// <param name="cancellationToken">Cancellation token for async cancellation.</param>
        /// <returns>Populated Table metadata.</returns>
        Task<Table?> GetTableInfoAsync(string tableName, CancellationToken cancellationToken = default);

        /// <summary>
        /// Retrieves all supported server collations.
        /// </summary>
        Task<ObservableCollection<CollationModel>?> GetAllCollation(CancellationToken cancellationToken = default);

        /// <summary>
        /// Creates a new database schema on the server.
        /// </summary>
        /// <param name="databaseInfo">Database specifications including name and collation.</param>
        Task CreateDatabase(DatabaseInfo databaseInfo, CancellationToken cancellationToken = default);

        /// <summary>
        /// Drops the specified database schema from the server.
        /// </summary>
        /// <param name="databaseInfo">The database schema to drop.</param>
        Task DropDatabase(DatabaseInfo databaseInfo, CancellationToken cancellationToken = default);

        /// <summary>
        /// Executes a paginated SQL query returning rows and column metadata.
        /// </summary>
        /// <param name="databaseName">Target database schema.</param>
        /// <param name="tableName">Target table name.</param>
        /// <param name="offset">Row offset.</param>
        /// <param name="limit">Page size limit.</param>
        /// <param name="cancellationToken">Cancellation token for async cancellation.</param>
        /// <returns>Paginated TableDataPage result.</returns>
        Task<TableDataPage> GetTableDataPageAsync(string databaseName, string tableName, int offset, int limit, CancellationToken cancellationToken = default);
    }
}
```
