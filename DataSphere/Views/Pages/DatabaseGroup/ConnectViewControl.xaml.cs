using DataSphere.ViewModels.Pages.DatabaseGroup;

namespace DataSphere.Views.Pages.DatabaseGroup
{
    /// <summary>
    /// Interaction logic for ConnectViewControl.xaml
    /// </summary>
    public partial class ConnectViewControl : UserControl
    {
        public ConnectViewModel ViewModel { get; }

        public ConnectViewControl()
        {
            ViewModel = new ConnectViewModel();
            DataContext = this;

            InitializeComponent();
        }
    }
}
