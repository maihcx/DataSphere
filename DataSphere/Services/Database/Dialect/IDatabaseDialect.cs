using DataSphere.Models;

namespace DataSphere.Services.Database.Dialect
{
    /// <summary>
    /// Defines engine-specific SQL dialect formatting, identifier escaping, and query generation operations.
    /// </summary>
    public interface IDatabaseDialect
    {
        /// <summary>
        /// Gets the canonical database engine identifier (e.g. "MySQL", "MariaDB", "PostgreSQL", "SQLite").
        /// </summary>
        string DatabaseType { get; }

        /// <summary>
        /// Safely quotes an identifier (database, table, column) according to the engine dialect.
        /// </summary>
        /// <param name="identifier">The raw identifier string.</param>
        /// <returns>The escaped, quoted identifier string.</returns>
        string QuoteIdentifier(string identifier);

        /// <summary>
        /// Generates a paginated SELECT query with optional server-side ORDER BY sorting.
        /// </summary>
        /// <param name="database">The target database or schema name.</param>
        /// <param name="table">The target table name.</param>
        /// <param name="offset">The 0-based row offset.</param>
        /// <param name="limit">The row count limit.</param>
        /// <param name="sort">Optional column sort descriptor.</param>
        /// <returns>A parameterized SQL query string.</returns>
        string BuildSelectPageQuery(string database, string table, int offset, int limit, ColumnSortDescriptor? sort);

        /// <summary>
        /// Generates a parameterized UPDATE statement for staging in-place cell modifications.
        /// </summary>
        /// <param name="database">The target database name.</param>
        /// <param name="table">The target table name.</param>
        /// <param name="changedColumns">Dictionary mapping column names to parameter names for modified columns.</param>
        /// <param name="primaryKeyColumns">Dictionary mapping primary key column names to parameter names.</param>
        /// <returns>A parameterized SQL UPDATE query string.</returns>
        string BuildUpdateRowQuery(string database, string table, IReadOnlyDictionary<string, string> changedColumns, IReadOnlyDictionary<string, string> primaryKeyColumns);

        /// <summary>
        /// Generates a high-performance metadata query to extract estimated row count in O(1) time.
        /// </summary>
        /// <param name="database">The database name.</param>
        /// <param name="table">The table name.</param>
        /// <returns>A metadata query string.</returns>
        string BuildRowCountEstimateQuery(string database, string table);
    }
}
