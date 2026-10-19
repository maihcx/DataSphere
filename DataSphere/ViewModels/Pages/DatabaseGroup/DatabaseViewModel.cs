using CommunityToolkit.Mvvm.ComponentModel;
using DataSphere.Utils;

namespace DataSphere.ViewModels.Pages.DatabaseGroup
{
    /// <summary>
    /// ViewModel for the Database management page, governing connection sessions and SQL query operations.
    /// </summary>
    public partial class DatabaseViewModel : ObservableObject
    {
        /// <summary>
        /// Gets or sets the display title of the database workspace.
        /// </summary>
        [ObservableProperty]
        public partial string Title { get; set; } = string.Empty;

        /// <summary>
        /// Initializes a new instance of the <see cref="DatabaseViewModel"/> class.
        /// </summary>
        public DatabaseViewModel()
        {
            UpdateLocalizedStrings();
            TranslationSource.Instance.PropertyChanged += (s, e) => UpdateLocalizedStrings();
        }

        private void UpdateLocalizedStrings()
        {
            Title = LanguageBase.GetLangValue("page_db_title");
        }
    }
}
