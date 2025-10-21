using System.Collections.ObjectModel;
using Wpf.Ui.Controls;

namespace DataSphere.ViewModels.Windows
{
    public partial class MainWindowViewModel : ObservableObject
    {
        private bool _isInitialized = false;

        private readonly INavigationService _navigationService;

        [ObservableProperty]
        private string? _applicationTitle = AppInfoHelper.AppName;

        [ObservableProperty]
        private ObservableCollection<object> _menuItems;

        [ObservableProperty]
        private ObservableCollection<object> _footerMenuItems;

        public MainWindowViewModel(INavigationService navigationService)
        {
            NavigationHandle.NavigationService = navigationService;
            _navigationService = navigationService;
            _menuItems = NavigationHandle.GetNavCardsInNamespace("DataSphere.Views.Pages");
            _footerMenuItems = NavigationHandle.GetNavCardsInNamespace("DataSphere.Views.PagesBottom");
        }

        public void OnNavigatedTo()
        {
            if (!_isInitialized)
                InitializeViewModel();
        }

        private void InitializeViewModel()
        {
            _isInitialized = true;
        }
    }
}
