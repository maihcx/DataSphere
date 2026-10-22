using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using DataSphere.Models;
using DataSphere.Models.Database;
using DataSphere.Services.Contracts;
using DataSphere.Services.Database.Interface;
using DataSphere.Utils;
using WinUIEx;

namespace DataSphere.Services
{
    /// <summary>
    /// Service presenting WinUI 3 ContentDialogs with verified XamlRoot resolution.
    /// </summary>
    public class DialogService : IDialogService
    {
        private readonly IWindowManager _windowManager;
        private readonly IThemeService _themeService;

        /// <summary>
        /// Initializes a new instance of the <see cref="DialogService"/> class.
        /// </summary>
        /// <param name="windowManager">The window manager used to resolve active window XamlRoot anchors.</param>
        /// <param name="themeService">The theme service used to synchronize dialog themes.</param>
        public DialogService(IWindowManager windowManager, IThemeService themeService)
        {
            _windowManager = windowManager ?? throw new ArgumentNullException(nameof(windowManager));
            _themeService = themeService ?? throw new ArgumentNullException(nameof(themeService));
        }

        private XamlRoot? ResolveXamlRoot(object? explicitRoot = null)
        {
            if (explicitRoot is XamlRoot xamlRoot)
            {
                return xamlRoot;
            }

            // 1. Match native foreground window to registered window sessions
            IntPtr fgHandle = WindowHelper.GetForegroundWindow();
            if (fgHandle != IntPtr.Zero)
            {
                var fgWindow = _windowManager.Windows
                    .FirstOrDefault(w => w.WindowInstance != null && w.WindowInstance.GetWindowHandle() == fgHandle)
                    ?.WindowInstance;

                if (fgWindow?.Content?.XamlRoot != null)
                {
                    return fgWindow.Content.XamlRoot;
                }
            }

            // 2. Tracked active window session
            var activeSessionWindow = _windowManager.ActiveWindowSession?.WindowInstance;
            if (activeSessionWindow?.Content?.XamlRoot != null)
            {
                return activeSessionWindow.Content.XamlRoot;
            }

            // 3. Fallback to the most recently registered window
            var lastWindow = _windowManager.Windows.LastOrDefault(w => w.WindowInstance != null)?.WindowInstance;
            if (lastWindow?.Content?.XamlRoot != null)
            {
                return lastWindow.Content.XamlRoot;
            }

            // 4. Fallback to the primary window
            var activeWindow = _windowManager.Windows.FirstOrDefault(w => w.WindowInstance != null)?.WindowInstance;
            return activeWindow?.Content?.XamlRoot;
        }

        /// <inheritdoc/>
        public async Task<ConnectionModel?> ShowConnectionEditingDialogAsync(ConnectionModel? existingConnection = null, object? xamlRoot = null)
        {
            var root = ResolveXamlRoot(xamlRoot);
            if (root == null)
            {
                throw new InvalidOperationException("No active XamlRoot available to display ContentDialog.");
            }

            var dialog = new Views.Dialogs.ConnectionEditingDialog(existingConnection)
            {
                XamlRoot = root,
                Style = Application.Current.Resources["DefaultContentDialogStyle"] as Style
            };

            _themeService.ApplyThemeToDialog(dialog);

            var result = await dialog.ShowAsync();
            if (result == ContentDialogResult.Primary)
            {
                return dialog.ResultConnection;
            }

            return null;
        }

        /// <inheritdoc/>
        public async Task<DatabaseInfo?> ShowDatabaseEditingDialogAsync(IDatabaseConnection connection, object? xamlRoot = null)
        {
            var root = ResolveXamlRoot(xamlRoot);
            if (root == null)
            {
                throw new InvalidOperationException("No active XamlRoot available to display ContentDialog.");
            }

            var dialog = new Views.Dialogs.DatabaseEditingDialog(connection)
            {
                XamlRoot = root,
                Style = Application.Current.Resources["DefaultContentDialogStyle"] as Style
            };

            _themeService.ApplyThemeToDialog(dialog);

            var result = await dialog.ShowAsync();
            if (result == ContentDialogResult.Primary)
            {
                return dialog.ResultDatabaseInfo;
            }

            return null;
        }

        /// <inheritdoc/>
        public async Task<bool> ShowConfirmationDialogAsync(string titleKey, string messageKey, object[]? formatArgs = null, object? xamlRoot = null)
        {
            var root = ResolveXamlRoot(xamlRoot);
            if (root == null)
            {
                throw new InvalidOperationException("No active XamlRoot available to display ContentDialog.");
            }

            string title = LanguageBase.GetLangValue(titleKey);
            string message = (formatArgs != null && formatArgs.Length > 0)
                ? LanguageBase.GetLangValue(messageKey, formatArgs)
                : LanguageBase.GetLangValue(messageKey);

            var dialog = new ContentDialog
            {
                XamlRoot = root,
                Style = Application.Current.Resources["DefaultContentDialogStyle"] as Style,
                Title = title,
                Content = message,
                PrimaryButtonText = LanguageBase.GetLangValue("msgbox_ok_title"),
                CloseButtonText = LanguageBase.GetLangValue("msgbox_cancel_title"),
                DefaultButton = ContentDialogButton.Close
            };

            _themeService.ApplyThemeToDialog(dialog);

            var result = await dialog.ShowAsync();
            return result == ContentDialogResult.Primary;
        }
    }
}
