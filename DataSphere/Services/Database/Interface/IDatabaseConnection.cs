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
        /// Retrieves a paginated slice of records along with table columns and total record count.
        /// </summary>
        Task<TableDataPage> GetTableDataPageAsync(string databaseName, string tableName, int page, int pageSize, CancellationToken cancellationToken = default);
    }
}
