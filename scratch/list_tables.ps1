Add-Type -Path "DataSphere/bin/Debug/net10.0-windows10.0.26100.0/win-x64/MySqlConnector.dll"
$conn = New-Object MySqlConnector.MySqlConnection("Server=localhost;User ID=root;Password=;Database=ngocthamcatalog;")
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandText = "SELECT table_name, table_rows FROM information_schema.tables WHERE table_schema = 'ngocthamcatalog' ORDER BY table_name"
$r = $cmd.ExecuteReader()
$index = 0
while ($r.Read()) {
    $name = $r[0]
    $rows = $r[1]
    if ($name -like "*product*") {
        Write-Host "Index $index : $name ($rows rows)"
    }
    $index++
}
$conn.Close()
