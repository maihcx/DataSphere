namespace DataSphere.Views.Pages
{
    [PageMeta("page_home_title", "page_home_summary", SymbolRegular.Home48, 0, false)]
    public partial class DashboardPage : INavigableView<DashboardViewModel>
    {
        public DashboardViewModel ViewModel { get; }

        public DashboardPage(DashboardViewModel viewModel)
        {
            ViewModel = viewModel;
            DataContext = this;

            InitializeComponent();
        }
    }
}
