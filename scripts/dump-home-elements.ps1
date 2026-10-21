$source = @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Automation;

public class ElementDumper {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct STARTUPINFO {
        public int cb;
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
        public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
        public short wShowWindow, cbReserved2;
        public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION {
        public IntPtr hProcess, hThread;
        public int dwProcessId, dwThreadId;
    }
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool CreateProcess(string app, string cmd, IntPtr pa, IntPtr ta, bool ih, uint fl, IntPtr env, string cd, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetThreadDesktop(IntPtr hDesktop);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseDesktop(IntPtr hDesktop);

    public static string Dump(int pid) {
        string res = "";
        Thread t = new Thread(() => {
            IntPtr hDesk = OpenDesktop("default", 0, false, 0x01FF);
            SetThreadDesktop(hDesk);
            try {
                AutomationElement appWin = null;
                for (int i = 0; i < 20; i++) {
                    Thread.Sleep(200);
                    appWin = AutomationElement.RootElement.FindFirst(TreeScope.Children, new PropertyCondition(AutomationElement.ProcessIdProperty, pid));
                    if (appWin != null) break;
                }
                if (appWin == null) return;
                var all = appWin.FindAll(TreeScope.Descendants, Condition.TrueCondition);
                foreach (AutomationElement el in all) {
                    try {
                        string name = el.Current.Name ?? "";
                        string ct = el.Current.ControlType.ProgrammaticName;
                        var r = el.Current.BoundingRectangle;
                        if (name.Length > 0 || r.Width > 100) {
                            res += ct + " | '" + name + "' | (" + (int)r.X + "," + (int)r.Y + "," + (int)r.Width + "x" + (int)r.Height + ")\n";
                        }
                    } catch {}
                }
            } finally {
                CloseDesktop(hDesk);
            }
        });
        t.SetApartmentState(ApartmentState.STA);
        t.Start();
        t.Join(15000);
        return res;
    }

    public static int Launch(string exe, string dir) {
        STARTUPINFO si = new STARTUPINFO();
        si.cb = Marshal.SizeOf(si);
        si.lpDesktop = @"WinSta0\default";
        PROCESS_INFORMATION pi = new PROCESS_INFORMATION();
        CreateProcess(exe, null, IntPtr.Zero, IntPtr.Zero, false, 0, IntPtr.Zero, dir, ref si, out pi);
        return pi.dwProcessId;
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies "WindowsBase", "UIAutomationClient", "UIAutomationTypes"

$exe = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe"
$dir = "D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"
$pidVal = [ElementDumper]::Launch($exe, $dir)
Start-Sleep -Seconds 3
$dump = [ElementDumper]::Dump($pidVal)
Write-Host $dump
Stop-Process -Id $pidVal -Force -ErrorAction SilentlyContinue
