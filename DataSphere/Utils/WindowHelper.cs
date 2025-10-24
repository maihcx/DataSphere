﻿using DataSphere.Views.Windows;

namespace DataSphere.Utils
{
    public static class WindowHelper
    {
        public static ApplicationThemeManagerService? ThemeManagerService;

        public static Window? MainWindow;

        public static ISnackbarService? GlobalSnackbar;

        public static IContentDialogService? ContentDialogService;

        public delegate void AutoHideNavPanelChanged(bool state);
        public static event AutoHideNavPanelChanged? OnAutoHideNavChanged;


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

        [DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

        private const int SW_RESTORE = 9;

        private const int KEYEVENTF_KEYUP = 0x0002;

        private const byte VK_MENU = 0x12;

        public static void BringToFront(Window window)
        {
            if (window == null) return;

            var handle = new WindowInteropHelper(window).Handle;

            ShowWindow(handle, SW_RESTORE);

            IntPtr foreground = GetForegroundWindow();
            uint curThread = GetCurrentThreadId();

            keybd_event(VK_MENU, 0, 0, UIntPtr.Zero);
            keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);

            if (foreground != IntPtr.Zero)
            {
                uint fgThread = GetWindowThreadProcessId(foreground, IntPtr.Zero);
                AttachThreadInput(fgThread, curThread, true);
                SetForegroundWindow(handle);
                AttachThreadInput(fgThread, curThread, false);
            }
            else
            {
                SetForegroundWindow(handle);
            }

            window.Activate();
            window.Focus();
        }

        public static void FocusMainWindow()
        {
            if (Application.Current.MainWindow is MainWindow mw)
            {
                if (!mw.IsVisible)
                {
                    mw.ShowWithEffect();
                }
                else
                {
                    if (mw.WindowState == WindowState.Minimized)
                    {
                        mw.WindowState = WindowState.Normal;
                    }
                    mw.Activate();
                }
                BringToFront(mw);
            }
        }

        public static bool IsAutoHideNavPanel
        {
            get;
            set
            {
                if (field == value) return;

                field = value;
                UserDataStore.SetValue("IsAutoHideNavPanel", field);
                OnAutoHideNavChanged?.Invoke(value);
            }
        } = UserDataStore.GetValue<bool>("IsAutoHideNavPanel");
    }
}
