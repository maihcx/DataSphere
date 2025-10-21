namespace DataSphere.Services
{
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
    }
}
