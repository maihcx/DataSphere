using DataSphere.Models;
using DataSphere.Services;
using DataSphere.Services.Contracts;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.UI.Xaml;

namespace DataSphere
{
    /// <summary>
    /// Coordinates the application lifecycle, service host, and primary window activation.
    /// </summary>
    public partial class App : Application
    {
        private static IHost? _host;
        private static readonly Task<IHost> _hostBuildTask = Task.Run(BuildHost);

        /// <summary>
        /// Gets the singleton application host instance.
        /// </summary>
        public static IHost HostInstance => _host ??= _hostBuildTask.GetAwaiter().GetResult();

        /// <summary>
        /// Gets the application dependency injection service provider.
        /// </summary>
        public static IServiceProvider Services => HostInstance.Services;

        /// <summary>
        /// Initializes a new instance of the <see cref="App"/> class.
        /// </summary>
        public App()
        {
            InitializeComponent();

            UnhandledException += (sender, args) =>
            {
                Debug.WriteLine($"[DataSphere] Unhandled WinUI exception: {args.Exception}");
            };
        }

        private static IHost BuildHost() =>
            Host.CreateDefaultBuilder()
                .ConfigureAppConfiguration(c =>
                {
                    c.SetBasePath(AppContext.BaseDirectory);
                })
                .ConfigureServices((context, services) =>
                {
                    // Hosted lifecycle service
                    services.AddHostedService<ApplicationHostService>();

                    // Window & Tab management infrastructure
                    services.AddSingleton<IWindowManager, DataSphere.Services.WindowManager>();
                    services.AddTransient<ITabService, TabService>();

                    // Core Application Services
                    services.AddSingleton<MessengerService>();
                    services.AddSingleton<IThemeService, DataSphere.Services.ThemeService>();
                    services.AddSingleton<IDialogService, DataSphere.Services.DialogService>();

                    // ViewModels & Windows
                    services.AddTransient<ViewModels.Windows.ShellViewModel>();
                    services.AddTransient<Views.Windows.ShellWindow>();

                    // Pages & Page ViewModels
                    services.AddTransient<ViewModels.Pages.HomeViewModel>();
                    services.AddTransient<Views.Pages.HomePage>();

                    services.AddTransient<ViewModels.Pages.DatabaseGroup.DatabaseViewModel>();
                    services.AddTransient<Views.Pages.DatabaseGroup.DatabasePage>();
                    services.AddTransient<ViewModels.Pages.DatabaseGroup.ConnectControlViewModel>();
                    services.AddTransient<Views.Pages.DatabaseGroup.ConnectViewControl>();

                    services.AddTransient<ViewModels.PagesBottom.SettingsViewModel>();
                    services.AddTransient<Views.PagesBottom.SettingsPage>();
                })
                .Build();

        /// <summary>
        /// Invoked when the application is launched, initializing services and activating the primary window.
        /// </summary>
        /// <param name="args">Details about the launch request and process.</param>
        protected override async void OnLaunched(LaunchActivatedEventArgs args)
        {
            _host = await _hostBuildTask.ConfigureAwait(true);
            await _host.StartAsync().ConfigureAwait(true);
        }

        /// <summary>
        /// Resolves a required service instance of type <typeparamref name="T"/> from the application host.
        /// </summary>
        /// <typeparam name="T">The service type to resolve.</typeparam>
        /// <returns>The resolved service instance.</returns>
        public static T GetRequiredService<T>() where T : class => HostInstance.Services.GetRequiredService<T>();

        /// <summary>
        /// Resolves an optional service instance of type <typeparamref name="T"/> from the application host.
        /// </summary>
        /// <typeparam name="T">The service type to resolve.</typeparam>
        /// <returns>The resolved service instance, or null if not registered.</returns>
        public static T? GetService<T>() where T : class => HostInstance.Services.GetService<T>();
    }
}
