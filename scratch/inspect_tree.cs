using System;
using System.Diagnostics;
using System.Threading;
using System.Windows.Automation;

class Program {
    static void Main() {
        Process proc = Process.Start(new ProcessStartInfo {
            FileName = @"DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.exe",
            WorkingDirectory = @"DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64"
        });
        Thread.Sleep(3000);
        Console.WriteLine("App running PID: " + proc.Id);
        proc.Kill();
    }
}
