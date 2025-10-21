namespace DataSphere.Utils
{
    public static class AppInfoHelper
    {
        public static readonly string AppName = Assembly.GetExecutingAssembly().GetName().Name ?? "NoName";

        public static string Author = "Song Mai Software";

        public static string SortAuthor = "SM SOFT";

        public static string AuthorCreated = "Created by SM SOFT";

        public static string AppDescription = "Manage your databases.";

        public static string CopyRight = "© 2025 Song Mai Software";

        public static string GetAppPath()
        {
            string? appPath = Environment.ProcessPath;
            if (string.IsNullOrEmpty(appPath))
            {
                appPath = AppDomain.CurrentDomain.BaseDirectory;
            }
            else
            {
                appPath = Path.GetDirectoryName(appPath) ?? appPath;
            }
            return appPath.Replace("\\", "/");
        }

        public static string GetAppPackage()
        {
            string? exePath = Environment.ProcessPath;

            if (string.IsNullOrEmpty(exePath))
            {
                exePath = Assembly.GetEntryAssembly()?.Location;
            }

            if (string.IsNullOrEmpty(exePath))
            {
                return string.Empty;
            }

            return Path.GetFileName(exePath);
        }
    }
}
