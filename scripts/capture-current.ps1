$sig = @'
[DllImport("user32.dll", SetLastError = true)]
public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, uint nFlags);
'@
Add-Type -MemberDefinition $sig -Name "NativeMethods" -Namespace "Test"
Add-Type -AssemblyName System.Drawing, UIAutomationClient
$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$p = Start-Process -FilePath $exePath -PassThru
Start-Sleep -Seconds 3
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $p.Id)
$appWin = [System.Windows.Automation.AutomationElement]::RootElement.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)
if ($appWin) {
    $hwnd = [IntPtr]$appWin.Current.NativeWindowHandle
    $rect = $appWin.Current.BoundingRectangle
    $bmp = New-Object System.Drawing.Bitmap([int]$rect.Width, [int]$rect.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    [Test.NativeMethods]::PrintWindow($hwnd, $hdc, 2)
    $g.ReleaseHdc($hdc)
    $bmp.Save("C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363\app_screen.png")
    Write-Host "Saved screen. Rect: $($rect.ToString())"
} else {
    Write-Host "App window not found."
}
Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
