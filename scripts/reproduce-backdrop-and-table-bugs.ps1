param(
    [string]$ArtifactDir = "C:\Users\huynh\.gemini\antigravity\brain\82efb6f9-3dcc-4e7e-ac8a-04c9e2fa180f"
)

$ErrorActionPreference = "Stop"

$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class BugReproVerifier {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct STARTUPINFO {
        public int cb;
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
        public int dwX;
        public int dwY;
        public int dwXSize;
        public int dwYSize;
        public int dwXCountChars;
        public int dwYCountChars;
        public int dwFillAttribute;
        public int dwFlags;
        public short wShowWindow;
        public short cbReserved2;
        public IntPtr lpReserved2;
        public IntPtr hStdInput;
        public IntPtr hStdOutput;
        public IntPtr hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION {
        public IntPtr hProcess;
        public IntPtr hThread;
        public int dwProcessId;
        public int dwThreadId;
    }

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool CreateProcess(
        string lpApplicationName,
        string lpCommandLine,
        IntPtr lpProcessAttributes,
        IntPtr lpThreadAttributes,
        bool bInheritHandles,
        uint dwCreationFlags,
        IntPtr lpEnvironment,
        string lpCurrentDirectory,
        ref STARTUPINFO lpStartupInfo,
        out PROCESS_INFORMATION lpProcessInformation);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseDesktop(IntPtr hDesktop);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, int dwExtraInfo);

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

    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;

    public static int LaunchApp(string exePath, string workingDir) {
        STARTUPINFO si = new STARTUPINFO();
        si.cb = Marshal.SizeOf(si);
        si.lpDesktop = @"WinSta0\default";

        PROCESS_INFORMATION pi = new PROCESS_INFORMATION();
        bool success = CreateProcess(exePath, null, IntPtr.Zero, IntPtr.Zero, false, 0, IntPtr.Zero, workingDir, ref si, out pi);
        if (!success) {
            int err = Marshal.GetLastWin32Error();
            throw new Exception("CreateProcess failed with win32 error code: " + err);
        }
        return pi.dwProcessId;
    }

    public static void PhysicalClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(80);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
        Thread.Sleep(80);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
        Thread.Sleep(200);
    }

    public static bool CaptureWindow(IntPtr hWnd, string savePath) {
        RECT rect;
        if (!GetWindowRect(hWnd, out rect)) return false;
        int width = rect.Right - rect.Left;
        int height = rect.Bottom - rect.Top;
        if (width <= 0 || height <= 0) return false;

        using (Bitmap bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb)) {
            using (Graphics g = Graphics.FromImage(bmp)) {
                IntPtr hdc = g.GetHdc();
                try {
                    bool res = PrintWindow(hWnd, hdc, 2); // 2 = PW_RENDERFULLCONTENT
                    if (!res) PrintWindow(hWnd, hdc, 0);
                } finally {
                    g.ReleaseHdc(hdc);
                }
            }
            bmp.Save(savePath, ImageFormat.Png);
        }
        return true;
    }

    public static string RunDiagnosticPass(int pid, string action, string savePath1, string savePath2) {
        string log = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) {
                log += "Failed to open default desktop: " + Marshal.GetLastWin32Error() + "\n";
                return;
            }
            SetThreadDesktop(hDesk);

            try {
                AutomationElement appWin = null;
                IntPtr hwnd = IntPtr.Zero;

                for (int i = 0; i < 35; i++) {
                    Thread.Sleep(300);
                    var cond = new PropertyCondition(AutomationElement.ProcessIdProperty, pid);
                    appWin = AutomationElement.RootElement.FindFirst(TreeScope.Children, cond);
                    if (appWin != null) {
                        hwnd = (IntPtr)appWin.Current.NativeWindowHandle;
                        log += "Found DataSphere window (HWND=" + hwnd + ")\n";
                        break;
                    }
                }

                if (appWin == null) {
                    log += "ERROR: Window not found for PID " + pid + "\n";
                    return;
                }

                SetForegroundWindow(hwnd);
                Thread.Sleep(1200);

                if (action == "SolidWhiteout") {
                    // 1. Capture initial Home
                    CaptureWindow(hwnd, savePath1);
                    log += "Captured Solid initial view: " + savePath1 + "\n";

                    // 2. Click Settings button/tab
                    var nameCond = new PropertyCondition(AutomationElement.NameProperty, "Cài đặt");
                    var settingsElem = appWin.FindFirst(TreeScope.Descendants, nameCond);
                    if (settingsElem == null) {
                        settingsElem = appWin.FindFirst(TreeScope.Descendants, new PropertyCondition(AutomationElement.NameProperty, "Settings"));
                    }

                    if (settingsElem != null) {
                        Rect r = settingsElem.Current.BoundingRectangle;
                        int cx = (int)(r.X + r.Width / 2);
                        int cy = (int)(r.Y + r.Height / 2);
                        log += "Located Settings element at (" + cx + ", " + cy + "), clicking...\n";
                        PhysicalClick(cx, cy);
                        Thread.Sleep(2000);
                    } else {
                        log += "WARNING: Settings tab element not found by name, searching controls...\n";
                    }

                    CaptureWindow(hwnd, savePath2);
                    log += "Captured Solid settings view: " + savePath2 + "\n";
                }
                else if (action == "AcrylicTable") {
                    // Click Database Card on Home page
                    var btnCond = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button);
                    var allButtons = appWin.FindAll(TreeScope.Descendants, btnCond);
                    AutomationElement dbBtn = null;
                    foreach (AutomationElement btn in allButtons) {
                        Rect r = btn.Current.BoundingRectangle;
                        if (r.Width > 200 && r.Height > 60) {
                            if (dbBtn == null || r.X < dbBtn.Current.BoundingRectangle.X) {
                                dbBtn = btn;
                            }
                        }
                    }

                    if (dbBtn != null) {
                        Rect r = dbBtn.Current.BoundingRectangle;
                        int cx = (int)(r.X + r.Width / 2);
                        int cy = (int)(r.Y + r.Height / 2);
                        log += "Clicking Database button at (" + cx + ", " + cy + ")...\n";
                        PhysicalClick(cx, cy);
                        Thread.Sleep(2500);
                    }

                    CaptureWindow(hwnd, savePath1);
                    log += "Captured Acrylic Database Page view: " + savePath1 + "\n";
                }
            } catch (Exception ex) {
                log += "EXCEPTION: " + ex.ToString() + "\n";
            } finally {
                CloseDesktop(hDesk);
            }
        });

        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join();
        return log;
    }
}
'@

