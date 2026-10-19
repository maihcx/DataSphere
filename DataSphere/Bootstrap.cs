using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Threading;
using System.Threading.Tasks;

namespace DataSphere
{
    /// <summary>
    /// Coordinates application pre-startup initialization, per-process IPC communication, and background memory maintenance.
    /// </summary>
    public static class Bootstrap
    {
        private static Thread? _pipeThread;
        private static readonly string UniqueProcessPipeName = $@"DataSphere.Process.{Process.GetCurrentProcess().Id}";
        private static Task? _gcTask;
        private static readonly CancellationTokenSource _cts = new();

        /// <summary>
        /// Executes initialization logic before the main application UI starts, configuring per-process IPC listeners without single-instance blocking.
        /// </summary>
        public static void OnBeforeStartup()
        {
            // T029 & T030: Multi-instance concurrency enabled.
            // Each process listens on its own unique per-process pipe for external commands without blocking or killing secondary processes.
            StartProcessIpcServer();
        }

        private static void StartProcessIpcServer()
        {
            _pipeThread = new Thread(() =>
            {
                while (!_cts.IsCancellationRequested)
                {
                    try
                    {
                        var pipeSecurity = new PipeSecurity();
                        pipeSecurity.AddAccessRule(new PipeAccessRule(
                            new SecurityIdentifier(WellKnownSidType.WorldSid, null),
                            PipeAccessRights.ReadWrite,
                            AccessControlType.Allow
                        ));

                        using var server = NamedPipeServerStreamAcl.Create(
                            UniqueProcessPipeName,
                            PipeDirection.In,
                            1,
                            PipeTransmissionMode.Byte,
                            PipeOptions.None,
                            0,
                            0,
                            pipeSecurity
                        );

                        server.WaitForConnection();

                        using var reader = new StreamReader(server);
                        string? line = reader.ReadLine();

                        if (line == "SHOW")
                        {
                            // In WinUI 3, bring the primary window to front if requested
                            Debug.WriteLine($"[DataSphere IPC] SHOW signal received for process {Process.GetCurrentProcess().Id}");
                        }
                    }
                    catch (Exception ex)
                    {
                        Debug.WriteLine($"[DataSphere IPC] Pipe error: {ex.Message}");
                        Thread.Sleep(200);
                    }
                }
            })
            {
                IsBackground = true,
                Name = "DataSphere_IPC_Thread"
            };

            _pipeThread.Start();
        }

        /// <summary>
        /// Starts periodic background garbage collection optimization tasks during runtime.
        /// </summary>
        public static void OnStartup()
        {
            _gcTask = Task.Run(async () =>
            {
                while (!_cts.IsCancellationRequested)
                {
                    try
                    {
                        GC.Collect(2, GCCollectionMode.Default, blocking: false);
                    }
                    catch
                    {
                        // Ignore background GC exceptions
                    }

                    await Task.Delay(TimeSpan.FromSeconds(30), _cts.Token).ConfigureAwait(false);
                }
            });
        }

        /// <summary>
        /// Cleans up IPC threads and background workers upon application exit.
        /// </summary>
        public static void OnExit()
        {
            _cts.Cancel();
            try
            {
                _gcTask?.Dispose();
            }
            catch
            {
                // Ignore disposal errors on exit
            }
        }
    }
}
