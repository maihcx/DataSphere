namespace DataSphere.ViewModels.Pages
{
    public partial class DatabaseViewModel : ObservableObject, INavigationAware
    {
        private bool _isInitialized = false;

        public Task OnNavigatedToAsync()
        {
            if (!_isInitialized)
                InitializeViewModel();

            return Task.CompletedTask;
        }

        public Task OnNavigatedFromAsync() => Task.CompletedTask;

        private void InitializeViewModel()
        {
            _isInitialized = true;
        }

        [ObservableProperty]
        private ObservableCollection<TabItemView> _tabsViewer = new()
        {
            new TabItemView { 
                Icon = new SymbolIcon() { Symbol = SymbolRegular.DatabasePlugConnected20 }, 
                HeaderKey = "connection_title", 
                Content = new Views.Pages.DatabaseGroup.ConnectViewControl(),
                CanClose = false
            }
        };
    }
}
