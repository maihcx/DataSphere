using System.Collections.ObjectModel;
using Windows.Foundation;
using DataSphere.Models;
using DataSphere.Services.Contracts;

namespace DataSphere.Services
{
    /// <summary>
    /// Service managing multi-window lifecycle, tab tear-off, and cross-window tab transfers.
    /// </summary>
    public class WindowManager : IWindowManager
    {
        private readonly List<WindowSession> _windows = new();
        private readonly IServiceProvider _serviceProvider;
        private readonly object _syncLock = new();
        private WindowSession? _activeWindowSession;

        /// <summary>
        /// Gets the read-only collection of all currently registered WindowSessions.
        /// </summary>
        public IReadOnlyList<WindowSession> Windows
        {
            get
            {
                lock (_syncLock)
                {
                    return _windows.ToList().AsReadOnly();
                }
            }
        }

        /// <summary>
        /// Gets the currently active top-level window session that has user focus.
        /// </summary>
        public WindowSession? ActiveWindowSession
        {
            get
            {
                lock (_syncLock)
                {
                    return _activeWindowSession;
                }
            }
            private set
            {
                lock (_syncLock)
                {
                    _activeWindowSession = value;
                }
            }
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="WindowManager"/> class.
        /// </summary>
        /// <param name="serviceProvider">The application service provider for resolving window dependencies.</param>
        public WindowManager(IServiceProvider serviceProvider)
        {
            _serviceProvider = serviceProvider ?? throw new ArgumentNullException(nameof(serviceProvider));
        }

        /// <summary>
        /// Registers a newly created top-level window session.
        /// </summary>
        /// <param name="session">The window session to register.</param>
        public void RegisterWindow(WindowSession session)
        {
            if (session == null)
            {
                throw new ArgumentNullException(nameof(session));
            }

            lock (_syncLock)
            {
                if (!_windows.Any(w => w.WindowId == session.WindowId))
                {
                    _windows.Add(session);
                    if (_activeWindowSession == null)
                    {
                        _activeWindowSession = session;
                    }
                }
            }

            if (session.WindowInstance != null)
            {
                session.WindowInstance.Activated += (sender, args) =>
                {
                    if (args.WindowActivationState != Microsoft.UI.Xaml.WindowActivationState.Deactivated)
                    {
                        ActiveWindowSession = session;
                    }
                };

                session.WindowInstance.Closed += (sender, args) =>
                {
                    UnregisterWindow(session.WindowId);
                };
            }
        }

        /// <summary>
        /// Deregisters and cleans up a closing window session.
        /// </summary>
        /// <param name="windowId">The unique ID of the closing window.</param>
        public void UnregisterWindow(Guid windowId)
        {
            bool shouldExit = false;

            lock (_syncLock)
            {
                var session = _windows.FirstOrDefault(w => w.WindowId == windowId);
                if (session != null)
                {
                    _windows.Remove(session);
                }

                if (_activeWindowSession?.WindowId == windowId)
                {
                    _activeWindowSession = _windows.LastOrDefault();
                }

                if (_windows.Count == 0)
                {
                    shouldExit = true;
                }
            }

            if (shouldExit)
            {
                Application.Current?.Exit();
            }
        }

        /// <summary>
        /// Spawns a new independent window hosting a torn-off tab at the specified screen coordinates.
        /// </summary>
        /// <param name="tab">The tab model being torn off.</param>
        /// <param name="screenPosition">The drop coordinates on screen.</param>
        /// <returns>The newly instantiated WindowSession.</returns>
        /// <summary>
        /// Spawns a new independent window hosting a torn-off tab at the specified screen coordinates.
        /// Reuses the session registered by ShellWindow to avoid duplicate registration.
        /// </summary>
        /// <param name="tab">The tab model being torn off.</param>
        /// <param name="screenPosition">The drop coordinates on screen.</param>
        /// <returns>The newly instantiated WindowSession.</returns>
        public WindowSession TearOffTabToNewWindow(TabItemModel tab, Point screenPosition)
        {
            if (tab == null)
            {
                throw new ArgumentNullException(nameof(tab));
            }

            // Create a new window instance via DI or type activation
            var shellWindowType = Type.GetType("DataSphere.Views.Windows.ShellWindow, DataSphere");
            Window? newWindow = null;

            if (shellWindowType != null)
            {
                newWindow = (_serviceProvider.GetService(shellWindowType) ?? Activator.CreateInstance(shellWindowType)) as Window;
            }

            WindowSession session;
            if (newWindow is Views.Windows.ShellWindow sw)
            {
                // ShellWindow constructor already registers its own session via RegisterWindow
                session = sw.Session ?? new WindowSession { WindowInstance = sw, IsPrimary = false };
                session.IsPrimary = false;

                if (sw.Session == null)
                {
                    RegisterWindow(session);
                }

                sw.ViewModel.TabService.Tabs.Add(tab);
                sw.ViewModel.TabService.SelectedTab = tab;
                tab.State = TabLifecycleState.Active;
            }
            else if (newWindow?.Content is FrameworkElement fe && fe.DataContext is ViewModels.Windows.ShellViewModel vm)
            {
                session = new WindowSession
                {
                    WindowInstance = newWindow,
                    IsPrimary = false
                };
                RegisterWindow(session);

                vm.TabService.Tabs.Add(tab);
                vm.TabService.SelectedTab = tab;
                tab.State = TabLifecycleState.Active;
            }
            else
            {
                session = new WindowSession
                {
                    WindowInstance = newWindow,
                    IsPrimary = false
                };
                RegisterWindow(session);
                session.AddTab(tab);
            }

            if (newWindow != null)
            {
                // Position window at target coordinates
                newWindow.AppWindow.Move(new Windows.Graphics.PointInt32((int)screenPosition.X, (int)screenPosition.Y));
                newWindow.Activate();
            }

            return session;
        }

        /// <summary>
        /// Transfers a tab from a donor window to a target window at a specific index.
        /// Enforces the donor window auto-closure rule if the donor window is a secondary window
        /// and transferring the tab leaves only the non-closable Home tab.
        /// </summary>
        /// <param name="sourceWindowId">The ID of the donor window.</param>
        /// <param name="targetWindowId">The ID of the receiving window.</param>
        /// <param name="tab">The tab model to transfer.</param>
        /// <param name="targetIndex">The target insertion index in the receiving tab strip.</param>
        public void TransferTab(Guid sourceWindowId, Guid targetWindowId, TabItemModel tab, int targetIndex)
        {
            if (tab == null)
            {
                throw new ArgumentNullException(nameof(tab));
            }

            WindowSession? sourceSession;
            WindowSession? targetSession;

            lock (_syncLock)
            {
                sourceSession = _windows.FirstOrDefault(w => w.WindowId == sourceWindowId);
                targetSession = _windows.FirstOrDefault(w => w.WindowId == targetWindowId);
            }

            if (sourceSession == null || targetSession == null)
            {
                return;
            }

            // Invariant Check: If the donor window is secondary and leaves only Home, it must auto-close.
            // The primary window must never auto-close on transfer.
            bool shouldCloseDonor = sourceSession.CanAutoCloseOnTransfer();

            var donorWindow = sourceSession.WindowInstance as Views.Windows.ShellWindow;
            var targetWindow = targetSession.WindowInstance as Views.Windows.ShellWindow;

            // 1. Remove from source window ViewModel (which automatically synchronizes sourceSession.Tabs)
            if (donorWindow != null)
            {
                ExecuteOnUi(donorWindow, () =>
                {
                    if (Equals(donorWindow.ViewModel.SelectedTab, tab))
                    {
                        int currentIndex = donorWindow.ViewModel.Tabs.IndexOf(tab);
                        int fallbackIndex = Math.Max(0, currentIndex - 1);
                        donorWindow.ViewModel.Tabs.Remove(tab);
                        if (donorWindow.ViewModel.Tabs.Count > 0)
                        {
                            donorWindow.ViewModel.SelectedTab = donorWindow.ViewModel.Tabs[Math.Min(fallbackIndex, donorWindow.ViewModel.Tabs.Count - 1)];
                        }
                    }
                    else
                    {
                        donorWindow.ViewModel.Tabs.Remove(tab);
                    }
                });
            }
            else
            {
                sourceSession.Tabs.Remove(tab);
            }

            // 2. Insert into target window ViewModel (which automatically synchronizes targetSession.Tabs)
            if (targetWindow != null)
            {
                ExecuteOnUi(targetWindow, () =>
                {
                    int insertIndex = Math.Clamp(targetIndex, 0, targetWindow.ViewModel.Tabs.Count);
                    targetWindow.ViewModel.Tabs.Insert(insertIndex, tab);
                    targetWindow.ViewModel.SelectedTab = tab;
                    tab.State = TabLifecycleState.Active;
                    targetWindow.Activate();
                });
            }
            else
            {
                int insertIndex = Math.Clamp(targetIndex, 0, targetSession.Tabs.Count);
                targetSession.Tabs.Insert(insertIndex, tab);
                targetSession.SelectedTab = tab;
                tab.State = TabLifecycleState.Active;
            }

            // 3. Automatically close donor window if invariant is triggered
            if (shouldCloseDonor)
            {
                if (donorWindow != null)
                {
                    ExecuteOnUi(donorWindow, () =>
                    {
                        donorWindow.Close();
                    });
                }
                else
                {
                    sourceSession.WindowInstance?.Close();
                }
            }
        }

        /// <summary>
        /// Executes an action on the UI thread of the target window if required, or immediately if already on the UI thread.
        /// </summary>
        /// <param name="window">The target window hosting the UI thread.</param>
        /// <param name="action">The action to execute.</param>
        private static void ExecuteOnUi(Window? window, Action action)
        {
            if (window?.DispatcherQueue != null)
            {
                if (window.DispatcherQueue.HasThreadAccess)
                {
                    action();
                }
                else
                {
                    window.DispatcherQueue.TryEnqueue(() => action());
                }
            }
            else
            {
                action();
            }
        }
    }
}
