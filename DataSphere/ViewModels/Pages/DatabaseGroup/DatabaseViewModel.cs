using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using DataSphere.Models;
using DataSphere.Services.Contracts;
using DataSphere.Utils;
using DataSphere.Views.Pages.DatabaseGroup;

namespace DataSphere.ViewModels.Pages.DatabaseGroup
{
    /// <summary>
    /// ViewModel for the Database management workspace page, governing the inner TabView strip.
    /// Anchors the permanent Connection catalog explorer in TabStripHeader and hosts open database sessions as dynamic tabs.
    /// </summary>
    public partial class DatabaseViewModel : ObservableObject, IDisposable
    {
        private readonly IDialogService _dialogService;
        private readonly System.ComponentModel.PropertyChangedEventHandler _translationHandler;
        private bool _disposed;

        /// <summary>
        /// Gets the ViewModel driving the connection explorer tree.
        /// </summary>
        public ConnectControlViewModel ConnectViewModel { get; }

        /// <summary>
        /// Gets the dedicated anchored tab item model for the Connection Catalog Explorer.
        /// Rendered permanently inside <c>InnerTabView.TabStripHeader</c>.
        /// </summary>
        public InnerTabItemModel ConnectionTab { get; }

        /// <summary>
        /// Gets the collection of open dynamic inner tabs (active database sessions) hosted inside the Database workspace.
        /// </summary>
        public ObservableCollection<InnerTabItemModel> InnerTabs { get; } = new();

        /// <summary>
        /// Gets or sets a value indicating whether the anchored Connection tab in TabStripHeader is selected.
        /// Mutual exclusion: setting this to true deselects <see cref="SelectedInnerTab"/>.
        /// </summary>
        [ObservableProperty]
        [NotifyPropertyChangedFor(nameof(EffectiveTabIndex))]
        [NotifyPropertyChangedFor(nameof(ActiveInnerContent))]
        public partial bool IsConnectionSelected { get; set; } = true;

        /// <summary>
        /// Gets or sets the currently active dynamic database tab, or null if Connection is active.
        /// Mutual exclusion: setting this to a non-null tab sets <see cref="IsConnectionSelected"/> to false.
        /// </summary>
        [ObservableProperty]
        [NotifyPropertyChangedFor(nameof(EffectiveTabIndex))]
        [NotifyPropertyChangedFor(nameof(ActiveInnerContent))]
        public partial InnerTabItemModel? SelectedInnerTab { get; set; }

        /// <summary>
        /// Gets the zero-based effective index of the currently active tab (0 for Connection tab, 1+ for dynamic workspace tabs).
        /// Used by the viewport host to calculate directional horizontal transition animations.
        /// </summary>
        public int EffectiveTabIndex => IsConnectionSelected ? 0 : (SelectedInnerTab != null ? InnerTabs.IndexOf(SelectedInnerTab) + 1 : 0);

        /// <summary>
        /// Gets the active content for the viewport ContentControl.
        /// Resolves to <see cref="ConnectionTab"/>.Content when <see cref="IsConnectionSelected"/> is true,
        /// otherwise <see cref="SelectedInnerTab"/>.Content.
        /// </summary>
        public object? ActiveInnerContent => IsConnectionSelected ? ConnectionTab.Content : SelectedInnerTab?.Content;

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

            ConnectionTab = CreateConnectionTab();

            _translationHandler = (s, e) => UpdateLocalizedStrings();
            TranslationSource.Instance.PropertyChanged += _translationHandler;
        }

        private InnerTabItemModel CreateConnectionTab()
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

            return new InnerTabItemModel
            {
                Header = LanguageBase.GetLangValue("tab_connections_header"),
                IconGlyph = "\uE703",
                Content = connectControl,
                IsClosable = false,
                ConnectionKey = "tab_connections_explorer"
            };
        }

        partial void OnSelectedInnerTabChanged(InnerTabItemModel? value)
        {
            if (value != null)
            {
                IsConnectionSelected = false;
            }
        }

        partial void OnIsConnectionSelectedChanged(bool value)
        {
            if (value)
            {
                SelectedInnerTab = null;
            }
        }

        /// <summary>
        /// Activates the anchored Connection tab and deselects any open dynamic database tabs.
        /// </summary>
        [RelayCommand]
        public void SelectConnection()
        {
            IsConnectionSelected = true;
            SelectedInnerTab = null;
            OnPropertyChanged(nameof(EffectiveTabIndex));
            OnPropertyChanged(nameof(ActiveInnerContent));
        }

        private void UpdateLocalizedStrings()
        {
            if (ConnectionTab != null)
            {
                ConnectionTab.Header = LanguageBase.GetLangValue("tab_connections_header");
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
                IsConnectionSelected = false;
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
            IsConnectionSelected = false;
        }

        /// <summary>
        /// Closes an open dynamic inner tab and disposes its database connection resources.
        /// If all dynamic tabs are closed, selection automatically falls back to the Connection tab.
        /// </summary>
        /// <param name="tab">The inner tab to close.</param>
        public void CloseTab(InnerTabItemModel tab)
        {
            if (tab == null || !tab.IsClosable) return;

            int index = InnerTabs.IndexOf(tab);
            if (index < 0) return;

            bool wasSelected = Equals(SelectedInnerTab, tab);

            tab.Dispose();
            InnerTabs.RemoveAt(index);

            if (wasSelected)
            {
                if (InnerTabs.Count > 0)
                {
                    int newIndex = Math.Clamp(index - 1, 0, InnerTabs.Count - 1);
                    SelectedInnerTab = InnerTabs[newIndex];
                }
                else
                {
                    SelectConnection();
                }
            }
        }

        /// <summary>
        /// Disposes all open inner database sessions, the anchored connection explorer tab, and unhooks global event listeners.
        /// </summary>
        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;

            TranslationSource.Instance.PropertyChanged -= _translationHandler;

            foreach (var tab in InnerTabs)
            {
                tab.Dispose();
            }
            InnerTabs.Clear();
            ConnectionTab?.Dispose();
            SelectedInnerTab = null;

            GC.SuppressFinalize(this);
        }
    }
}
