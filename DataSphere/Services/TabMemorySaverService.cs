using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using DataSphere.Models;
using DataSphere.Services.Contracts;
using DataSphere.Utils;

namespace DataSphere.Services
{
    /// <summary>
    /// Service managing the automated background evaluation and sleeping lifecycle of inactive tabs to conserve memory.
    /// </summary>
    public class TabMemorySaverService : ITabMemorySaverService
    {
        private const string SettingKeyEnableSaver = "EnableTabMemorySaver";
        private const string SettingKeyTimeoutMinutes = "TabSleepTimeoutMinutes";

        private readonly IWindowManager _windowManager;
        private DispatcherTimer? _timer;
        private bool _isEnabled;
        private int _idleTimeoutMinutes;
        private bool _isDisposed;

        /// <summary>
        /// Gets or sets a value indicating whether background tab memory saving is active.
        /// When toggled off, any currently sleeping tabs are awakened immediately.
        /// </summary>
        public bool IsEnabled
        {
            get => _isEnabled;
            set
            {
                if (_isEnabled != value)
                {
                    _isEnabled = value;
                    UserDataStore.SetValue(SettingKeyEnableSaver, value);

                    if (_isEnabled)
                    {
                        StartTimer();
                    }
                    else
                    {
                        StopTimer();
                        WakeUpAllTabs();
                    }
                }
            }
        }

        /// <summary>
        /// Gets or sets the idle timeout in minutes before putting an inactive tab to sleep.
        /// </summary>
        public int IdleTimeoutMinutes
        {
            get => _idleTimeoutMinutes;
            set
            {
                if (_idleTimeoutMinutes != value)
                {
                    _idleTimeoutMinutes = value > 0 ? value : 15;
                    UserDataStore.SetValue(SettingKeyTimeoutMinutes, _idleTimeoutMinutes);
                }
            }
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="TabMemorySaverService"/> class.
        /// </summary>
        /// <param name="windowManager">The window manager service used to enumerate open window sessions and their tabs.</param>
        public TabMemorySaverService(IWindowManager windowManager)
        {
            _windowManager = windowManager ?? throw new ArgumentNullException(nameof(windowManager));

            _isEnabled = UserDataStore.GetValue<bool?>(SettingKeyEnableSaver) ?? true;
            _idleTimeoutMinutes = UserDataStore.GetValue<int?>(SettingKeyTimeoutMinutes) ?? 15;

            InitializeTimer();
        }

        private void InitializeTimer()
        {
            try
            {
                _timer = new DispatcherTimer
                {
                    Interval = TimeSpan.FromSeconds(60)
                };
                _timer.Tick += (s, e) => OnTimerTick();

                if (_isEnabled)
                {
                    _timer.Start();
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[TabMemorySaverService] Warning: Failed to initialize DispatcherTimer on construction: {ex.Message}");
            }
        }

        private void StartTimer()
        {
            if (_timer == null)
            {
                InitializeTimer();
            }
            else if (!_timer.IsEnabled)
            {
                _timer.Start();
            }
        }

        private void StopTimer()
        {
            if (_timer != null && _timer.IsEnabled)
            {
                _timer.Stop();
            }
        }

        private void OnTimerTick()
        {
            if (!_isEnabled || _isDisposed)
            {
                return;
            }

            foreach (var session in _windowManager.Windows)
            {
                EvaluateTabs(session.Tabs, session.SelectedTab);
            }
        }

        /// <summary>
        /// Manually triggers an evaluation pass over all open tabs.
        /// </summary>
        /// <param name="tabs">The collection of all currently opened tabs.</param>
        /// <param name="activeTab">The currently selected active tab, which must remain hot.</param>
        public void EvaluateTabs(IEnumerable<TabItemModel> tabs, TabItemModel? activeTab)
        {
            if (!_isEnabled || tabs == null)
            {
                return;
            }

            var now = DateTime.UtcNow;
            var timeout = TimeSpan.FromMinutes(_idleTimeoutMinutes);

            foreach (var tab in tabs)
            {
                // Active tab or selected tab must never sleep
                if (tab == activeTab || tab.IsSelected)
                {
                    continue;
                }

                // Check eligibility for sleep
                if (!tab.IsSleeping && tab.CanSleep && (now - tab.LastActiveTime) >= timeout)
                {
                    PutTabToSleep(tab);
                }
            }
        }

        private void PutTabToSleep(TabItemModel tab)
        {
            if (tab.Content is ISleepableTabContent sleepable)
            {
                if (!sleepable.CanSleep)
                {
                    return;
                }
                sleepable.Sleep();
            }

            tab.IsSleeping = true;
            tab.State = TabLifecycleState.Sleeping;
        }

        /// <summary>
        /// Awakes a sleeping tab on demand, rehydrating its visual state and restoring active lifecycle state.
        /// </summary>
        /// <param name="tab">The tab to wake up.</param>
        public void WakeUpTab(TabItemModel tab)
        {
            if (tab == null)
            {
                return;
            }

            if (tab.IsSleeping)
            {
                if (tab.Content is ISleepableTabContent sleepable)
                {
                    sleepable.WakeUp();
                }

                tab.IsSleeping = false;
                tab.LastActiveTime = DateTime.UtcNow;

                if (tab.IsSelected)
                {
                    tab.State = TabLifecycleState.Active;
                }
                else
                {
                    tab.State = TabLifecycleState.Background;
                }
            }
        }

        /// <summary>
        /// Awakes all currently sleeping tabs across all open window sessions.
        /// </summary>
        private void WakeUpAllTabs()
        {
            foreach (var session in _windowManager.Windows)
            {
                foreach (var tab in session.Tabs)
                {
                    if (tab.IsSleeping)
                    {
                        WakeUpTab(tab);
                    }
                }
            }
        }

        /// <summary>
        /// Releases timer resources and detaches event listeners.
        /// </summary>
        public void Dispose()
        {
            if (!_isDisposed)
            {
                _isDisposed = true;
                StopTimer();
                _timer = null;
            }
        }
    }
}
