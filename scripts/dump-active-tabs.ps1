Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

$p = Get-Process -Name "DataSphere" -ErrorAction SilentlyContinue
if (!$p) {
    Write-Host "DataSphere is not running"
    exit
}

$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $p.Id)
$wins = [System.Windows.Automation.AutomationElement]::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)

Write-Host "Found $($wins.Count) windows."
for ($i = 0; $i -lt $wins.Count; $i++) {
    $w = $wins[$i]
    Write-Host "`nWindow $i Handle=$($w.Current.NativeWindowHandle) Name='$($w.Current.Name)' Rect=$($w.Current.BoundingRectangle)"
    $elements = $w.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
    Write-Host "Total elements: $($elements.Count)"
    foreach ($e in $elements) {
        if ($e.Current.ControlType.ProgrammaticName -in @("ControlType.TabItem", "ControlType.Button", "ControlType.Header")) {
            Write-Host "  $($e.Current.ControlType.ProgrammaticName) '$($e.Current.Name)' Bounds=$($e.Current.BoundingRectangle)"
        }
    }
}
