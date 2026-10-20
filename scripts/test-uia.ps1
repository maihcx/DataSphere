Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$root = [System.Windows.Automation.AutomationElement]::RootElement
$children = $root.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)

Write-Host "UIA Root Children Count: $($children.Count)"
foreach ($child in $children) {
    Write-Host "Name: '$($child.Current.Name)' | Class: '$($child.Current.ClassName)' | ProcessId: $($child.Current.ProcessId)"
}
