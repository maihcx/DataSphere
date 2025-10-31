using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace DataSphere
{
    public static class Bootstrap
    {
        private static Thread? _pipeThread;

        private static Mutex? _mutex;

        private static string UniqueAppId = @"Global\DataSphere.SingleInstance.App";

        private static bool _isPrimaryInstance = false;

        private static SplashScreen? SplashScreen;

        private static Task? _gcTask;

        private static CancellationTokenSource _cts = new();

        public static void OnBeforeStartup()
        {
            #region Mutex checker
            try
            {
                _mutex = CreateMutexWithSecurity(UniqueAppId);
                _isPrimaryInstance = _mutex.WaitOne(0, false);
            }
            catch
            {
                _mutex = new Mutex(true, UniqueAppId, out _isPrimaryInstance);
            }

            if (!_isPrimaryInstance)
            {
                try
                {
                    using var client = new NamedPipeClientStream(".", UniqueAppId, PipeDirection.Out);
                    client.Connect(1000);
                    using var writer = new StreamWriter(client) { AutoFlush = true };
                    writer.WriteLine("SHOW");
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"Failed to connect to pipe: {ex.Message}");
                }

                Environment.Exit(0);
                return;
            }
            #endregion

            #region SplashScreen Show
            SplashScreen = new SplashScreen("Assets/wpfui-icon-256.png");
            SplashScreen.Show(true, true);
            #endregion

            #region Single App Reader
            _pipeThread = new Thread(() =>
            {
                while (true)
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
                            UniqueAppId,
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
                            App.Current.Dispatcher.Invoke(() =>
                            {
                                var mainWindow = Application.Current?.MainWindow;
                                if (mainWindow != null)
                                {
                                    WindowHelper.FocusMainWindow();
                                }
                            });
                        }
                    }
                    catch (Exception)
                    {
                        Thread.Sleep(100);
                    }
                }
            });
            _pipeThread.IsBackground = true;
            _pipeThread.Start();
            #endregion
        }

        public static void OnStartup()
        {
            _gcTask = Task.Run(async () =>
            {
                while (!_cts.IsCancellationRequested)
                {
                    try
                    {
                        GC.Collect(0, GCCollectionMode.Default, blocking: false);
                    }
                    catch { /* ignore */ }

                    await Task.Delay(TimeSpan.FromSeconds(3), _cts.Token)
                              .ConfigureAwait(false);
                }
            });
        }

        public static void OnExit()
        {
            if (_mutex != null)
            {
                try
                {
                    _mutex.ReleaseMutex();
                }
                catch { }
                _mutex.Dispose();
            }

            _cts?.Cancel();
            _gcTask?.Dispose();
        }

        /// <summary>
        /// Create Mutex for all users with full control permission.
        /// </summary>
        private static Mutex CreateMutexWithSecurity(string name)
        {
            var allowEveryoneRule = new MutexAccessRule(
                new SecurityIdentifier(WellKnownSidType.WorldSid, null),
                MutexRights.FullControl,
                AccessControlType.Allow
            );

            var securitySettings = new MutexSecurity();
            securitySettings.AddAccessRule(allowEveryoneRule);

            bool createdNew;

            var mutex = new Mutex(false, name, out createdNew);


            if (createdNew)
            {
                mutex.SetAccessControl(securitySettings);
            }

            return mutex;
        }
    }
}
