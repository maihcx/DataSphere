using CommunityToolkit.Mvvm.Messaging.Messages;
using DataSphere.Controls;
using DataSphere.Dialogs;

namespace DataSphere.Services
{
    public interface IDialogWithResult<TResult>
    {
        TResult? Result { get; }
    }

    public interface IDialogWithModel
    {
        void SetModel(object? model);
    }

    public static class MessengerService
    {

        public static void ShowSnackbar(string title, string content, ControlAppearance controlAppearance)
        {
            ShowSnackbar(title, content, controlAppearance, null, default);
        }

        public static void ShowSnackbar(string title, string content, ControlAppearance controlAppearance, TimeSpan timeSpan = default)
        {
            ShowSnackbar(title, content, controlAppearance, null, timeSpan);
        }

        public static void ShowSnackbar(string title, string content, ControlAppearance controlAppearance, IconElement? icon = null)
        {
            ShowSnackbar(title, content, controlAppearance, icon, default);
        }

        public static void ShowSnackbar(string title, string? content, ControlAppearance controlAppearance, IconElement? icon = null, TimeSpan timeSpan = default)
        {
            var ResourceManager = Resources.Locales.String.ResourceManager;
            var CurrentCulture = TranslationSource.Instance.CurrentCulture;
            WindowHelper.GlobalSnackbar?.Show(ResourceManager.GetString(title, CurrentCulture) ?? string.Empty, ResourceManager.GetString(content ?? string.Empty, CurrentCulture) ?? string.Empty, controlAppearance, icon, timeSpan);
        }

        public static async Task<TResult?> ShowDialogAsync<TDialog, TResult>(object? model = null, ContentPresenter? dialogHost = null, Func<TDialog, Task>? onShowing = null) where TDialog : ContentDialog, IDialogWithResult<TResult>
        {
            var service = WindowHelper.ContentDialogService
                ?? throw new InvalidOperationException("ContentDialogService is not initialized.");

            dialogHost ??= service.GetDialogHost();

            if (Activator.CreateInstance(typeof(TDialog), dialogHost) is not TDialog dialog)
                throw new InvalidOperationException($"Cannot create instance of type {typeof(TDialog).FullName}.");

            // Nếu dialog có interface IDialogWithModel → truyền model vào
            if (dialog is IDialogWithModel modelDialog)
            {
                if (onShowing != null)
                {
                    await onShowing(dialog);
                }
                modelDialog.SetModel(model);
            }
            else if (model != null)
            {
                if (onShowing != null)
                {
                    await onShowing(dialog);
                }
                dialog.DataContext = model;
            }

            await dialog.ShowAsync();
            return dialog.Result;
        }
    }

    public class GenericMessage<T> : ValueChangedMessage<T>
    {
        public GenericMessage(T value) : base(value) { }
    }
}
