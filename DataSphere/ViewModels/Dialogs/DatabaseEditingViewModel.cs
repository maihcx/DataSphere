using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using DataSphere.Models.Database;
using DataSphere.Services.Database.Interface;

namespace DataSphere.ViewModels.Dialogs
{
    /// <summary>
    /// ViewModel for configuring database schema specifications (name, collation) prior to creation.
    /// </summary>
    public partial class DatabaseEditingViewModel : ObservableObject
    {
        private readonly IDatabaseConnection _connection;

        /// <summary>
        /// Gets or sets the database schema name.
        /// </summary>
        [ObservableProperty]
        public partial string DatabaseName { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the collection of collations retrieved from the server.
        /// </summary>
        [ObservableProperty]
        public partial ObservableCollection<CollationModel>? DatabaseCollation { get; set; }

        /// <summary>
        /// Gets or sets the currently selected collation model.
        /// </summary>
        [ObservableProperty]
        public partial CollationModel? DatabaseCollationSelected { get; set; }

        /// <summary>
        /// Gets a value indicating whether database specifications are valid to submit.
        /// </summary>
        public bool IsAllowSubmit => !string.IsNullOrWhiteSpace(DatabaseName);

        /// <summary>
        /// Initializes a new instance of the <see cref="DatabaseEditingViewModel"/> class.
        /// </summary>
        /// <param name="connection">The active database connection.</param>
        public DatabaseEditingViewModel(IDatabaseConnection connection)
        {
            _connection = connection ?? throw new ArgumentNullException(nameof(connection));
            _ = LoadCollationsAsync();
        }

        partial void OnDatabaseNameChanged(string value) => OnPropertyChanged(nameof(IsAllowSubmit));

        private async Task LoadCollationsAsync()
        {
            try
            {
                var collations = await _connection.GetAllCollation();
                if (collations != null)
                {
                    DatabaseCollation = collations;
                    DatabaseCollationSelected = collations.FirstOrDefault(c => c.Collation == "utf8mb4_unicode_ci")
                        ?? collations.FirstOrDefault()
                        ?? new CollationModel { Collation = "utf8mb4_general_ci" };
                }
            }
            catch
            {
                // Fallback to basic collation
                DatabaseCollation = new ObservableCollection<CollationModel>
                {
                    new() { Collation = "utf8mb4_unicode_ci" },
                    new() { Collation = "utf8mb4_general_ci" }
                };
                DatabaseCollationSelected = DatabaseCollation.First();
            }
        }

        /// <summary>
        /// Converts the current configuration into a new <see cref="DatabaseInfo"/> instance.
        /// </summary>
        /// <returns>The populated DatabaseInfo model.</returns>
        public DatabaseInfo ToDatabaseInfo()
        {
            return new DatabaseInfo
            {
                Name = DatabaseName.Trim(),
                Collation = DatabaseCollationSelected ?? new CollationModel { Collation = "utf8mb4_unicode_ci" }
            };
        }
    }
}
