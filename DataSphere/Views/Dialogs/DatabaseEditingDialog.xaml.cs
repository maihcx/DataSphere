using Microsoft.UI.Xaml.Controls;
using DataSphere.Models.Database;
using DataSphere.Services.Database.Interface;
using DataSphere.ViewModels.Dialogs;

namespace DataSphere.Views.Dialogs
{
    /// <summary>
    /// Native WinUI 3 ContentDialog for specifying new database schema parameters.
    /// </summary>
    public sealed partial class DatabaseEditingDialog : ContentDialog
    {
        /// <summary>
        /// Gets the ViewModel governing the database editing dialog.
        /// </summary>
        public DatabaseEditingViewModel ViewModel { get; }

        /// <summary>
        /// Gets the configured <see cref="DatabaseInfo"/> specification if confirmed.
        /// </summary>
        public DatabaseInfo ResultDatabaseInfo => ViewModel.ToDatabaseInfo();

        /// <summary>
        /// Initializes a new instance of the <see cref="DatabaseEditingDialog"/> class.
        /// </summary>
        /// <param name="connection">The active database connection used to query collations.</param>
        public DatabaseEditingDialog(IDatabaseConnection connection)
        {
            ViewModel = new DatabaseEditingViewModel(connection);
            InitializeComponent();
        }
    }
}
