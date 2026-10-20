using System.Collections.ObjectModel;
using System.Text.Json;
using System.Text.Json.Serialization;
using DataSphere.Models;
using DataSphere.Utils;

namespace DataSphere.Services
{
    /// <summary>
    /// Service responsible for persisting and retrieving database connections with transparent password encryption.
    /// </summary>
    public static class ConnectionStorageService
    {
        private static CancellationTokenSource? _saveCts;

        /// <summary>
        /// Gets the absolute path to the connections storage file.
        /// </summary>
        public static readonly string ConfigFilePath =
            Path.Combine(AppInfoHelper.DataDir, "connections.json");

        private static readonly JsonSerializerOptions Options = new()
        {
            WriteIndented = true,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        };

        /// <summary>
        /// Asynchronously persists the collection of database connections to disk, encrypting passwords with AES-CBC.
        /// Debounces write operations using a configurable delay.
        /// </summary>
        /// <param name="connections">The connection hierarchy to persist.</param>
        /// <param name="delayMs">Debounce delay in milliseconds (default 200ms).</param>
        /// <param name="cancellationToken">Optional cancellation token.</param>
        public static async Task SaveAsync(ObservableCollection<ConnectionModel> connections, int delayMs = 200, CancellationToken cancellationToken = default)
        {
            _saveCts?.Cancel();
            _saveCts = new CancellationTokenSource();
            var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(_saveCts.Token, cancellationToken);
            var token = linkedCts.Token;

            try
            {
                if (delayMs > 0)
                {
                    await Task.Delay(delayMs, token).ConfigureAwait(false);
                }
                if (token.IsCancellationRequested) return;

                var persistentList = new List<ConnectionModel>();
                lock (connections)
                {
                    foreach (var conn in connections)
                    {
                        persistentList.Add(CloneForPersistence(conn));
                    }
                }

                var directory = Path.GetDirectoryName(ConfigFilePath);
                if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
                {
                    Directory.CreateDirectory(directory);
                }

                var json = JsonSerializer.Serialize(persistentList, Options);
                await File.WriteAllTextAsync(ConfigFilePath, json, token).ConfigureAwait(false);
            }
            catch (TaskCanceledException)
            {
                // Debounced write superseded by newer request
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[ConnectionStorageService] Failed to save connections: {ex.Message}");
            }
        }

        /// <summary>
        /// Asynchronously loads and decrypts database connections from disk.
        /// Returns an empty collection without throwing if the file does not exist or contains invalid JSON.
        /// </summary>
        /// <returns>Collection of restored ConnectionModel instances with decrypted in-memory passwords.</returns>
        public static async Task<ObservableCollection<ConnectionModel>> LoadAsync()
        {
            if (!File.Exists(ConfigFilePath))
            {
                return new ObservableCollection<ConnectionModel>();
            }

            try
            {
                var json = await File.ReadAllTextAsync(ConfigFilePath).ConfigureAwait(false);
                var data = JsonSerializer.Deserialize<ObservableCollection<ConnectionModel>>(json, Options);
                if (data == null)
                {
                    return new ObservableCollection<ConnectionModel>();
                }

                foreach (var conn in data)
                {
                    DecryptInPlace(conn);
                }

                return data;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[ConnectionStorageService] Failed to load connections: {ex.Message}");
                return new ObservableCollection<ConnectionModel>();
            }
        }

        private static ConnectionModel CloneForPersistence(ConnectionModel source)
        {
            var clone = new ConnectionModel
            {
                Name = source.Name,
                Key = source.Key,
                IsEditing = false,
                Type = source.Type,
                Host = source.Host,
                Port = source.Port,
                User = source.User,
                Password = string.IsNullOrWhiteSpace(source.Password)
                    ? string.Empty
                    : PasswordEncryptor.Encrypt(source.Password),
                Children = new ObservableCollection<ConnectionModel>()
            };

            if (source.Children != null)
            {
                foreach (var child in source.Children)
                {
                    clone.Children.Add(CloneForPersistence(child));
                }
            }

            return clone;
        }

        private static void DecryptInPlace(ConnectionModel model)
        {
            if (!string.IsNullOrWhiteSpace(model.Password))
            {
                try
                {
                    model.Password = PasswordEncryptor.Decrypt(model.Password);
                }
                catch
                {
                    // Fallback to existing value if already plain text or corrupted
                }
            }

            if (model.Children != null)
            {
                foreach (var child in model.Children)
                {
                    DecryptInPlace(child);
                }
            }
        }
    }
}
