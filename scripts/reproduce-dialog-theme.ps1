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

public class DialogReproducer {
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
        bool success = CreateProcess(
            exePath,
            null,
            IntPtr.Zero,
            IntPtr.Zero,
            false,
            0,
            IntPtr.Zero,
            workingDir,
            ref si,
            out pi);

        if (!success) {
            int err = Marshal.GetLastWin32Error();
            throw new Exception("CreateProcess failed with win32 error code: " + err);
        }

        return pi.dwProcessId;
    }

    public static void PhysicalLeftClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
        Thread.Sleep(50);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
        Thread.Sleep(200);
    }

    public static void CaptureWindow(IntPtr hWnd, string savePath) {
        RECT rect;
        GetWindowRect(hWnd, out rect);
        int width = rect.Right - rect.Left;
        int height = rect.Bottom - rect.Top;
        if (width <= 0 || height <= 0) {
            width = 1280;
            height = 800;
        }

        using (Bitmap bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb)) {
            using (Graphics g = Graphics.FromImage(bmp)) {
                IntPtr hdc = g.GetHdc();
                try {
                    PrintWindow(hWnd, hdc, 2); // PW_RENDERFULLCONTENT = 2
                } finally {
                    g.ReleaseHdc(hdc);
                }
            }
            bmp.Save(savePath, ImageFormat.Png);
        }
    }

    public static string ReproduceDialog(int targetPid, string savePath) {
        string log = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk == IntPtr.Zero) {
                log += "Failed to open default desktop.\n";
                return;
            }
            SetThreadDesktop(hDesk);

            try {
                AutomationElement appWin = null;
                for (int i = 0; i < 20; i++) {
                    var p = Process.GetProcessById(targetPid);
                    if (p != null && p.MainWindowHandle != IntPtr.Zero) {
                        appWin = AutomationElement.FromHandle(p.MainWindowHandle);
                        break;
                    }
                    Thread.Sleep(500);
                }

                if (appWin == null) {
                    log += "Could not find main window.\n";
                    return;
                }

                IntPtr hwnd = (IntPtr)appWin.Current.NativeWindowHandle;
                SetForegroundWindow(hwnd);
                Thread.Sleep(1500);

                // 1. Click Database Button to navigate to DatabasePage
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
                    PhysicalLeftClick(cx, cy);
                    Thread.Sleep(2000);
                }

                // 2. In DatabasePage, log all buttons found and click the toolbar button
                AutomationElement newConnBtn = null;
                var allDbButtons = appWin.FindAll(TreeScope.Descendants, btnCond);
                log += "Total buttons found: " + allDbButtons.Count + "\n";
                foreach (AutomationElement btn in allDbButtons) {
                    Rect r = btn.Current.BoundingRectangle;
                    log += "Button: name='" + btn.Current.Name + "', rect=" + r.ToString() + "\n";
                    if (r.Width > 100 && r.Width < 200 && r.Height > 25 && r.Height < 40 && r.Y > 80 && r.Y < 120) {
                        if (newConnBtn == null || r.X < newConnBtn.Current.BoundingRectangle.X) {
                            newConnBtn = btn;
                        }
                    }
                }

                if (newConnBtn != null) {
                    Rect r = newConnBtn.Current.BoundingRectangle;
                    int cx = (int)(r.X + r.Width / 2);
                    int cy = (int)(r.Y + r.Height / 2);
                    log += "Clicking 'Tạo kết nối mới' button at (" + cx + ", " + cy + ")...\n";
                    PhysicalLeftClick(cx, cy);
                    Thread.Sleep(2000);
                } else {
                    log += "Could not find 'Tạo kết nối mới' button.\n";
                }

                // Wait for ContentDialog
                Thread.Sleep(1500);

                // Capture window with popup
                CaptureWindow(hwnd, savePath);
                log += "Captured window with dialog: " + savePath + "\n";

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

if (-not ([System.Management.Automation.PSTypeName]'DialogReproducer').Type) {
    Add-Type -TypeDefinition $source -ReferencedAssemblies WindowsBase, UIAutomationClient, UIAutomationTypes, System.Drawing
}

$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"
$userStorePath = "$env:LOCALAPPDATA\DataSphere\userdata.json"

function TerminateExisting {
    Get-Process -Name "DataSphere" -ErrorAction SilentlyContinue | ForEach-Object {
        Stop-Process -Id $_.Id -Force
    }
    Start-Sleep -Milliseconds 600
}

try {
    TerminateExisting

    # Ensure Dark Theme + Acrylic Backdrop in userdata.json
    $cfg = @{
        "IThemeType" = "Dark"
        "ISystemBackdropType" = "Acrylic"
        "Language" = "vi"
    } | ConvertTo-Json
    Set-Content -Path $userStorePath -Value $cfg -Encoding UTF8

    Write-Host "Launching DataSphere in Dark mode + Acrylic..." -ForegroundColor Cyan
    $pid1 = [DialogReproducer]::LaunchApp($exePath, $workingDir)
    Start-Sleep -Seconds 3

    $diagPath = Join-Path $ArtifactDir "04_verified_dialog_dark_smoke.png"
    $log = [DialogReproducer]::ReproduceDialog($pid1, $diagPath)
    Write-Host $log

} finally {
    TerminateExisting
}
