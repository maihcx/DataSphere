using System;
using System.Collections.ObjectModel;
using System.Collections.Generic;
using System.Threading.Tasks;
using DataSphere.Models;
using DataSphere.Models.Database;
using MySqlConnector;

namespace DataSphere.Services.Database
{
    /// <summary>
    /// Provides MySQL database connection and metadata retrieval logic.
    /// </summary>
    public class MySqlDatabaseConnection : IDatabaseConnection
    {
        private MySqlConnection? _connection;

        private ConnectionModel Model;

        public MySqlDatabaseConnection(ConnectionModel model)
        {
            Model = model;
        }

        /// <summary>
        /// Indicates whether the current connection is open.
        /// </summary>
        public bool IsConnected => _connection?.State == System.Data.ConnectionState.Open;

        /// <summary>
        /// Opens a connection to the MySQL database using the provided model.
        /// </summary>
        public async Task<bool> ConnectAsync()
        {
            try
            {
                string connStr =
                    $"Server={Model.Host};Port={Model.Port};User ID={Model.User};Password={Model.Password};";
                _connection = new MySqlConnection(connStr);
                await _connection.OpenAsync().ConfigureAwait(false);
                return IsConnected;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[MySQL] Connection failed: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// Closes and disposes the active connection.
        /// </summary>
        public async Task DisconnectAsync()
        {
            if (_connection != null)
            {
                await _connection.CloseAsync().ConfigureAwait(false);
                _connection.Dispose();
                _connection = null;
            }
        }

        /// <summary>
        /// Tests whether the connection parameters are valid.
        /// </summary>
        public async Task<bool> TestConnectionAsync()
        {
            try
            {
                await ConnectAsync().ConfigureAwait(false);
                await DisconnectAsync().ConfigureAwait(false);
                return true;
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// Retrieves detailed table metadata, including columns, keys, and row count.
        /// </summary>
        /// <param name="tableName">The table name to query.</param>
        /// <returns>A fully populated <see cref="Table"/> object.</returns>
        public async Task<Table?> GetTableInfoAsync(string tableName)
        {
            if (_connection == null || !IsConnected)
                throw new InvalidOperationException("Database is not connected.");

            var table = new Table
            {
                Name = tableName,
                Schema = _connection.Database,
                Columns = new List<Column>(),
                PrimaryKeys = new List<string>(),
                ForeignKeys = new List<ForeignKey>()
            };

            // Retrieve column metadata
            const string columnQuery = @"
                SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, COLUMN_KEY, COLUMN_COMMENT
                FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = @schema AND TABLE_NAME = @table;";

            using (var cmd = new MySqlCommand(columnQuery, _connection))
            {
                cmd.Parameters.AddWithValue("@schema", _connection.Database);
                cmd.Parameters.AddWithValue("@table", tableName);

                using var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false);
                while (await reader.ReadAsync().ConfigureAwait(false))
                {
                    var column = new Column
                    {
                        Name = reader.GetString("COLUMN_NAME"),
                        DataType = reader.GetString("DATA_TYPE"),
                        IsNullable = reader.GetString("IS_NULLABLE") == "YES",
                        DefaultValue = reader["COLUMN_DEFAULT"]?.ToString(),
                        IsPrimaryKey = reader.GetString("COLUMN_KEY") == "PRI",
                        Comment = reader["COLUMN_COMMENT"]?.ToString()
                    };

                    table.Columns.Add(column);

                    if (column.IsPrimaryKey)
                        table.PrimaryKeys.Add(column.Name);
                }
            }

            // Retrieve foreign key metadata
            const string fkQuery = @"
                SELECT 
                    CONSTRAINT_NAME,
                    COLUMN_NAME,
                    REFERENCED_TABLE_NAME,
                    REFERENCED_COLUMN_NAME
                FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
                WHERE TABLE_SCHEMA = @schema AND TABLE_NAME = @table
                      AND REFERENCED_TABLE_NAME IS NOT NULL;";

            using (var cmd = new MySqlCommand(fkQuery, _connection))
            {
                cmd.Parameters.AddWithValue("@schema", _connection.Database);
                cmd.Parameters.AddWithValue("@table", tableName);

                using var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false);
                while (await reader.ReadAsync().ConfigureAwait(false))
                {
                    var fk = new ForeignKey
                    {
                        Name = reader.GetString("CONSTRAINT_NAME"),
                        Column = reader.GetString("COLUMN_NAME"),
                        ReferencedTable = reader.GetString("REFERENCED_TABLE_NAME"),
                        ReferencedColumn = reader.GetString("REFERENCED_COLUMN_NAME")
                    };

                    table.ForeignKeys.Add(fk);
                }
            }

            // Count rows safely (may be slow for huge tables)
            try
            {
                string countQuery = $"SELECT COUNT(*) FROM `{tableName}`;";
                using var cmd = new MySqlCommand(countQuery, _connection);
                table.RowCount = Convert.ToInt64(await cmd.ExecuteScalarAsync().ConfigureAwait(false));
            }
            catch
            {
                table.RowCount = null;
            }

            return table;
        }

        /// <summary>
        /// Retrieves all tables from the specified database with basic metadata.
        /// </summary>
        /// <param name="dbName">The name of the database to query.</param>
        /// <returns>An observable collection of <see cref="Table"/> objects, or null if no tables found.</returns>
        public async Task<ObservableCollection<Table>?> GetAllTablesAsync(string dbName)
        {
            if (_connection == null || !IsConnected)
                throw new InvalidOperationException("Database is not connected.");

            if (string.IsNullOrWhiteSpace(dbName))
                throw new ArgumentException("Database name cannot be null or empty.", nameof(dbName));

            var tables = new ObservableCollection<Table>();

            const string query = @"
                SELECT TABLE_NAME, TABLE_ROWS, TABLE_COMMENT
                FROM INFORMATION_SCHEMA.TABLES
                WHERE TABLE_SCHEMA = @schema AND TABLE_TYPE = 'BASE TABLE'
                ORDER BY TABLE_NAME;";

            using (var cmd = new MySqlCommand(query, _connection))
            {
                cmd.Parameters.AddWithValue("@schema", dbName);

                using var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false);
                while (await reader.ReadAsync().ConfigureAwait(false))
                {
                    var table = new Table
                    {
                        Name = reader.GetString("TABLE_NAME"),
                        Schema = dbName,
                        RowCount = reader["TABLE_ROWS"] is DBNull ? 0 : Convert.ToInt64(reader["TABLE_ROWS"]),
                        Comment = reader["TABLE_COMMENT"]?.ToString()
                    };

                    tables.Add(table);
                }
            }

            return tables.Count > 0 ? tables : null;
        }

        public async Task<ObservableCollection<DatabaseInfo>?> GetAllDatabasesAsync()
        {
            if (_connection == null || !IsConnected)
                throw new InvalidOperationException("Database is not connected.");

            var databases = new ObservableCollection<DatabaseInfo>();

            const string query = @"
                SELECT 
                    SCHEMA_NAME AS DatabaseName,
                    DEFAULT_CHARACTER_SET_NAME AS Charset,
                    DEFAULT_COLLATION_NAME AS Collation
                FROM INFORMATION_SCHEMA.SCHEMATA
                ORDER BY SCHEMA_NAME;";

            using var cmd = new MySqlCommand(query, _connection);
            using var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false);

            while (await reader.ReadAsync().ConfigureAwait(false))
            {
                databases.Add(new DatabaseInfo
                {
                    Name = reader.GetString("DatabaseName"),
                    Charset = reader["Charset"]?.ToString(),
                    Collation = reader["Collation"]?.ToString()
                });
            }

            return databases;
        }
    }
}
