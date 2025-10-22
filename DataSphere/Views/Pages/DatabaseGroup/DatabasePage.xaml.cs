namespace DataSphere.Views.Pages
{
    [PageMeta("page_db_title", "page_db_summary", SymbolRegular.DatabaseLink24, 1, false)]
    public partial class DatabasePage : INavigableView<DatabaseViewModel>
    {
        public DatabaseViewModel ViewModel { get; }

        public DatabasePage(DatabaseViewModel viewModel)
        {
            ViewModel = viewModel;
            DataContext = this;

            InitializeComponent();
        }
    }
}
