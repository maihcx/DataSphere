using DataSphere.Models;
using DataSphere.Models.Database;
using DataSphere.Services.Database.Interface;

namespace DataSphere.Services.Contracts
{
    /// <summary>
    /// Service coordinating the presentation of native WinUI 3 ContentDialogs with explicit XamlRoot assignment.
    /// </summary>
    public interface IDialogService
    {
        /// <summary>
        /// Displays the connection creation or editing dialog.
        /// </summary>
        /// <param name="existingConnection">Optional connection model to edit.</param>
        /// <param name="xamlRoot">Optional explicit XamlRoot visual anchor.</param>
        /// <returns>The created or updated ConnectionModel, or null if canceled.</returns>
        Task<ConnectionModel?> ShowConnectionEditingDialogAsync(ConnectionModel? existingConnection = null, object? xamlRoot = null);

        /// <summary>
        /// Displays the database creation dialog.
        /// </summary>
        /// <param name="connection">The active database connection used to retrieve collations and verify credentials.</param>
        /// <param name="xamlRoot">Optional explicit XamlRoot visual anchor.</param>
        /// <returns>The created DatabaseInfo specification, or null if canceled.</returns>
        Task<DatabaseInfo?> ShowDatabaseEditingDialogAsync(IDatabaseConnection connection, object? xamlRoot = null);

        /// <summary>
        /// Displays an asynchronous confirmation dialog.
        /// </summary>
        /// <param name="titleKey">Localization key for the dialog title.</param>
        /// <param name="messageKey">Localization key for the confirmation prompt message.</param>
        /// <param name="formatArgs">Optional format arguments for the localized message.</param>
        /// <param name="xamlRoot">Optional explicit XamlRoot visual anchor.</param>
        /// <returns><c>true</c> if the user confirmed the primary action; otherwise, <c>false</c>.</returns>
        Task<bool> ShowConfirmationDialogAsync(string titleKey, string messageKey, object[]? formatArgs = null, object? xamlRoot = null);
    }
}
