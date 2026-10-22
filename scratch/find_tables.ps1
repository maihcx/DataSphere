Add-Type -Path "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\MySqlConnector.dll"
$conn = New-Object MySqlConnector.MySqlConnection("Server=localhost;Port=3306;User ID=root;Password=;")
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandText = "SELECT table_schema, table_name, table_rows FROM information_schema.tables WHERE table_name LIKE '%product%' OR table_rows > 5000 ORDER BY table_rows DESC LIMIT 20;"
$reader = $cmd.ExecuteReader()
while ($reader.Read()) {
    Write-Host ($reader.GetString(0) + "." + $reader.GetString(1) + " (Rows: " + $reader.GetValue(2) + ")")
}
$conn.Close()
