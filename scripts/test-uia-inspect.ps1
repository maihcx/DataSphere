Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"

Write-Host "Launching DataSphere..."
$proc = Start-Process -FilePath $exePath -WorkingDirectory $workingDir -PassThru

try {
    Start-Sleep -Seconds 3

    $appEl = [System.Windows.Automation.AutomationElement]::FromHandle($proc.MainWindowHandle)
    if ($null -eq $appEl) {
        Write-Host "Failed to get AutomationElement from handle"
        return
    }

    Write-Host "Found App AutomationElement: $($appEl.Current.Name) ($($appEl.Current.ControlType.ProgrammaticName))"

    # Find all Descendants
    $allDesc = $appEl.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        [System.Windows.Automation.Condition]::TrueCondition
    )

    Write-Host "Total elements: $($allDesc.Count)"
    $buttons = @()
    $tabs = @()
    foreach ($el in $allDesc) {
        try {
            $ct = $el.Current.ControlType.ProgrammaticName
            $name = $el.Current.Name
            $aid = $el.Current.AutomationId
            if ($ct -eq "ControlType.Button" -or $ct -eq "ControlType.TabItem" -or $ct -eq "ControlType.ListItem") {
                Write-Host "Element: [$ct] Name='$name', AutoId='$aid'"
            }
        } catch {}
    }
} finally {
    if (-not $proc.HasExited) {
        $proc.Kill()
    }
}
