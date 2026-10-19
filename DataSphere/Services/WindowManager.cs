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
                }
            }

            if (session.WindowInstance != null)
            {
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

            var session = new WindowSession
            {
                WindowInstance = newWindow,
                IsPrimary = false
            };

            // Register session
            RegisterWindow(session);

            if (newWindow != null)
            {
                // Position window at target coordinates
                newWindow.AppWindow.Move(new Windows.Graphics.PointInt32((int)screenPosition.X, (int)screenPosition.Y));

                // Add the torn-off tab to the new window's tab service or session
                if (newWindow is Views.Windows.ShellWindow sw)
                {
                    sw.ViewModel.TabService.Tabs.Add(tab);
                    sw.ViewModel.TabService.SelectedTab = tab;
                    tab.State = TabLifecycleState.Active;
                }
                else if (newWindow.Content is FrameworkElement fe && fe.DataContext is ViewModels.Windows.ShellViewModel vm)
                {
                    vm.TabService.Tabs.Add(tab);
                    vm.TabService.SelectedTab = tab;
                    tab.State = TabLifecycleState.Active;
                }
                else
                {
                    session.AddTab(tab);
                }

                newWindow.Activate();
            }

            return session;
        }

        /// <summary>
        /// Transfers a tab from a donor window to a target window at a specific index.
        /// Enforces the donor window auto-closure rule if the donor window has only two tabs (Home + ContentTab).
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

            // Invariant Check: If the donor window has only 2 tabs (Home + ContentTab),
            // moving the ContentTab leaves only Home, so the donor window must close.
            bool shouldCloseDonor = sourceSession.CanAutoCloseOnTransfer();

            // Remove from source
            sourceSession.Tabs.Remove(tab);

            // Insert into target
            int insertIndex = Math.Clamp(targetIndex, 0, targetSession.Tabs.Count);
            targetSession.Tabs.Insert(insertIndex, tab);
            targetSession.SelectedTab = tab;
            tab.State = TabLifecycleState.Active;

            // Automatically close donor window if invariant is triggered
            if (shouldCloseDonor)
            {
                sourceSession.WindowInstance?.Close();
            }
        }
    }
}
