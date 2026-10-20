using Windows.ApplicationModel.DataTransfer;
using Windows.Foundation;
using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using WinUIEx;
using DataSphere.Models;
using DataSphere.Services.Contracts;
using DataSphere.Utils;
using DataSphere.ViewModels.Windows;
using DataSphere.Views.Pages;

namespace DataSphere.Views.Windows
{
    /// <summary>
    /// Top-level application shell window hosting the browser-style tab strip and active viewports.
    /// </summary>
    public sealed partial class ShellWindow : WindowEx
    {
        private readonly IWindowManager _windowManager;
        private WindowSession? _session;

        /// <summary>
        /// Gets the Presentation ViewModel coordinating this shell window.
        /// </summary>
        public ShellViewModel ViewModel { get; }

        /// <summary>
        /// Gets the active window session tracking this window instance.
        /// </summary>
        public WindowSession? Session => _session;

        /// <summary>
        /// Initializes a new instance of the <see cref="ShellWindow"/> class.
        /// </summary>
        /// <param name="viewModel">The shell view model.</param>
        /// <param name="windowManager">The application window manager service.</param>
        public ShellWindow(ShellViewModel viewModel, IWindowManager windowManager)
        {
            ViewModel = viewModel ?? throw new ArgumentNullException(nameof(viewModel));
            _windowManager = windowManager ?? throw new ArgumentNullException(nameof(windowManager));

            InitializeComponent();

            ExtendsContentIntoTitleBar = true;
            SetTitleBar(CustomDragRegion);
            CustomDragRegion.MinWidth = 188;
            AppWindow.TitleBar.ButtonBackgroundColor = Colors.Transparent;
            AppWindow.TitleBar.ButtonInactiveBackgroundColor = Colors.Transparent;

            // Register session
            _session = new WindowSession
            {
                WindowInstance = this,
                IsPrimary = _windowManager.Windows.Count == 0
            };

            // Mirror tabs from viewmodel into session and keep synchronized
            foreach (var tab in ViewModel.Tabs)
            {
                _session.Tabs.Add(tab);
            }

            ViewModel.Tabs.CollectionChanged += (s, e) =>
            {
                if (e.NewItems != null)
                {
                    foreach (TabItemModel tab in e.NewItems)
                    {
                        if (!_session.Tabs.Contains(tab))
                        {
                            _session.Tabs.Add(tab);
                        }
                    }
                }

                if (e.OldItems != null)
                {
                    foreach (TabItemModel tab in e.OldItems)
                    {
                        _session.Tabs.Remove(tab);
                    }
                }
            };

            ViewModel.RequestCloseWindow += (s, e) =>
            {
                Close();
            };

            if (_session.IsPrimary)
            {
                WindowPlacementHelper.RestorePlacement(this);
            }

            AppWindow.Closing += (sender, args) =>
            {
                if (_session != null && _session.IsPrimary)
                {
                    WindowPlacementHelper.SavePlacement(this);
                }
            };

            Closed += (sender, args) =>
            {
                if (_session != null && _session.IsPrimary)
                {
                    WindowPlacementHelper.SavePlacement(this);
                }
            };

            _windowManager.RegisterWindow(_session);
        }

        private void OnTabViewSelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (ShellTabView.SelectedItem is TabItemModel selectedTab && !Equals(ViewModel.SelectedTab, selectedTab))
            {
                ViewModel.SelectedTab = selectedTab;
            }
        }

        private void OnTabCloseRequested(TabView sender, TabViewTabCloseRequestedEventArgs args)
        {
            if (args.Item is TabItemModel tabModel)
            {
                ViewModel.CloseTabCommand.Execute(tabModel);
            }
        }

        private void OnTabDragStarting(TabView sender, TabViewTabDragStartingEventArgs args)
        {
            if (args.Item is TabItemModel tabModel)
            {
                // Invariant: Anchored Home tab cannot be dragged or torn off
                if (tabModel.PageType == typeof(HomePage) || !tabModel.IsClosable)
                {
                    args.Cancel = true;
                    return;
                }

                int index = ViewModel.Tabs.IndexOf(tabModel);
                var payload = new TabDragPayload
                {
                    SourceWindowId = _session?.WindowId ?? Guid.Empty,
                    TabId = tabModel.Id,
                    Tab = tabModel,
                    SourceIndex = index
                };

                args.Data.Properties.Add("DataSphereTabPayload", payload);
                args.Data.RequestedOperation = DataPackageOperation.Move;
            }
        }

        private void OnTabDroppedOutside(TabView sender, TabViewTabDroppedOutsideEventArgs args)
        {
            if (args.Item is TabItemModel tabModel && tabModel.IsClosable)
            {
                // Switch active selection if the torn-off tab is currently selected
                if (Equals(ViewModel.SelectedTab, tabModel))
                {
                    int index = ViewModel.Tabs.IndexOf(tabModel);
                    int fallbackIndex = Math.Max(0, index - 1);
                    ViewModel.Tabs.Remove(tabModel);
                    if (ViewModel.Tabs.Count > 0)
                    {
                        ViewModel.SelectedTab = ViewModel.Tabs[Math.Min(fallbackIndex, ViewModel.Tabs.Count - 1)];
                    }
                }
                else
                {
                    // Remove tab from current window (automatically synchronizes _session.Tabs)
                    ViewModel.Tabs.Remove(tabModel);
                }

                // Get cursor position on screen
                var cursorPos = SimpleCursorPosition.GetCursorPos();
                var screenPoint = new Point(cursorPos.X, cursorPos.Y);

                // Tear off into new window while leaving donor window open
                _windowManager.TearOffTabToNewWindow(tabModel, screenPoint);
            }
        }

        private void OnTabStripDragOver(object sender, DragEventArgs e)
        {
            if (e.DataView.Properties.ContainsKey("DataSphereTabPayload"))
            {
                e.AcceptedOperation = DataPackageOperation.Move;
            }
            else
            {
                e.AcceptedOperation = DataPackageOperation.None;
            }
        }

        private void OnTabStripDrop(object sender, DragEventArgs e)
        {
            if (e.DataView.Properties.TryGetValue("DataSphereTabPayload", out object? rawPayload) &&
                rawPayload is TabDragPayload payload)
            {
                if (_session != null && payload.SourceWindowId != _session.WindowId)
                {
                    // Calculate drop index or append
                    int targetIndex = ViewModel.Tabs.Count;
                    _windowManager.TransferTab(payload.SourceWindowId, _session.WindowId, payload.Tab, targetIndex);
                }
            }
        }
    }

    /// <summary>
    /// Helper to retrieve the current cursor screen position via Win32 API.
    /// </summary>
    internal static class SimpleCursorPosition
    {
        /// <summary>
        /// Win32 POINT structure representing X and Y screen coordinates.
        /// </summary>
        [StructLayout(LayoutKind.Sequential)]
        internal struct POINT
        {
            /// <summary>
            /// The X coordinate on the screen.
            /// </summary>
            public int X;

            /// <summary>
            /// The Y coordinate on the screen.
            /// </summary>
            public int Y;
        }

        [DllImport("user32.dll")]
        private static extern bool GetCursorPos(out POINT lpPoint);

        /// <summary>
        /// Retrieves the current cursor position in screen coordinates.
        /// </summary>
        /// <returns>A tuple containing the X and Y coordinates.</returns>
        public static (int X, int Y) GetCursorPos()
        {
            if (GetCursorPos(out POINT point))
            {
                return (point.X, point.Y);
            }
            return (100, 100);
        }
    }
}
