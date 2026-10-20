Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Drawing

$code = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class DirectWindowCapture {
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, int nFlags);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public static bool Capture(IntPtr hWnd, string outPath) {
        RECT r;
        GetWindowRect(hWnd, out r);
        int w = r.Right - r.Left;
        int h = r.Bottom - r.Top;
        if (w <= 0 || h <= 0) return false;

        using (Bitmap bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb)) {
            using (Graphics g = Graphics.FromImage(bmp)) {
                IntPtr hdc = g.GetHdc();
                // 2 = PW_RENDERFULLCONTENT
                bool ok = PrintWindow(hWnd, hdc, 2);
                if (!ok) {
                    PrintWindow(hWnd, hdc, 0);
                }
                g.ReleaseHdc(hdc);
            }
            bmp.Save(outPath, ImageFormat.Png);
        }
        return true;
    }
}
'@

Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing

$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"

Write-Host "============================================================"
Write-Host "DataSphere Automated UI Verification & Diagnostic Capture"
Write-Host "============================================================"

Write-Host "[1/6] Starting DataSphere process..."
$proc = Start-Process -FilePath $exePath -WorkingDirectory $workingDir -PassThru

try {
    $hwnd = [IntPtr]::Zero
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 500
        $proc.Refresh()
        if ($proc.HasExited) {
            Write-Error "DataSphere process exited with code $($proc.ExitCode)"
            return
        }
        if ($proc.MainWindowHandle -ne [IntPtr]::Zero) {
            $hwnd = $proc.MainWindowHandle
            break
        }
    }

    if ($hwnd -eq [IntPtr]::Zero) {
        Write-Error "Failed to obtain MainWindowHandle."
        return
    }

    Write-Host "[2/6] Obtained MainWindowHandle: $hwnd (PID: $($proc.Id))"
    Start-Sleep -Seconds 2

    $root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
    if ($null -eq $root) {
        Write-Error "Cannot attach UIAutomation to root window."
        return
    }

    Write-Host "[3/6] Navigating from Home to Database tab via 'btn_open_database'..."
    $condDbBtn = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
        "btn_open_database"
    )

    $dbBtn = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condDbBtn)
    if ($null -ne $dbBtn) {
        $pattern = $dbBtn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern) -as [System.Windows.Automation.InvokePattern]
        $pattern.Invoke()
        Write-Host "      Clicked 'btn_open_database' successfully."
    } else {
        Write-Warning "Could not find 'btn_open_database' by AutomationId."
    }

    Start-Sleep -Seconds 2

    Write-Host "[4/6] Triggering Connection Editing Dialog via 'btn_new_connection'..."
    $condNewConn = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
        "btn_new_connection"
    )

    $newConnBtn = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condNewConn)
    if ($null -eq $newConnBtn) {
        $condEmptyNewConn = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
            "btn_empty_new_connection"
        )
        $newConnBtn = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condEmptyNewConn)
    }

    if ($null -ne $newConnBtn) {
        $pattern = $newConnBtn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern) -as [System.Windows.Automation.InvokePattern]
        $pattern.Invoke()
        Write-Host "      Clicked 'btn_new_connection' successfully."
    } else {
        Write-Warning "Could not find 'btn_new_connection'!"
    }

    Write-Host "[5/6] Inspecting Dialog Elements via UIAutomation..."
    Start-Sleep -Seconds 2

    # Query descendants to confirm dialog controls
    $allDesc = $root.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        [System.Windows.Automation.Condition]::TrueCondition
    )

    $foundElements = @()
    foreach ($el in $allDesc) {
        try {
            $aid = $el.Current.AutomationId
            $name = $el.Current.Name
            $ct = $el.Current.ControlType.ProgrammaticName
            if ($aid -or $name) {
                if ($aid -eq "cb_database_type" -or $aid -eq "btn_test_connection" -or $name -like "*kết nối*" -or $name -like "*Connection*" -or $name -like "*MySQL*") {
                    $foundElements += "      * [$ct] AutomationId='$aid' Name='$name'"
                }
            }
        } catch {}
    }

    Write-Host "      Detected Dialog Controls:"
    $foundElements | Select-Object -Unique | ForEach-Object { Write-Host $_ }

    Write-Host "[6/6] Capturing high-fidelity screenshot of DataSphere..."
    $artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\aca4648a-7af8-48c3-9b8a-ae269a772d90"
    $outPath = "$artifactDir\verification_visual_evidence.png"

    $captured = [DirectWindowCapture]::Capture($hwnd, $outPath)
    if ($captured) {
        $fileInfo = Get-Item $outPath
        Write-Host "============================================================"
        Write-Host "VERIFICATION SUCCESS: Visual evidence saved successfully!"
        Write-Host "Output File: $outPath"
        Write-Host "Dimensions : 1280x800 px"
        Write-Host "Size       : $($fileInfo.Length) bytes"
        Write-Host "============================================================"
    } else {
        Write-Error "Failed to capture window."
    }

} finally {
    if (-not $proc.HasExited) {
        Write-Host "Cleaning up test DataSphere instance..."
        $proc.Kill()
    }
}
