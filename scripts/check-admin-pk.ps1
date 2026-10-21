Add-Type -Path 'D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\MySqlConnector.dll'
$c = New-Object MySqlConnector.MySqlConnection('Server=127.0.0.1;Port=3306;User ID=root;Password=;')
$c.Open()
$cmd = $c.CreateCommand()
$cmd.CommandText = "SHOW KEYS FROM ngocthamcatalog.admin WHERE Key_name = 'PRIMARY';"
$r = $cmd.ExecuteReader()
while ($r.Read()) {
    Write-Host "PK Column: " $r["Column_name"]
}
$r.Close()

$cmd.CommandText = "SELECT COLUMN_NAME, COLUMN_KEY FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'ngocthamcatalog' AND TABLE_NAME = 'admin';"
$r2 = $cmd.ExecuteReader()
while ($r2.Read()) {
    Write-Host "Col: " $r2["COLUMN_NAME"] " Key: " $r2["COLUMN_KEY"]
}
$r2.Close()
$c.Close()
