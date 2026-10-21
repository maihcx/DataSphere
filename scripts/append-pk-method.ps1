$path = "D:\DEV\C#DOTNET\DataSphere\DataSphere\Services\Database\Connection\MySqlDatabaseConnection.cs"
$content = [System.IO.File]::ReadAllText($path)

$method = @"

        /// <summary>
        /// Asynchronously retrieves the primary key column names for the specified database table.
        /// </summary>
        /// <param name="databaseName">The owning database schema name.</param>
        /// <param name="tableName">The target table name.</param>
        /// <param name="cancellationToken">Cancellation token to abort the query.</param>
        /// <returns>A read-only list of primary key column names in ordinal sequence.</returns>
        public async Task<IReadOnlyList<string>> GetPrimaryKeysAsync(string databaseName, string tableName, CancellationToken cancellationToken = default)
        {
            if (_connection == null || !IsConnected)
                throw new InvalidOperationException("Database is not connected.");

            if (string.IsNullOrWhiteSpace(databaseName))
                throw new ArgumentException("Database name cannot be null or empty.", nameof(databaseName));

            if (string.IsNullOrWhiteSpace(tableName))
                throw new ArgumentException("Table name cannot be null or empty.", nameof(tableName));

            var primaryKeys = new List<string>();
            const string pkQuery = @"
                SELECT COLUMN_NAME
                FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
                WHERE TABLE_SCHEMA = @schema AND TABLE_NAME = @table AND CONSTRAINT_NAME = 'PRIMARY'
                ORDER BY ORDINAL_POSITION;";

            using (var cmd = new MySqlCommand(pkQuery, _connection))
            {
                cmd.Parameters.AddWithValue("@schema", databaseName);
                cmd.Parameters.AddWithValue("@table", tableName);

                using var reader = await cmd.ExecuteReaderAsync(cancellationToken).ConfigureAwait(false);
                while (await reader.ReadAsync(cancellationToken).ConfigureAwait(false))
                {
                    primaryKeys.Add(reader.GetString(0));
                }
            }

            return primaryKeys;
        }
    }
}
"@

$lastBraces = $content.LastIndexOf("    }`r`n}")
if ($lastBraces -lt 0) {
    $lastBraces = $content.LastIndexOf("    }`n}")
}
if ($lastBraces -ge 0) {
    $newContent = $content.Substring(0, $lastBraces) + $method
    [System.IO.File]::WriteAllText($path, $newContent, [System.Text.Encoding]::UTF8)
    Write-Host "Successfully added GetPrimaryKeysAsync to MySqlDatabaseConnection.cs"
} else {
    Write-Host "Could not find last braces in MySqlDatabaseConnection.cs"
}
