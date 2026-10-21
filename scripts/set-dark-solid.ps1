$p = "$env:LOCALAPPDATA\DataSphere\userdata.json"
$j = Get-Content $p -Raw | ConvertFrom-Json
$j.IThemeType = "Dark"
$j.ISystemBackdropType = "Solid"
$j | ConvertTo-Json | Set-Content $p
Write-Host "Set userdata.json to Dark + Solid"
