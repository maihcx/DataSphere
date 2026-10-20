using System;
using System.Runtime.InteropServices;
using Windows.Graphics;
using Microsoft.UI.Windowing;
using WinUIEx;
using DataSphere.Models;

namespace DataSphere.Utils
{
    /// <summary>
    /// Helper utility for persisting and restoring top-level window layout, dimensions, and presentation state.
    /// </summary>
    public static class WindowPlacementHelper
    {
        private const string KeyStartupCode = "StartUpCode";
        private const string KeyLeft = "Window_Left";
        private const string KeyTop = "Window_Top";
        private const string KeyWidth = "Window_Width";
        private const string KeyHeight = "Window_Height";
        private const string KeyMaximized = "IsWindow_Maximized";
        private const string ValidStartupCode = "xv2";

        [StructLayout(LayoutKind.Sequential)]
        private struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        [DllImport("user32.dll")]
        private static extern IntPtr MonitorFromRect(ref RECT lprc, uint dwFlags);

        [DllImport("user32.dll")]
        private static extern int GetSystemMetrics(int nIndex);

        private const uint MONITOR_DEFAULTTONULL = 0;
        private const int SM_CXSCREEN = 0;
        private const int SM_CYSCREEN = 1;

        /// <summary>
        /// Saves the position, size, and presentation state of the specified window to UserDataStore.
        /// </summary>
        /// <param name="window">The window instance whose placement should be recorded.</param>
        public static void SavePlacement(WindowEx window)
        {
            if (window?.AppWindow == null)
            {
                return;
            }

            try
            {
                var presenter = window.AppWindow.Presenter as OverlappedPresenter;
                bool isMaximized = presenter?.State == OverlappedPresenterState.Maximized;

                UserDataStore.SetValue(KeyMaximized, isMaximized);

                // Only record size and position when not maximized to preserve normal restore bounds
                if (!isMaximized)
                {
                    var pos = window.AppWindow.Position;
                    var size = window.AppWindow.Size;

                    if (size.Width >= WindowPlacementState.MinimumWidth && size.Height >= WindowPlacementState.MinimumHeight)
                    {
                        UserDataStore.SetValue(KeyLeft, (double)pos.X);
                        UserDataStore.SetValue(KeyTop, (double)pos.Y);
                        UserDataStore.SetValue(KeyWidth, (double)size.Width);
                        UserDataStore.SetValue(KeyHeight, (double)size.Height);
                        UserDataStore.SetValue(KeyStartupCode, ValidStartupCode);
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[WindowPlacementHelper] Failed to save placement: {ex.Message}");
            }
        }

        /// <summary>
        /// Restores saved placement coordinates or maximized presentation state to the specified window.
        /// </summary>
        /// <param name="window">The window instance to restore.</param>
        public static void RestorePlacement(WindowEx window)
        {
            if (window?.AppWindow == null)
            {
                return;
            }

            try
            {
                var startupCode = UserDataStore.GetValue<string>(KeyStartupCode);
                var isMaximized = UserDataStore.GetValue<bool>(KeyMaximized);

                double width = UserDataStore.GetValue<double>(KeyWidth);
                double height = UserDataStore.GetValue<double>(KeyHeight);
                double left = UserDataStore.GetValue<double>(KeyLeft);
                double top = UserDataStore.GetValue<double>(KeyTop);

                // Use default dimensions if invalid or uninitialized
                if (width < WindowPlacementState.MinimumWidth || height < WindowPlacementState.MinimumHeight)
                {
                    width = 1280.0;
                    height = 800.0;
                }

                int intLeft = (int)left;
                int intTop = (int)top;
                int intWidth = (int)width;
                int intHeight = (int)height;

                // Validate if saved rectangle intersects any connected monitor
                RECT rect = new RECT
                {
                    Left = intLeft,
                    Top = intTop,
                    Right = intLeft + intWidth,
                    Bottom = intTop + intHeight
                };

                IntPtr hMonitor = MonitorFromRect(ref rect, MONITOR_DEFAULTTONULL);
                if (hMonitor == IntPtr.Zero || string.IsNullOrWhiteSpace(startupCode))
                {
                    // Fall back to centering on primary monitor
                    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
                    int screenHeight = GetSystemMetrics(SM_CYSCREEN);

                    intLeft = Math.Max(0, (screenWidth - intWidth) / 2);
                    intTop = Math.Max(0, (screenHeight - intHeight) / 2);
                }

                window.AppWindow.MoveAndResize(new RectInt32(intLeft, intTop, intWidth, intHeight));

                if (isMaximized)
                {
                    var presenter = window.AppWindow.Presenter as OverlappedPresenter;
                    presenter?.Maximize();
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[WindowPlacementHelper] Failed to restore placement: {ex.Message}");
            }
        }
    }
}
