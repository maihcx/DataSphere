using CommunityToolkit.Mvvm.Messaging;

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

            WeakReferenceMessenger.Default.Register<GenericMessage<(ConnectionModel, string)>>(this, (r, m) =>
            {
                var conn = m.Value.Item1;
                var handleType = m.Value.Item2;

                var existingTab = TabsViewer.FirstOrDefault(t =>
                    t.Key.Equals(conn.Key));

                if (existingTab != null)
                {
                    existingTab.Header = conn.Name;
                    if (handleType == "add")
                    {
                        SelectedTab = existingTab;
                    }
                }
                else if (handleType == "add")
                {
                    var newTab = new TabItemView()
                    {
                        Header = conn.Name,
                        Icon = conn.Icon,
                        Content = new Views.Pages.DatabaseGroup.DatabaseViewControl(),
                        CanClose = true,
                        Key = conn.Key,
                    };

                    TabsViewer.Add(newTab);
                    SelectedTab = newTab;
                }
            });
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

        [ObservableProperty]
        private TabItemView? _selectedTab;
    }
}
