using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using DataSphere.Models;
using DataSphere.Services.Contracts;
using DataSphere.Utils;
using DataSphere.Views.Pages.DatabaseGroup;

namespace DataSphere.ViewModels.Pages.DatabaseGroup
{
    /// <summary>
    /// ViewModel for the Database management workspace page, governing the inner TabView strip.
    /// Tab 0 is anchored to the connection catalog explorer; subsequent tabs host active database sessions.
    /// </summary>
    public partial class DatabaseViewModel : ObservableObject
    {
        private readonly IDialogService _dialogService;

        /// <summary>
        /// Gets the ViewModel driving the connection explorer tree.
        /// </summary>
        public ConnectControlViewModel ConnectViewModel { get; }

        /// <summary>
        /// Gets the collection of open inner tabs hosted inside the Database workspace.
        /// </summary>
        public ObservableCollection<InnerTabItemModel> InnerTabs { get; } = new();

        /// <summary>
        /// Gets or sets the currently active inner tab.
        /// </summary>
        [ObservableProperty]
        public partial InnerTabItemModel? SelectedInnerTab { get; set; }

        /// <summary>
        /// Initializes a new instance of the <see cref="DatabaseViewModel"/> class.
        /// </summary>
        /// <param name="dialogService">The dialog service for launching connection and database dialogs.</param>
        public DatabaseViewModel(IDialogService dialogService)
        {
            _dialogService = dialogService ?? throw new ArgumentNullException(nameof(dialogService));

            ConnectViewModel = new ConnectControlViewModel(_dialogService)
            {
                OnOpenConnection = OpenConnectionTab
            };

            InitializeTabs();

            TranslationSource.Instance.PropertyChanged += (s, e) => UpdateLocalizedStrings();
        }

        private void InitializeTabs()
        {
            object? connectControl = null;
            try
            {
                connectControl = new ConnectViewControl(ConnectViewModel);
            }
            catch
            {
                // Fallback for headless environments or unit testing where WinUI Xaml Core is not active
                connectControl = ConnectViewModel;
            }

            var tab0 = new InnerTabItemModel
            {
                Header = LanguageBase.GetLangValue("tab_connections_header"),
                IconGlyph = "\uE774",
                Content = connectControl,
                IsClosable = false,
                ConnectionKey = "tab_connections_explorer"
            };

            InnerTabs.Add(tab0);
            SelectedInnerTab = tab0;
        }

        private void UpdateLocalizedStrings()
        {
            if (InnerTabs.Count > 0 && InnerTabs[0].ConnectionKey == "tab_connections_explorer")
            {
                InnerTabs[0].Header = LanguageBase.GetLangValue("tab_connections_header");
            }
        }

        /// <summary>
        /// Opens a database connection session in a dedicated inner tab, or activates it if already open.
        /// </summary>
        /// <param name="connection">The database connection configuration.</param>
        public void OpenConnectionTab(ConnectionModel connection)
        {
            if (connection == null) return;

            var existing = InnerTabs.FirstOrDefault(t => t.ConnectionKey == connection.Key);
            if (existing != null)
            {
                SelectedInnerTab = existing;
                return;
            }

            var dbVm = new DatabaseControlViewModel(connection, _dialogService);
            object? dbView = null;
            try
            {
                dbView = new DatabaseViewControl(dbVm);
            }
            catch
            {
                // Fallback for headless environments or unit testing where WinUI Xaml Core is not active
                dbView = dbVm;
            }

            var newTab = new InnerTabItemModel
            {
                Header = connection.Name,
                IconGlyph = "\uE774",
                Content = dbView,
                IsClosable = true,
                ConnectionKey = connection.Key,
                DisposableContext = dbVm
            };

            InnerTabs.Add(newTab);
            SelectedInnerTab = newTab;
        }

        /// <summary>
        /// Closes an open inner tab and disposes its database connection resources.
        /// </summary>
        /// <param name="tab">The inner tab to close.</param>
        public void CloseTab(InnerTabItemModel tab)
        {
            if (tab == null || !tab.IsClosable) return;

            int index = InnerTabs.IndexOf(tab);
            if (index < 0) return;

            bool wasSelected = Equals(SelectedInnerTab, tab);

            tab.DisposableContext?.Dispose();
            InnerTabs.RemoveAt(index);

            if (wasSelected && InnerTabs.Count > 0)
            {
                int newIndex = Math.Max(0, index - 1);
                SelectedInnerTab = InnerTabs[newIndex];
            }
        }
    }
}
