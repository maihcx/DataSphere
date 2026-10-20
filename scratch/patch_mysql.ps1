$ErrorActionPreference = "Stop"

$path = "DataSphere/Services/Database/Connection/MySqlDatabaseConnection.cs"
$content = [System.IO.File]::ReadAllText($path)

$method = @"
        /// <summary>
        /// Retrieves a paginated slice of records along with table columns and total record count.
        /// </summary>
        public async Task<TableDataPage> GetTableDataPageAsync(string databaseName, string tableName, int page, int pageSize, CancellationToken cancellationToken = default)
        {
            if (_connection == null || !IsConnected)
            {
                throw new InvalidOperationException("Database is not connected.");
            }

            var resultPage = new TableDataPage
            {
                CurrentPage = Math.Max(1, page),
                PageSize = Math.Max(1, pageSize)
            };

            // 1. Get total record count
            try
            {
                string countQuery = $"SELECT COUNT(*) FROM `{databaseName}`.`{tableName}`;";
                using (var countCmd = new MySqlCommand(countQuery, _connection))
                {
                    var countObj = await countCmd.ExecuteScalarAsync(cancellationToken);
                    if (countObj != null && long.TryParse(countObj.ToString(), out long total))
                    {
                        resultPage.TotalRecords = total;
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[MySQL] Count query failed: {ex.Message}");
            }

            // 2. Query paginated records
            int offset = (resultPage.CurrentPage - 1) * resultPage.PageSize;
            string dataQuery = $"SELECT * FROM `{databaseName}`.`{tableName}` LIMIT @Limit OFFSET @Offset;";

            using (var dataCmd = new MySqlCommand(dataQuery, _connection))
            {
                dataCmd.Parameters.AddWithValue("@Limit", resultPage.PageSize);
                dataCmd.Parameters.AddWithValue("@Offset", offset);

                using var reader = await dataCmd.ExecuteReaderAsync(cancellationToken);

                for (int i = 0; i < reader.FieldCount; i++)
                {
                    resultPage.Columns.Add(new Column
                    {
                        Name = reader.GetName(i),
                        DataType = reader.GetFieldType(i).Name
                    });
                }

                int rowIndex = offset + 1;
                while (await reader.ReadAsync(cancellationToken))
                {
                    var rowData = new TableRowData
                    {
                        RowIndex = rowIndex++
                    };

                    for (int i = 0; i < reader.FieldCount; i++)
                    {
                        object val = reader.GetValue(i);
                        rowData.Cells.Add(val == DBNull.Value || val == null ? "NULL" : val.ToString() ?? string.Empty);
                    }

                    resultPage.Rows.Add(rowData);
                }
            }

            return resultPage;
        }
    }
}
"@

if ($content -notmatch "GetTableDataPageAsync") {
    $lastBrace = $content.LastIndexOf('}')
    $secondLastBrace = $content.LastIndexOf('}', $lastBrace - 1)
    $truncated = $content.Substring(0, $secondLastBrace)
    $final = $truncated + $method
    [System.IO.File]::WriteAllText($path, $final, [System.Text.Encoding]::UTF8)
    Write-Output "UPDATED"
} else {
    Write-Output "ALREADY_PRESENT"
}
