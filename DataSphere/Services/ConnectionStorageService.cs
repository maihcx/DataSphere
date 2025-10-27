using System.Text.Json.Serialization;

namespace DataSphere.Services
{
    public static class ConnectionStorageService
    {
        private static readonly string ConfigFilePath =
            Path.Combine(AppInfoHelper.DataDir, "connections.json");

        private static readonly JsonSerializerOptions Options = new()
        {
            WriteIndented = true,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        };

        public static async Task SaveAsync(ObservableCollection<ConnectionModel> connections)
        {
            var json = JsonSerializer.Serialize(connections, Options);
            await File.WriteAllTextAsync(ConfigFilePath, json);
        }

        public static async Task<ObservableCollection<ConnectionModel>> LoadAsync()
        {
            if (!File.Exists(ConfigFilePath))
                return new ObservableCollection<ConnectionModel>();

            try
            {
                var json = await File.ReadAllTextAsync(ConfigFilePath);
                var data = JsonSerializer.Deserialize<ObservableCollection<ConnectionModel>>(json, Options);
                return data ?? new ObservableCollection<ConnectionModel>();
            }
            catch
            {
                return new ObservableCollection<ConnectionModel>();
            }
        }
    }
}
