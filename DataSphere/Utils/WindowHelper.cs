using System.Runtime.InteropServices;
using Microsoft.UI.Xaml;
using WinUIEx;

namespace DataSphere.Utils
{
    /// <summary>
    /// Helper utilities for native window activation, focus management, and foreground window coordination.
    /// </summary>
    public static class WindowHelper
    {
        [DllImport("user32.dll")]
        private static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("user32.dll")]
        private static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);

        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr processId);

        [DllImport("kernel32.dll")]
        private static extern uint GetCurrentThreadId();

        /// <summary>
        /// Retrieves a handle to the foreground window (the window with which the user is currently working).
        /// </summary>
        /// <returns>The handle to the foreground window, or IntPtr.Zero if none.</returns>
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

        private const int SW_RESTORE = 9;
        private const int KEYEVENTF_KEYUP = 0x0002;
        private const byte VK_MENU = 0x12;

        /// <summary>
        /// Restores and forcefully brings the specified native window to the foreground.
        /// </summary>
        /// <param name="window">The window instance to bring to the front.</param>
        public static void BringToFront(Window? window)
        {
            if (window == null)
            {
                return;
            }

            IntPtr handle = window.GetWindowHandle();
            if (handle == IntPtr.Zero)
            {
                return;
            }

            ShowWindow(handle, SW_RESTORE);

            IntPtr foreground = GetForegroundWindow();
            uint curThread = GetCurrentThreadId();

            keybd_event(VK_MENU, 0, 0, UIntPtr.Zero);
            keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);

            if (foreground != IntPtr.Zero)
            {
                uint fgThread = GetWindowThreadProcessId(foreground, IntPtr.Zero);
                if (fgThread != curThread)
                {
                    AttachThreadInput(curThread, fgThread, true);
                    SetForegroundWindow(handle);
                    AttachThreadInput(curThread, fgThread, false);
                    return;
                }
            }

            SetForegroundWindow(handle);
        }
    }
}
