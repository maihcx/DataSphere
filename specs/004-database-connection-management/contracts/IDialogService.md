# Contract: WinUI 3 Native ContentDialog Integration

**Namespace**: `DataSphere.Services.Contracts` / `DataSphere.Dialogs`  

## 1. Overview
Defines standard patterns for presenting modal dialogs in WinUI 3, ensuring explicit assignment of `XamlRoot` per Windows App SDK requirements.

## 2. Interface Definition

```csharp
namespace DataSphere.Services.Contracts
{
    /// <summary>
    /// Coordinates the presentation of WinUI 3 ContentDialogs with verified XamlRoot binding.
    /// </summary>
    public interface IDialogService
    {
        /// <summary>
        /// Shows the connection editing ContentDialog for creating or modifying a connection.
        /// </summary>
        /// <param name="existingConnection">Optional existing connection for edit mode.</param>
        /// <param name="xamlRoot">Optional explicit XamlRoot; resolved from active window if null.</param>
        /// <returns>The created or edited ConnectionModel, or null if canceled.</returns>
        Task<ConnectionModel?> ShowConnectionEditingDialogAsync(ConnectionModel? existingConnection = null, object? xamlRoot = null);

        /// <summary>
        /// Shows the database creation/editing ContentDialog.
        /// </summary>
        /// <param name="connection">The active IDatabaseConnection to populate collations and execute creation.</param>
        /// <param name="xamlRoot">Optional explicit XamlRoot.</param>
        /// <returns>The created/edited DatabaseInfo, or null if canceled.</returns>
        Task<DatabaseInfo?> ShowDatabaseEditingDialogAsync(IDatabaseConnection connection, object? xamlRoot = null);

        /// <summary>
        /// Displays an asynchronous confirmation dialog.
        /// </summary>
        /// <param name="titleKey">Localization key for the dialog title.</param>
        /// <param name="messageKey">Localization key for the dialog message body.</param>
        /// <param name="formatArgs">Optional format arguments for the message string.</param>
        /// <param name="xamlRoot">Optional explicit XamlRoot.</param>
        /// <returns><c>true</c> if confirmed by user (Primary action); otherwise, <c>false</c>.</returns>
        Task<bool> ShowConfirmationDialogAsync(string titleKey, string messageKey, object[]? formatArgs = null, object? xamlRoot = null);
    }
}
```

## 3. Implementation Rules
1. Every `ContentDialog` MUST set its `XamlRoot` before calling `ShowAsync()`.
2. Win32 message boxes (`MessageBox.Show`) are strictly forbidden (Constitution Principle II).
3. All dialog titles, buttons, and error messages MUST use `TranslationSource` localization.
