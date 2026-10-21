using System.Text;
using DataSphere.Models;

namespace DataSphere.Services.Database.Dialect
{
    /// <summary>
    /// Implements SQL dialect operations for MySQL and MariaDB database engines.
    /// </summary>
    public class MySqlDialect : IDatabaseDialect
    {
        /// <summary>
        /// Gets the singleton default instance of the MySQL dialect.
        /// </summary>
        public static MySqlDialect Instance { get; } = new();

        /// <inheritdoc/>
        public string DatabaseType => "MySQL";

        /// <inheritdoc/>
        public string QuoteIdentifier(string identifier)
        {
            if (string.IsNullOrWhiteSpace(identifier))
            {
                return string.Empty;
            }

            // In MySQL/MariaDB, identifiers are quoted with backticks. Internal backticks are doubled.
            return $"`{identifier.Replace("`", "``")}`";
        }

        /// <inheritdoc/>
        public string BuildSelectPageQuery(string database, string table, int offset, int limit, ColumnSortDescriptor? sort)
        {
            var sb = new StringBuilder();
            sb.Append("SELECT * FROM ");
            sb.Append(QuoteIdentifier(database));
            sb.Append('.');
            sb.Append(QuoteIdentifier(table));

            if (sort != null && sort.Direction != ColumnSortDirection.None && !string.IsNullOrWhiteSpace(sort.ColumnName))
            {
                string dir = sort.Direction == ColumnSortDirection.Ascending ? "ASC" : "DESC";
                sb.Append(" ORDER BY ");
                sb.Append(QuoteIdentifier(sort.ColumnName));
                sb.Append(' ');
                sb.Append(dir);
            }

            sb.Append(" LIMIT @Limit OFFSET @Offset;");
            return sb.ToString();
        }

        /// <inheritdoc/>
        public string BuildUpdateRowQuery(string database, string table, IReadOnlyDictionary<string, string> changedColumns, IReadOnlyDictionary<string, string> primaryKeyColumns)
        {
            if (changedColumns == null || changedColumns.Count == 0)
            {
                throw new ArgumentException("At least one changed column must be specified for an update query.", nameof(changedColumns));
            }

            if (primaryKeyColumns == null || primaryKeyColumns.Count == 0)
            {
                throw new ArgumentException("At least one primary key predicate must be specified for an update query.", nameof(primaryKeyColumns));
            }

            var sb = new StringBuilder();
            sb.Append("UPDATE ");
            sb.Append(QuoteIdentifier(database));
            sb.Append('.');
            sb.Append(QuoteIdentifier(table));
            sb.Append(" SET ");

            bool first = true;
            foreach (var kvp in changedColumns)
            {
                if (!first) sb.Append(", ");
                sb.Append(QuoteIdentifier(kvp.Key));
                sb.Append(" = ");
                sb.Append(kvp.Value);
                first = false;
            }

            sb.Append(" WHERE ");
            first = true;
            foreach (var kvp in primaryKeyColumns)
            {
                if (!first) sb.Append(" AND ");
                sb.Append(QuoteIdentifier(kvp.Key));
                sb.Append(" = ");
                sb.Append(kvp.Value);
                first = false;
            }

            sb.Append(';');
            return sb.ToString();
        }

        /// <inheritdoc/>
        public string BuildRowCountEstimateQuery(string database, string table)
        {
            return "SELECT TABLE_ROWS FROM information_schema.TABLES WHERE TABLE_SCHEMA = @Schema AND TABLE_NAME = @Table;";
        }
    }
}
