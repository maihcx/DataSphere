# Contract: Connection Storage & Secure Persistence

**Namespace**: `DataSphere.Services`  

## 1. Overview
Governs asynchronous loading, saving, and transparent credential encryption for the database connection catalog stored in `%LOCALAPPDATA%\DataSphere\connections.json`.

## 2. API Contract

```csharp
namespace DataSphere.Services
{
    /// <summary>
    /// Service responsible for persisting and retrieving database connections with transparent password encryption.
    /// </summary>
    public static class ConnectionStorageService
    {
        /// <summary>
        /// Asynchronously persists the collection of database connections to disk, encrypting passwords with AES-CBC.
        /// Debounces write operations using a configurable delay.
        /// </summary>
        /// <param name="connections">The connection hierarchy to persist.</param>
        /// <param name="delayMs">Debounce delay in milliseconds (default 200ms).</param>
        /// <param name="cancellationToken">Cancellation token for aborting delayed writes.</param>
        public static Task SaveAsync(ObservableCollection<ConnectionModel> connections, int delayMs = 200, CancellationToken cancellationToken = default);

        /// <summary>
        /// Asynchronously loads and decrypts database connections from disk.
        /// Returns an empty collection without throwing if the file does not exist or contains invalid JSON.
        /// </summary>
        /// <returns>Collection of restored ConnectionModel instances with decrypted in-memory passwords.</returns>
        public static Task<ObservableCollection<ConnectionModel>> LoadAsync();
    }
}
```

## 3. Cryptographic Invariants
1. All connection passwords written to `%LOCALAPPDATA%\DataSphere\connections.json` MUST be encrypted with `PasswordEncryptor.Encrypt()`.
2. Plain-text passwords MUST never be written to persistent files, logs, or diagnostic dumps.
3. If a password cannot be decrypted or is empty, the system defaults to an empty string without throwing unhandled exceptions.
