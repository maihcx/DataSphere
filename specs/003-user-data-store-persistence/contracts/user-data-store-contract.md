# Interface & Service Contracts: User Preferences & State Persistence

**Feature**: `003-user-data-store-persistence`
**Date**: 2026-10-20
**Status**: Completed

## 1. IThemeService Contract

Orchestrates the active visual theme across all open top-level shell windows.

```csharp
namespace DataSphere.Services.Contracts
{
    /// <summary>
    /// Service responsible for managing application-wide theme preferences and applying them to windows.
    /// </summary>
    public interface IThemeService
    {
        /// <summary>
        /// Gets the current theme preference string ("Light", "Dark", "Default").
        /// </summary>
        string CurrentTheme { get; }

        /// <summary>
        /// Occurs when the application theme changes.
        /// </summary>
        event EventHandler<string>? ThemeChanged;

        /// <summary>
        /// Initializes the theme from persistent storage and applies it to the application.
        /// </summary>
        void Initialize();

        /// <summary>
        /// Sets and persists the application theme, notifying all active windows to refresh their visual state.
        /// </summary>
        /// <param name="themeName">The theme mode name ("Light", "Dark", "Default").</param>
        void SetTheme(string themeName);

        /// <summary>
        /// Applies the active theme to the specified window instance.
        /// </summary>
        /// <param name="window">The window to theme.</param>
        void ApplyThemeToWindow(object window);
    }
}
```

---

## 2. Window Placement Persistence Contract

Manages saving and restoring window coordinates and state to/from `UserDataStore`.

```csharp
namespace DataSphere.Services.Contracts
{
    /// <summary>
    /// Helper contract for saving and restoring top-level window geometry.
    /// </summary>
    public static class WindowPlacementManager
    {
        /// <summary>
        /// Saves the position, size, and maximized state of the specified window to UserDataStore.
        /// </summary>
        /// <param name="window">The window instance to record.</param>
        public static void SavePlacement(WindowEx window);

        /// <summary>
        /// Restores saved placement coordinates or maximized state to the specified window.
        /// </summary>
        /// <param name="window">The window instance to restore.</param>
        public static void RestorePlacement(WindowEx window);
    }
}
```

---

## 3. UserDataStore Public API Contract

Thread-safe static storage utility for application preferences.

```csharp
namespace DataSphere.Utils
{
    /// <summary>
    /// Thread-safe local file-based key-value storage for application and user preferences.
    /// </summary>
    public static class UserDataStore
    {
        /// <summary>
        /// Retrieves a strongly-typed preference value for the given key.
        /// </summary>
        /// <typeparam name="T">The target type to deserialize.</typeparam>
        /// <param name="key">The configuration key name.</param>
        /// <returns>The stored value, or default(T) if not found or corrupted.</returns>
        public static T GetValue<T>(string key);

        /// <summary>
        /// Persists a preference value under the specified key to the user data store.
        /// </summary>
        /// <typeparam name="T">The value type.</typeparam>
        /// <param name="key">The configuration key name.</param>
        /// <param name="value">The value to store.</param>
        /// <returns><c>true</c> if successfully written; otherwise <c>false</c>.</returns>
        public static bool SetValue<T>(string key, T value);

        /// <summary>
        /// Retrieves and decrypts a sensitive string preference value.
        /// </summary>
        /// <param name="key">The configuration key name.</param>
        /// <returns>The decrypted plaintext string, or empty string if not found.</returns>
        public static string GetValuePass(string key);

        /// <summary>
        /// Encrypts and persists a sensitive string preference value.
        /// </summary>
        /// <param name="key">The configuration key name.</param>
        /// <param name="value">The plaintext value to encrypt and store.</param>
        /// <returns><c>true</c> if successfully encrypted and saved; otherwise <c>false</c>.</returns>
        public static bool SetValuePass(string key, string value);

        /// <summary>
        /// Resets all stored preferences to empty defaults.
        /// </summary>
        public static void Reset();

        /// <summary>
        /// Forces reloading of data from disk into memory.
        /// </summary>
        public static void Reload();
    }
}
```
