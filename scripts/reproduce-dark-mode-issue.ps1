$source = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Automation;

public class DarkModeReproducer {
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

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, uint nFlags);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;

    public static void PhysicalLeftClick(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(120);
        mouse_event(MOUSEEVENTF_LEFTDOWN, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(80);
        mouse_event(MOUSEEVENTF_LEFTUP, (uint)x, (uint)y, 0, UIntPtr.Zero);
        Thread.Sleep(300);
    }

    public static void CaptureWindow(IntPtr hWnd, string savePath) {
        RECT rc;
        GetWindowRect(hWnd, out rc);
        int width = rc.Right - rc.Left;
        int height = rc.Bottom - rc.Top;
        using (Bitmap bmp = new Bitmap(width, height)) {
            using (Graphics g = Graphics.FromImage(bmp)) {
                IntPtr hdc = g.GetHdc();
                PrintWindow(hWnd, hdc, 2); // PW_RENDERFULLCONTENT = 2
                g.ReleaseHdc(hdc);
            }
            bmp.Save(savePath, ImageFormat.Png);
        }
    }

    public static bool Run(string exePath, string workingDir, string artifactDir) {
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            if (hDesk != IntPtr.Zero) {
                SetThreadDesktop(hDesk);
            }

            STARTUPINFO si = new STARTUPINFO();
            si.cb = Marshal.SizeOf(si);
            si.lpDesktop = @"WinSta0\default";

            PROCESS_INFORMATION pi = new PROCESS_INFORMATION();
            bool created = CreateProcess(exePath, null, IntPtr.Zero, IntPtr.Zero, false, 0, IntPtr.Zero, workingDir, ref si, out pi);

            if (!created) {
                Console.WriteLine("Failed to create process: " + Marshal.GetLastWin32Error());
                return;
            }

            Console.WriteLine("Launched DataSphere PID: " + pi.dwProcessId);
            Thread.Sleep(4000);

            AutomationElement appWin = null;
            for (int i = 0; i < 20; i++) {
                var found = AutomationElement.RootElement.FindFirst(TreeScope.Children, new PropertyCondition(AutomationElement.ProcessIdProperty, pi.dwProcessId));
                if (found != null) {
                    appWin = found;
                    break;
                }
                Thread.Sleep(500);
            }

            if (appWin == null) {
                Console.WriteLine("Could not locate DataSphere window!");
                try { Process.GetProcessById(pi.dwProcessId).Kill(); } catch {}
                return;
            }

            IntPtr hwnd = new IntPtr(appWin.Current.NativeWindowHandle);
            Rect winRect = appWin.Current.BoundingRectangle;

            // Click settings button on HomePage
            var allButtons = appWin.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button));
            AutomationElement settingsBtn = null;
            foreach (AutomationElement btn in allButtons) {
                string name = btn.Current.Name ?? "";
                if (name.IndexOf("đặt", StringComparison.OrdinalIgnoreCase) >= 0 || name.IndexOf("Settings", StringComparison.OrdinalIgnoreCase) >= 0) {
                    settingsBtn = btn;
                    break;
                }
            }

            if (settingsBtn != null) {
                Rect br = settingsBtn.Current.BoundingRectangle;
                PhysicalLeftClick((int)(br.X + br.Width / 2), (int)(br.Y + br.Height / 2));
            } else {
                PhysicalLeftClick((int)(winRect.X + winRect.Width - 100), (int)(winRect.Y + winRect.Height / 2));
            }
            Thread.Sleep(2000);

            string reproShot = System.IO.Path.Combine(artifactDir, "diagnose_dark_solid_issue.png");
            CaptureWindow(hwnd, reproShot);
            Console.WriteLine("Saved repro screenshot: " + reproShot);

            try { Process.GetProcessById(pi.dwProcessId).Kill(); } catch {}
        });

        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join(20000);
        return true;
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing", "UIAutomationClient", "UIAutomationTypes", "WindowsBase"

$exePath = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$workingDir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"
$artifactDir = "C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363"

[DarkModeReproducer]::Run($exePath, $workingDir, $artifactDir)
