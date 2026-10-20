using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text.Json;

namespace DataSphere.Utils
{
    /// <summary>
    /// Thread-safe local file-based key-value storage for application and user preferences.
    /// Stores data at %LOCALAPPDATA%\DataSphere\userdata.json with in-memory caching and transparent encryption.
    /// </summary>
    public static class UserDataStore
    {
        private static readonly string DataDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "DataSphere");

        private static readonly string DataFile = Path.Combine(DataDir, "userdata.json");

        private static readonly object _syncLock = new();

        private static Dictionary<string, object> _data = new();

        private static readonly Dictionary<string, string> _passCaching = new();

        static UserDataStore()
        {
            Reload();
        }

        private static void SaveData()
        {
            lock (_syncLock)
            {
                try
                {
                    if (!Directory.Exists(DataDir))
                    {
                        Directory.CreateDirectory(DataDir);
                    }

                    var json = JsonSerializer.Serialize(_data, new JsonSerializerOptions
                    {
                        WriteIndented = true
                    });

                    // Write to temporary file first for atomic persistence
                    var tempFile = Path.Combine(DataDir, $"userdata.{Guid.NewGuid():N}.tmp");
                    File.WriteAllText(tempFile, json);

                    if (File.Exists(DataFile))
                    {
                        File.Delete(DataFile);
                    }

                    File.Move(tempFile, DataFile);
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"[UserDataStore] Failed to save settings: {ex.Message}");
                }
            }
        }

        /// <summary>
        /// Retrieves a strongly-typed preference value for the given key.
        /// </summary>
        /// <typeparam name="T">The target type to deserialize.</typeparam>
        /// <param name="key">The configuration key name.</param>
        /// <returns>The stored value, or default(T) if not found or corrupted.</returns>
        public static T GetValue<T>(string key)
        {
            if (string.IsNullOrWhiteSpace(key))
            {
                return default!;
            }

            lock (_syncLock)
            {
                if (_data.TryGetValue(key, out var value))
                {
                    try
                    {
                        if (value is JsonElement elem)
                        {
                            return elem.Deserialize<T>()!;
                        }

                        if (value is IConvertible)
                        {
                            return (T)Convert.ChangeType(value, typeof(T));
                        }

                        return (T)value;
                    }
                    catch (Exception ex)
                    {
                        Debug.WriteLine($"[UserDataStore] Failed to deserialize key '{key}': {ex.Message}");
                    }
                }

                try
                {
                    var defaultValue = Properties.Settings.Default[key];
                    if (defaultValue is T tVal)
                    {
                        return tVal;
                    }

                    if (defaultValue != null)
                    {
                        return (T)Convert.ChangeType(defaultValue, typeof(T));
                    }
                }
                catch
                {
                    // Fallback ignored when Settings is not configured
                }

                return default!;
            }
        }

        /// <summary>
        /// Retrieves and decrypts a sensitive string preference value.
        /// </summary>
        /// <param name="key">The configuration key name.</param>
        /// <returns>The decrypted plaintext string, or empty string if not found or corrupted.</returns>
        public static string GetValuePass(string key)
        {
            if (string.IsNullOrWhiteSpace(key))
            {
                return string.Empty;
            }

            lock (_syncLock)
            {
                try
                {
                    if (_passCaching.TryGetValue(key, out var result) && !string.IsNullOrEmpty(result))
                    {
                        return result;
                    }

                    var cipherText = GetValue<string>(key);
                    if (!string.IsNullOrEmpty(cipherText))
                    {
                        result = PasswordEncryptor.Decrypt(cipherText);
                        _passCaching[key] = result;
                        return result;
                    }
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"[UserDataStore] Failed to decrypt key '{key}': {ex.Message}");
                }

                return string.Empty;
            }
        }

        /// <summary>
        /// Persists a preference value under the specified key to the user data store.
        /// </summary>
        /// <typeparam name="T">The value type.</typeparam>
        /// <param name="key">The configuration key name.</param>
        /// <param name="value">The value to store.</param>
        /// <returns><c>true</c> if successfully written; otherwise <c>false</c>.</returns>
        public static bool SetValue<T>(string key, T value)
        {
            if (string.IsNullOrWhiteSpace(key))
            {
                return false;
            }

            lock (_syncLock)
            {
                _data[key] = value!;
                SaveData();
                return true;
            }
        }

        /// <summary>
        /// Encrypts and persists a sensitive string preference value.
        /// </summary>
        /// <param name="key">The configuration key name.</param>
        /// <param name="value">The plaintext value to encrypt and store.</param>
        /// <returns><c>true</c> if successfully encrypted and saved; otherwise <c>false</c>.</returns>
        public static bool SetValuePass(string key, string value)
        {
            if (string.IsNullOrWhiteSpace(key))
            {
                return false;
            }

            lock (_syncLock)
            {
                var safeValue = value ?? string.Empty;
                _passCaching[key] = safeValue;
                return SetValue(key, PasswordEncryptor.Encrypt(safeValue));
            }
        }

        /// <summary>
        /// Resets all stored preferences to empty defaults and saves to disk.
        /// </summary>
        public static void Reset()
        {
            lock (_syncLock)
            {
                _data.Clear();
                _passCaching.Clear();
                SaveData();
            }
        }

        /// <summary>
        /// Forces reloading of preferences from disk into memory, recovering gracefully from corrupted files.
        /// </summary>
        public static void Reload()
        {
            lock (_syncLock)
            {
                _data.Clear();
                _passCaching.Clear();

                if (File.Exists(DataFile))
                {
                    try
                    {
                        var json = File.ReadAllText(DataFile);
                        _data = JsonSerializer.Deserialize<Dictionary<string, object>>(json)
                                ?? new Dictionary<string, object>();
                    }
                    catch (Exception ex)
                    {
                        Debug.WriteLine($"[UserDataStore] Warning: Failed to parse {DataFile}, resetting to defaults: {ex.Message}");
                        _data = new Dictionary<string, object>();
                    }
                }
                else
                {
                    _data = new Dictionary<string, object>();
                }
            }
        }
    }
}