if (-not ([System.Management.Automation.PSTypeName]'BugReproVerifier').Type) {
    Add-Type -TypeDefinition $source -ReferencedAssemblies WindowsBase, UIAutomationClient, UIAutomationTypes, System.Drawing
}

$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"
$userStorePath = "$env:LOCALAPPDATA\DataSphere\userdata.json"

$originalUserData = $null
if (Test-Path $userStorePath) {
    $originalUserData = Get-Content $userStorePath -Raw
}

function TerminateExisting {
    Get-Process -Name "DataSphere" -ErrorAction SilentlyContinue | ForEach-Object {
        Stop-Process -Id $_.Id -Force
    }
    Start-Sleep -Milliseconds 600
}

try {
    Write-Host "=== TEST 1: Reproduce Solid Backdrop + Dark Mode Whiteout ===" -ForegroundColor Cyan
    TerminateExisting

    $testConfig1 = @{
        "IThemeType" = "Dark"
        "Language" = "vi"
        "ISystemBackdropType" = "Solid"
        "Window_Width" = 1062
        "Window_Height" = 784
        "IsWindow_Maximized" = $false
        "StartUpCode" = "xv2"
        "Window_Left" = 697
        "Window_Top" = 178
    } | ConvertTo-Json -Depth 5
    Set-Content -Path $userStorePath -Value $testConfig1 -Encoding utf8

    $pid1 = [BugReproVerifier]::LaunchApp($exePath, $workingDir)
    Write-Host "Launched PID: $pid1 (Solid + Dark)" -ForegroundColor Green

    $snap1 = Join-Path $ArtifactDir "01_diagnostic_solid_dark_home.png"
    $snap2 = Join-Path $ArtifactDir "02_diagnostic_solid_dark_settings.png"
    $log1 = [BugReproVerifier]::RunDiagnosticPass($pid1, "SolidWhiteout", $snap1, $snap2)
    Write-Host $log1

    TerminateExisting

    Write-Host "`n=== TEST 2: Reproduce Acrylic Backdrop + Dark Mode Database View ===" -ForegroundColor Cyan
    $testConfig2 = @{
        "IThemeType" = "Dark"
        "Language" = "vi"
        "ISystemBackdropType" = "Acrylic"
        "Window_Width" = 1100
        "Window_Height" = 800
        "IsWindow_Maximized" = $false
        "StartUpCode" = "xv2"
        "Window_Left" = 600
        "Window_Top" = 150
    } | ConvertTo-Json -Depth 5
    Set-Content -Path $userStorePath -Value $testConfig2 -Encoding utf8

    $pid2 = [BugReproVerifier]::LaunchApp($exePath, $workingDir)
    Write-Host "Launched PID: $pid2 (Acrylic + Dark)" -ForegroundColor Green

    $snapDb = Join-Path $ArtifactDir "03_diagnostic_acrylic_dark_database_page.png"
    $log2 = [BugReproVerifier]::RunDiagnosticPass($pid2, "AcrylicTable", $snapDb, "")
    Write-Host $log2

    TerminateExisting

} finally {
    if ($originalUserData) {
        Set-Content -Path $userStorePath -Value $originalUserData -Encoding utf8
    }
}

Write-Host "=== Diagnostic Execution Completed ===" -ForegroundColor Green
