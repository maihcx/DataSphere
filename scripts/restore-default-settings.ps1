$p = "$env:LOCALAPPDATA\DataSphere\userdata.json"
$j = Get-Content $p -Raw | ConvertFrom-Json
$j.IThemeType = "Default"
$j.ISystemBackdropType = "Mica"
$j | ConvertTo-Json | Set-Content $p
Write-Host "Restored userdata.json to Default + Mica"
