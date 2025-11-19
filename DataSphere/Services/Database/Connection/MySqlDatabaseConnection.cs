using DataSphere.Models.Database;
using DataSphere.Services.Database.Interface;
using MySqlConnector;
using System.Data;
using System.Xml.Linq;

namespace DataSphere.Services.Database.Connection
{
    /// <summary>
    /// Provides MySQL database connection and metadata retrieval logic.
    /// </summary>
    public class MySqlDatabaseConnection : IDatabaseConnection
    {
        private MySqlConnection? _connection;

        private ConnectionModel Model;

        private ObservableCollection<CollationModel>? AllCollation = null;

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
                    $"Server={Model.Host};Port={Model.Port};User ID={Model.User};Password={Model.Password};AllowZeroDateTime=True;";
                _connection = new MySqlConnection(connStr);
                await _connection.OpenAsync().ConfigureAwait(false);

                await GetAllCollation();

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
                using (var cmd = new MySqlCommand(countQuery, _connection))
                {
                    table.RowCount = Convert.ToInt64(await cmd.ExecuteScalarAsync().ConfigureAwait(false));
                }
            }
            catch
            {
                table.RowCount = null;
            }

            return table;
        }

        public async Task<ObservableCollection<CollationModel>?> GetAllCollation()
        {
            if (_connection == null || !IsConnected)
                throw new InvalidOperationException("Database is not connected.");

            if (AllCollation == null)
            {
                AllCollation = new();
                const string query = @"SHOW COLLATION;";

                using (var cmd = new MySqlCommand(query, _connection))
                {
                    using var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false);
                    while (await reader.ReadAsync().ConfigureAwait(false))
                    {
                        var collation = new CollationModel
                        {
                            Collation = reader.IsDBNull("Collation") ? string.Empty : reader.GetString("Collation"),
                            Charset = reader.IsDBNull("Charset") ? string.Empty : reader.GetString("Charset"),
                            Compiled = reader.IsDBNull("Compiled") ? string.Empty : reader.GetString("Compiled"),
                            Default = reader.IsDBNull("Default") ? string.Empty : reader.GetString("Default"),
                            Id = reader.IsDBNull("Id") ? 0 : reader.GetInt32("Id"),
                            Sortlen = reader.IsDBNull("Sortlen") ? 0 : reader.GetInt32("Sortlen")
                        };

                        AllCollation.Add(collation);
                    }
                }

                return AllCollation.Count > 0 ? AllCollation : null;
            }

            return AllCollation;
        }

        public async Task<CollationModel> GetDefCollation()
        {
            if (_connection == null || !IsConnected)
                throw new InvalidOperationException("Database is not connected.");

            CollationModel? collation = new();

            const string query = @"SHOW VARIABLES LIKE 'collation_server';";

            using (var cmd = new MySqlCommand(query, _connection))
            {
                using var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false);
                while (await reader.ReadAsync().ConfigureAwait(false))
                {
                    collation = new CollationModel { Collation = reader.GetString("Value") };
                }
            }

            if (!string.IsNullOrWhiteSpace(collation.Collation))
            {
                collation = await GetCollationInfo(collation.Collation);
            }

            return collation;
        }

        public async Task<CollationModel> GetCollationInfo(string strCollation, CollationModel? collation = null)
        {
            if (_connection == null || !IsConnected)
                throw new InvalidOperationException("Database is not connected.");

            collation ??= new CollationModel();

            if (string.IsNullOrWhiteSpace(strCollation))
            {
                return collation;
            }

            if (AllCollation != null && AllCollation.Count > 0)
            {
                var cached = AllCollation.FirstOrDefault(x =>
                    x.Collation.Equals(strCollation, StringComparison.OrdinalIgnoreCase));

                if (cached != null)
                {
                    collation.Collation = cached.Collation;
                    collation.Charset = cached.Charset;
                    collation.Id = cached.Id;
                    collation.Default = cached.Default;
                    collation.Compiled = cached.Compiled;
                    collation.Sortlen = cached.Sortlen;

                }
            }

            return collation;
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

            using (var cmd = new MySqlCommand(query, _connection))
            {
                using var reader = await cmd.ExecuteReaderAsync().ConfigureAwait(false);
                while (await reader.ReadAsync().ConfigureAwait(false))
                {
                    databases.Add(new DatabaseInfo
                    {
                        Name = reader.GetString("DatabaseName"),
                        Charset = reader["Charset"].ToString() ?? string.Empty,
                        Collation = await GetCollationInfo(reader["Collation"]?.ToString() ?? "")
                    });
                }
            }

            return databases;
        }

        /// <summary>
        /// Executes a raw SQL query and returns the result as a DataTable.
        /// </summary>
        public async Task<DataTable?> ExecuteQueryAsync(string sql)
        {
            if (_connection == null || !IsConnected)
                throw new InvalidOperationException("Database is not connected.");

            if (string.IsNullOrWhiteSpace(sql))
                throw new ArgumentException("SQL query cannot be null or empty.", nameof(sql));

            try
            {
                var table = new DataTable();

                using (var cmd = new MySqlCommand(sql, _connection))
                {
                    using (var adapter = new MySqlDataAdapter(cmd))
                    {
                        await Task.Run(() =>
                        {
                            adapter.FillSchema(table, SchemaType.Source);

                            adapter.Fill(table);

                            var dateColumns = table.Columns.Cast<DataColumn>()
                        .Where(c => c.DataType == typeof(MySqlConnector.MySqlDateTime))
                        .Select(c => new { Column = c, Index = c.Ordinal })
                        .ToList();

                            if (dateColumns.Any())
                            {
                                // Tạo DataTable mới với cấu trúc giống hệt
                                var newTable = table.Clone();

                                // Đổi kiểu các cột datetime
                                foreach (var col in dateColumns)
                                {
                                    newTable.Columns[col.Index].DataType = typeof(string);
                                }

                                // Copy dữ liệu và convert
                                foreach (DataRow oldRow in table.Rows)
                                {
                                    var newRow = newTable.NewRow();
                                    for (int i = 0; i < table.Columns.Count; i++)
                                    {
                                        if (oldRow[i] is MySqlConnector.MySqlDateTime mySqlDt)
                                        {
                                            newRow[i] = mySqlDt.IsValidDateTime
                                                ? mySqlDt.GetDateTime().ToString("dd/MM/yyyy hh:mm:ss tt")
                                                : "0000-00-00 00:00:00";
                                        }
                                        else
                                        {
                                            newRow[i] = oldRow[i];
                                        }
                                    }
                                    newTable.Rows.Add(newRow);
                                }

                                table = newTable;
                            }

                        }).ConfigureAwait(false);
                    }
                }

                return table;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[MySQL] Query failed: {ex.Message}");
                return null;
            }
        }

        /// <summary>
        /// Executes an SQL query built from a fluent SQL builder.
        /// </summary>
        public async Task<DataTable?> ExecuteQueryAsync(ISqlBuilder builder)
        {
            if (builder == null)
                throw new ArgumentNullException(nameof(builder));

            string sql = builder.ToSqlString();
            return await ExecuteQueryAsync(sql).ConfigureAwait(false);
        }

        public async Task<bool> DatabaseExistsAsync(string dbname)
        {
            var databases = await GetAllDatabasesAsync();
            if (databases == null)
            {
                return false;
            }
            return databases.Any(x =>
                x.Name.Equals(dbname, StringComparison.OrdinalIgnoreCase));
        }

        public async Task CreateDatabase(DatabaseInfo databaseInfo)
        {
            string query = $@"
                CREATE DATABASE `{databaseInfo.Name.Trim()}`
                CHARACTER SET {databaseInfo.Collation.Charset}
                COLLATE {databaseInfo.Collation.Collation};";

            using (var cmd = new MySqlCommand(query, _connection))
            {
                await cmd.ExecuteNonQueryAsync();
            }
        }

        public async Task DropDatabase(DatabaseInfo databaseInfo)
        {
            string query = $@"DROP DATABASE IF EXISTS `{databaseInfo.Name.Trim()}`;";

            using (var cmd = new MySqlCommand(query, _connection))
            {
                await cmd.ExecuteNonQueryAsync();
            }
        }
    }
}
