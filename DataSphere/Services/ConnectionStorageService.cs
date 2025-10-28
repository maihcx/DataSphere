using System.Text.Json.Serialization;

namespace DataSphere.Services
{
    public static class ConnectionStorageService
    {
        private static CancellationTokenSource? _saveCts;

        private static readonly string ConfigFilePath =
            Path.Combine(AppInfoHelper.DataDir, "connections.json");

        private static readonly JsonSerializerOptions Options = new()
        {
            WriteIndented = true,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        };

        public static async Task SaveAsync(ObservableCollection<ConnectionModel> connections, int delayMs = 200)
        {
            _saveCts?.Cancel();
            _saveCts = new CancellationTokenSource();
            var token = _saveCts.Token;

            try
            {
                await Task.Delay(delayMs, token);
                if (token.IsCancellationRequested) return;

                var json = JsonSerializer.Serialize(connections, Options);
                await File.WriteAllTextAsync(ConfigFilePath, json, token);
            }
            catch (TaskCanceledException)
            {
                
            }
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
