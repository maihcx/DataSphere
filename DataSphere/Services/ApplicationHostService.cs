using DataSphere.Services.Contracts;
using DataSphere.Utils;
using DataSphere.Views.Windows;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace DataSphere.Services
{
    /// <summary>
    /// Coordinates the application host lifecycle and primary shell window activation.
    /// </summary>
    public class ApplicationHostService : IHostedService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly IWindowManager _windowManager;
        private readonly IThemeService _themeService;

        /// <summary>
        /// Initializes a new instance of the <see cref="ApplicationHostService"/> class.
        /// </summary>
        /// <param name="serviceProvider">The application service provider.</param>
        /// <param name="windowManager">The application window manager service.</param>
        /// <param name="themeService">The application theme service.</param>
        public ApplicationHostService(
            IServiceProvider serviceProvider,
            IWindowManager windowManager,
            IThemeService themeService)
        {
            _serviceProvider = serviceProvider ?? throw new ArgumentNullException(nameof(serviceProvider));
            _windowManager = windowManager ?? throw new ArgumentNullException(nameof(windowManager));
            _themeService = themeService ?? throw new ArgumentNullException(nameof(themeService));
        }

        /// <summary>
        /// Triggered when the application host is ready to start the service.
        /// </summary>
        /// <param name="cancellationToken">Indicates that the start process has been aborted.</param>
        public Task StartAsync(CancellationToken cancellationToken)
        {
            return HandleActivationAsync();
        }

        /// <summary>
        /// Triggered when the application host is performing a graceful shutdown.
        /// </summary>
        /// <param name="cancellationToken">Indicates that the shutdown process should no longer be graceful.</param>
        public Task StopAsync(CancellationToken cancellationToken)
        {
            return Task.CompletedTask;
        }

        /// <summary>
        /// Creates and activates the primary ShellWindow during startup after restoring language and theme preferences.
        /// </summary>
        private Task HandleActivationAsync()
        {
            // Restore persisted language preference prior to UI construction
            TranslationSource.Instance.CurrentCulture = LanguageBase.GetSetupLanguage();

            // Initialize theme configuration from UserDataStore
            _themeService.Initialize();

            var shellWindow = _serviceProvider.GetRequiredService<ShellWindow>();

            // Apply theme to the root visual before activation
            _themeService.ApplyThemeToWindow(shellWindow);

            shellWindow.Activate();
            return Task.CompletedTask;
        }
    }
}
