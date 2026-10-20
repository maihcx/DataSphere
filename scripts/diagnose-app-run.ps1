$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"

Write-Host "Starting DataSphere.exe..."
$p = Start-Process -FilePath $exePath -WorkingDirectory $workingDir -PassThru
Write-Host "Process ID: $($p.Id)"

for ($i = 0; $i -lt 10; $i++) {
    Start-Sleep -Milliseconds 500
    $p.Refresh()
    if ($p.HasExited) {
        Write-Host "Process has exited! Exit code: $($p.ExitCode)"
        break
    } else {
        Write-Host "Running... (Title: '$($p.MainWindowTitle)', HWND: $($p.MainWindowHandle))"
    }
}

if (-not $p.HasExited) {
    Write-Host "DataSphere is running stably!"
}
