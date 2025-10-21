namespace DataSphere.Views.PagesBottom
{
    [PageMeta("page_settings_title", "page_settings_summary", SymbolRegular.Settings24, 999)]
    public partial class SettingsPage : INavigableView<SettingsViewModel>
    {
        public SettingsViewModel ViewModel { get; }
        public SettingsPage(SettingsViewModel viewModel)
        {
            ViewModel = viewModel;
            DataContext = this;

            InitializeComponent();
        }
    }
}
