using Windows.ApplicationModel.DataTransfer;
using Windows.Foundation;
using System.Runtime.InteropServices;
using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media.Animation;
using Microsoft.UI.Xaml.Media.Imaging;
using WinUIEx;
using DataSphere.Controls;
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
        private readonly IThemeService _themeService;
        private WindowSession? _session;
        private Storyboard? _activeTransitionStoryboard;

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
        /// <param name="themeService">The application theme and system backdrop service.</param>
        public ShellWindow(ShellViewModel viewModel, IWindowManager windowManager, IThemeService themeService)
        {
            ViewModel = viewModel ?? throw new ArgumentNullException(nameof(viewModel));
            _windowManager = windowManager ?? throw new ArgumentNullException(nameof(windowManager));
            _themeService = themeService ?? throw new ArgumentNullException(nameof(themeService));

            InitializeComponent();

            ExtendsContentIntoTitleBar = true;
            SetTitleBar(CustomDragRegion);
            CustomDragRegion.MinWidth = 188;
            AppWindow.TitleBar.ButtonBackgroundColor = Colors.Transparent;
            AppWindow.TitleBar.ButtonInactiveBackgroundColor = Colors.Transparent;

            // Apply active theme and system backdrop to this window
            _themeService.ApplyThemeAndBackdrop(this);
            _themeService.ThemeChanged += OnThemeChanged;
            _themeService.BackdropChanged += OnBackdropChanged;

            // Register session
            _session = new WindowSession
            {
                WindowInstance = this,
                IsPrimary = _windowManager.Windows.Count == 0
            };

            // Mirror dynamic tabs from viewmodel into session and keep synchronized
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

            // Deselect dynamic tabs in ShellTabView whenever Home is selected
            ViewModel.PropertyChanged += (s, e) =>
            {
                if (e.PropertyName == nameof(ShellViewModel.IsHomeSelected))
                {
                    if (ViewModel.IsHomeSelected)
                    {
                        ShellTabView.SelectedItem = null;
                        SlidingTabIndicatorBehavior.UpdatePosition(ShellTabView, animate: true);
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
                CancelActiveTransition();
                _themeService.ThemeChanged -= OnThemeChanged;
                _themeService.BackdropChanged -= OnBackdropChanged;
                if (_session != null && _session.IsPrimary)
                {
                    WindowPlacementHelper.SavePlacement(this);
                }
            };

            _windowManager.RegisterWindow(_session);
        }

        /// <summary>
        /// Cancels and cleans up any currently active theme or backdrop transition storyboard and overlay state.
        /// </summary>
        private void CancelActiveTransition()
        {
            if (_activeTransitionStoryboard != null)
            {
                _activeTransitionStoryboard.Stop();
                _activeTransitionStoryboard = null;
            }

            if (ThemeTransitionOverlay != null)
            {
                ThemeTransitionOverlay.Visibility = Visibility.Collapsed;
            }

            if (ThemeTransitionImage != null)
            {
                ThemeTransitionImage.Source = null;
            }
        }

        /// <summary>
        /// Performs a smooth Fluent cross-fade transition between the current visual appearance and the updated theme.
        /// </summary>
        /// <returns>A task representing the asynchronous transition operation.</returns>
        private async Task TransitionThemeAsync()
        {
            if (WindowRoot == null || WindowRoot.ActualWidth <= 0 || WindowRoot.ActualHeight <= 0)
            {
                _themeService.ApplyThemeAndBackdrop(this);
                return;
            }

            try
            {
                CancelActiveTransition();

                // 1. Capture snapshot of the current window visual tree before theme change
                var renderBitmap = new RenderTargetBitmap();
                await renderBitmap.RenderAsync(WindowRoot);

                ThemeTransitionImage.Source = renderBitmap;
                ThemeTransitionOverlay.Opacity = 1.0;
                ThemeTransitionOverlay.Visibility = Visibility.Visible;

                // 2. Apply the new theme (swaps all ThemeResources behind the snapshot overlay)
                _themeService.ApplyThemeAndBackdrop(this);

                // 3. Smoothly fade out the snapshot overlay over 250ms with Fluent CubicEase
                var storyboard = new Storyboard();
                var fadeAnimation = new DoubleAnimation
                {
                    From = 1.0,
                    To = 0.0,
                    Duration = new Duration(TimeSpan.FromMilliseconds(250)),
                    EasingFunction = new CubicEase { EasingMode = EasingMode.EaseInOut }
                };

                Storyboard.SetTarget(fadeAnimation, ThemeTransitionOverlay);
                Storyboard.SetTargetProperty(fadeAnimation, "Opacity");
                storyboard.Children.Add(fadeAnimation);

                storyboard.Completed += (s, e) =>
                {
                    ThemeTransitionOverlay.Visibility = Visibility.Collapsed;
                    ThemeTransitionImage.Source = null;
                    _activeTransitionStoryboard = null;
                };

                _activeTransitionStoryboard = storyboard;
                storyboard.Begin();
            }
            catch (Exception)
            {
                CancelActiveTransition();
                _themeService.ApplyThemeAndBackdrop(this);
            }
        }

        /// <summary>
        /// Performs a smooth Fluent cross-fade transition when updating the active system backdrop material.
        /// </summary>
        /// <returns>A task representing the asynchronous transition operation.</returns>
        private async Task TransitionBackdropAsync()
        {
            if (WindowRoot == null || WindowRoot.ActualWidth <= 0 || WindowRoot.ActualHeight <= 0)
            {
                _themeService.ApplyThemeAndBackdrop(this);
                return;
            }

            try
            {
                CancelActiveTransition();

                // 1. Capture snapshot of current visual tree
                var renderBitmap = new RenderTargetBitmap();
                await renderBitmap.RenderAsync(WindowRoot);

                ThemeTransitionImage.Source = renderBitmap;
                ThemeTransitionOverlay.Opacity = 1.0;
                ThemeTransitionOverlay.Visibility = Visibility.Visible;

                // 2. Apply the updated backdrop material
                _themeService.ApplyThemeAndBackdrop(this);

                // 3. Smoothly fade out the snapshot overlay over 300ms with Fluent CubicEase
                var storyboard = new Storyboard();
                var fadeAnimation = new DoubleAnimation
                {
                    From = 1.0,
                    To = 0.0,
                    Duration = new Duration(TimeSpan.FromMilliseconds(300)),
                    EasingFunction = new CubicEase { EasingMode = EasingMode.EaseInOut }
                };

                Storyboard.SetTarget(fadeAnimation, ThemeTransitionOverlay);
                Storyboard.SetTargetProperty(fadeAnimation, "Opacity");
                storyboard.Children.Add(fadeAnimation);

                storyboard.Completed += (s, e) =>
                {
                    ThemeTransitionOverlay.Visibility = Visibility.Collapsed;
                    ThemeTransitionImage.Source = null;
                    _activeTransitionStoryboard = null;
                };

                _activeTransitionStoryboard = storyboard;
                storyboard.Begin();
            }
            catch (Exception)
            {
                CancelActiveTransition();
                _themeService.ApplyThemeAndBackdrop(this);
            }
        }

        /// <summary>
        /// Handles the ThemeChanged event by initiating a smooth snapshot cross-fade transition.
        /// </summary>
        /// <param name="sender">The event source.</param>
        /// <param name="theme">The new theme string.</param>
        private void OnThemeChanged(object? sender, string theme) => DispatcherQueue?.TryEnqueue(async () => await TransitionThemeAsync());

        /// <summary>
        /// Handles the BackdropChanged event by initiating a smooth snapshot cross-fade transition.
        /// </summary>
        /// <param name="sender">The event source.</param>
        /// <param name="backdrop">The new backdrop material string.</param>
        private void OnBackdropChanged(object? sender, string backdrop) => DispatcherQueue?.TryEnqueue(async () => await TransitionBackdropAsync());

        /// <summary>
        /// Handles the Tapped event on the anchored Home TabViewItem to select Home.
        /// </summary>
        /// <param name="sender">The source of the tapped event.</param>
        /// <param name="e">The tapped event arguments.</param>
        private void OnHomeTabTapped(object sender, TappedRoutedEventArgs e)
        {
            ViewModel.SelectHomeCommand.Execute(null);
            ShellTabView.SelectedItem = null;
            SlidingTabIndicatorBehavior.UpdatePosition(ShellTabView, animate: true);
        }

        /// <summary>
        /// Handles the CloseRequested event on the anchored Home TabViewItem to close the application.
        /// </summary>
        /// <param name="sender">The Home TabViewItem requesting close.</param>
        /// <param name="args">The tab close requested event arguments.</param>
        private void OnHomeTabCloseRequested(TabViewItem sender, TabViewTabCloseRequestedEventArgs args)
        {
            ViewModel.CloseHomeCommand.Execute(null);
        }

        /// <summary>
        /// Handles selection changes on dynamic workspace tabs.
        /// </summary>
        /// <param name="sender">The TabView source.</param>
        /// <param name="e">The selection changed event arguments.</param>
        private void OnTabViewSelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (ShellTabView.SelectedItem is TabItemModel selectedTab && !Equals(ViewModel.SelectedTab, selectedTab))
            {
                ViewModel.SelectedTab = selectedTab;
            }
        }

        /// <summary>
        /// Handles tab close requests on dynamic workspace tabs.
        /// </summary>
        /// <param name="sender">The TabView source.</param>
        /// <param name="args">The tab close requested event arguments.</param>
        private void OnTabCloseRequested(TabView sender, TabViewTabCloseRequestedEventArgs args)
        {
            if (args.Item is TabItemModel tabModel)
            {
                ViewModel.CloseTabCommand.Execute(tabModel);
            }
        }

        /// <summary>
        /// Handles tab drag starting events, preventing anchored Home tabs from being dragged or torn off.
        /// </summary>
        /// <param name="sender">The TabView source.</param>
        /// <param name="args">The drag starting event arguments.</param>
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

        /// <summary>
        /// Handles tab dropped outside events to tear off the tab into a new window.
        /// </summary>
        /// <param name="sender">The TabView source.</param>
        /// <param name="args">The tab dropped outside event arguments.</param>
        private void OnTabDroppedOutside(TabView sender, TabViewTabDroppedOutsideEventArgs args)
        {
            if (args.Item is TabItemModel tabModel && tabModel.IsClosable)
            {
                // Explicitly disconnect the tab's visual content from the donor window's CachedContentControl
                CachedContentControl.DisconnectFromParent(tabModel.Content as UIElement);

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
                    else
                    {
                        ViewModel.SelectHome();
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

        /// <summary>
        /// Handles drag over events across the tab bar area (including the anchored Home tab, title bar drag region,
        /// and TabView host) to enable cross-window tab docking even when zero dynamic tabs exist or when hovering over empty strip space.
        /// </summary>
        /// <param name="sender">The drag event source.</param>
        /// <param name="e">The drag event arguments.</param>
        private void OnTabAreaDragOver(object sender, DragEventArgs e)
        {
            if (e.DataView.Properties.ContainsKey("DataSphereTabPayload"))
            {
                e.AcceptedOperation = DataPackageOperation.Move;
                e.Handled = true;
            }
            else
            {
                e.AcceptedOperation = DataPackageOperation.None;
            }
        }

        /// <summary>
        /// Calculates the insertion index within dynamic tabs based on the drag pointer location.
        /// </summary>
        /// <param name="e">The drag event arguments containing drop coordinates.</param>
        /// <returns>The zero-based insertion index.</returns>
        private int CalculateTabDropIndex(DragEventArgs e)
        {
            if (ViewModel.Tabs.Count == 0)
            {
                return 0;
            }

            Point dropPoint = e.GetPosition(ShellTabView);

            for (int i = 0; i < ViewModel.Tabs.Count; i++)
            {
                if (ShellTabView.ContainerFromIndex(i) is TabViewItem tabItem)
                {
                    var transform = tabItem.TransformToVisual(ShellTabView);
                    var itemBounds = transform.TransformBounds(new Rect(0, 0, tabItem.ActualWidth, tabItem.ActualHeight));
                    double midpointX = itemBounds.X + (itemBounds.Width / 2.0);

                    if (dropPoint.X < midpointX)
                    {
                        return i;
                    }
                }
            }

            return ViewModel.Tabs.Count;
        }

        /// <summary>
        /// Handles drop events across the tab bar area to accept transferred tabs from another window,
        /// inserting at index 0 when dropped on the anchored Home tab, or at the calculated drop index along the dynamic tab strip.
        /// </summary>
        /// <param name="sender">The drag event source.</param>
        /// <param name="e">The drag event arguments.</param>
        private void OnTabAreaDrop(object sender, DragEventArgs e)
        {
            if (e.Handled)
            {
                return;
            }

            if (e.DataView.Properties.TryGetValue("DataSphereTabPayload", out object? rawPayload) &&
                rawPayload is TabDragPayload payload)
            {
                if (_session != null && payload.SourceWindowId != _session.WindowId)
                {
                    int targetIndex = ReferenceEquals(sender, HomeTabItem) ? 0 : CalculateTabDropIndex(e);
                    _windowManager.TransferTab(payload.SourceWindowId, _session.WindowId, payload.Tab, targetIndex);
                    e.Handled = true;
                }
            }
        }

        /// <summary>
        /// Handles tab strip drag over events for inter-window tab transfer.
        /// </summary>
        /// <param name="sender">The TabView source.</param>
        /// <param name="e">The drag event arguments.</param>
        private void OnTabStripDragOver(object sender, DragEventArgs e)
        {
            if (e.DataView.Properties.ContainsKey("DataSphereTabPayload"))
            {
                e.AcceptedOperation = DataPackageOperation.Move;
                e.Handled = true;
            }
            else
            {
                e.AcceptedOperation = DataPackageOperation.None;
            }
        }

        /// <summary>
        /// Handles tab strip drop events to accept transferred tabs from another window.
        /// </summary>
        /// <param name="sender">The TabView source.</param>
        /// <param name="e">The drag event arguments.</param>
        private void OnTabStripDrop(object sender, DragEventArgs e)
        {
            if (e.Handled)
            {
                return;
            }

            if (e.DataView.Properties.TryGetValue("DataSphereTabPayload", out object? rawPayload) &&
                rawPayload is TabDragPayload payload)
            {
                if (_session != null && payload.SourceWindowId != _session.WindowId)
                {
                    int targetIndex = CalculateTabDropIndex(e);
                    _windowManager.TransferTab(payload.SourceWindowId, _session.WindowId, payload.Tab, targetIndex);
                    e.Handled = true;
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
