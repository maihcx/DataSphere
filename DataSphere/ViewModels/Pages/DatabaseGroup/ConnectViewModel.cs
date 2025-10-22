using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DataSphere.ViewModels.Pages.DatabaseGroup
{
    public partial class ConnectViewModel : ObservableObject
    {
        private bool _isInitialized = false;

        public ConnectViewModel()
        {
            if (!_isInitialized)
                InitializeViewModel();
        }

        private void InitializeViewModel()
        {
            _isInitialized = true;
        }

        [ObservableProperty]
        private ObservableCollection<ContextAction> _viewContextItem = new()
        {
            new ContextAction()
            {
                NameKey = "ctx_add_title",
                Icon = new SymbolIcon() { Symbol = SymbolRegular.Add20 },
                Children = new ObservableCollection<ContextAction>()
                {
                    new ContextAction()
                    {
                        NameKey = "ctx_mysql_title",
                        Icon = new SymbolIcon() { Symbol = SymbolRegular.Database20 },
                        Command = new RelayCommand(() =>
                        {
                            // Add database logic here
                        })
                    }
                }
            }
        };
    }
}
