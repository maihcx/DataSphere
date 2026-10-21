using System.Collections.ObjectModel;
using System.Data;
using DataSphere.Models;
using DataSphere.Models.Database;

namespace DataSphere.Services.Database.Interface
{
    /// <summary>
    /// Contract defining asynchronous operations for connecting to, exploring, and querying a database server.
    /// </summary>
    public interface IDatabaseConnection
    {
        /// <summary>
        /// Gets a value indicating whether the database session is open.
        /// </summary>
        bool IsConnected { get; }

        /// <summary>
        /// Opens the database session asynchronously.
        /// </summary>
        Task<bool> ConnectAsync();

        /// <summary>
        /// Closes and disposes active database connection sessions.
        /// </summary>
        Task DisconnectAsync();

        /// <summary>
        /// Tests database credentials and network reachability.
        /// </summary>
        Task<bool> TestConnectionAsync();

        /// <summary>
        /// Retrieves all table definitions within the specified database schema.
        /// </summary>
        Task<ObservableCollection<Table>?> GetAllTablesAsync(string dbName);

        /// <summary>
        /// Retrieves detailed column and key metadata for a specific table.
        /// </summary>
        Task<Table?> GetTableInfoAsync(string tableName);

        /// <summary>
        /// Retrieves all collations supported by the server.
        /// </summary>
        Task<ObservableCollection<CollationModel>?> GetAllCollation();

        /// <summary>
        /// Retrieves the default server collation.
        /// </summary>
        Task<CollationModel> GetDefCollation();

        /// <summary>
        /// Retrieves collation metadata for a specific collation name.
        /// </summary>
        Task<CollationModel> GetCollationInfo(string strCollation, CollationModel? collation = null);

        /// <summary>
        /// Retrieves all available database schemas on the server.
        /// </summary>
        Task<ObservableCollection<DatabaseInfo>?> GetAllDatabasesAsync();

        /// <summary>
        /// Executes a raw SQL query and returns results in a DataTable.
        /// </summary>
        Task<DataTable?> ExecuteQueryAsync(string sql);

        /// <summary>
        /// Executes an SQL query built with a query builder.
        /// </summary>
        Task<DataTable?> ExecuteQueryAsync(ISqlBuilder builder);

        /// <summary>
        /// Checks whether a database schema exists on the server.
        /// </summary>
        Task<bool> DatabaseExistsAsync(string dbname);

        /// <summary>
        /// Creates a new database schema on the server.
        /// </summary>
        Task CreateDatabase(DatabaseInfo databaseInfo);

        /// <summary>
        /// Drops a database schema from the server.
        /// </summary>
        Task DropDatabase(DatabaseInfo databaseInfo);

        /// <summary>
        /// Retrieves a paginated slice of records along with table columns, optional server-side sorting, and total record count.
        /// </summary>
        /// <param name="databaseName">The target database or schema name.</param>
        /// <param name="tableName">The target table name.</param>
        /// <param name="page">The 1-based page number.</param>
        /// <param name="pageSize">The page size.</param>
        /// <param name="sort">Optional column sort descriptor for server-side ORDER BY.</param>
        /// <param name="cancellationToken">Cancellation token to abort in-flight query.</param>
        /// <returns>A populated <see cref="TableDataPage"/> object.</returns>
        Task<TableDataPage> GetTableDataPageAsync(string databaseName, string tableName, int page, int pageSize, ColumnSortDescriptor? sort = null, CancellationToken cancellationToken = default);

        /// <summary>
        /// Commits pending row updates to the database engine using parameterized UPDATE statements.
        /// </summary>
        /// <param name="databaseName">The database name.</param>
        /// <param name="tableName">The table name.</param>
        /// <param name="updates">The collection of pending row modifications.</param>
        /// <param name="cancellationToken">Cancellation token.</param>
        /// <returns>A task representing the asynchronous operation.</returns>
        Task ExecuteUpdateRowsAsync(string databaseName, string tableName, IEnumerable<PendingRowUpdate> updates, CancellationToken cancellationToken = default);

        /// <summary>
        /// Asynchronously retrieves the primary key column names for the specified database table.
        /// </summary>
        /// <param name="databaseName">The owning database schema name.</param>
        /// <param name="tableName">The target table name.</param>
        /// <param name="cancellationToken">Cancellation token to abort the query.</param>
        /// <returns>A read-only list of primary key column names in ordinal sequence.</returns>
        Task<IReadOnlyList<string>> GetPrimaryKeysAsync(string databaseName, string tableName, CancellationToken cancellationToken = default);
    }
}
