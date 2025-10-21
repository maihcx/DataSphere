namespace DataSphere.Helpers
{
    public static class TextBoxExtensions
    {
        // --- AutoScroll ---
        public static readonly DependencyProperty AutoScrollProperty =
            DependencyProperty.RegisterAttached(
                "AutoScroll",
                typeof(bool),
                typeof(TextBoxExtensions),
                new PropertyMetadata(false, OnAutoScrollChanged));

        public static bool GetAutoScroll(DependencyObject obj) =>
            (bool)obj.GetValue(AutoScrollProperty);

        public static void SetAutoScroll(DependencyObject obj, bool value) =>
            obj.SetValue(AutoScrollProperty, value);

        private static readonly TextChangedEventHandler AutoScrollHandler =
            (s, e) => { 
                if (s is Wpf.Ui.Controls.TextBox textBox)
                {
                    textBox.ScrollToEnd();
                }
                else if (s is System.Windows.Controls.TextBox textBoxW)
                {
                    textBoxW.ScrollToEnd();
                }
            };

        private static void OnAutoScrollChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is Wpf.Ui.Controls.TextBox textBox)
            {
                if ((bool)e.NewValue)
                    textBox.TextChanged += AutoScrollHandler;
                else
                    textBox.TextChanged -= AutoScrollHandler;
            }
            else if (d is System.Windows.Controls.TextBox textBoxW)
            {
                if ((bool)e.NewValue)
                    textBoxW.TextChanged += AutoScrollHandler;
                else
                    textBoxW.TextChanged -= AutoScrollHandler;
            }
        }

        // --- Input Block ---
        public static readonly DependencyProperty IsInputBlockedProperty =
            DependencyProperty.RegisterAttached(
                "IsInputBlocked",
                typeof(bool),
                typeof(TextBoxExtensions),
                new PropertyMetadata(false, OnIsInputBlockedChanged));

        public static bool GetIsInputBlocked(DependencyObject obj) =>
            (bool)obj.GetValue(IsInputBlockedProperty);

        public static void SetIsInputBlocked(DependencyObject obj, bool value) =>
            obj.SetValue(IsInputBlockedProperty, value);

        private static void OnIsInputBlockedChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is Wpf.Ui.Controls.TextBox textBox)
            {
                if ((bool)e.NewValue)
                {
                    textBox.PreviewTextInput += BlockInput;
                    textBox.PreviewKeyDown += BlockKey;
                }
                else
                {
                    textBox.PreviewTextInput -= BlockInput;
                    textBox.PreviewKeyDown -= BlockKey;
                }
            }
            else if (d is System.Windows.Controls.TextBox textBoxW)
            {
                if ((bool)e.NewValue)
                {
                    textBoxW.PreviewTextInput += BlockInput;
                    textBoxW.PreviewKeyDown += BlockKey;
                }
                else
                {
                    textBoxW.PreviewTextInput -= BlockInput;
                    textBoxW.PreviewKeyDown -= BlockKey;
                }
            }
        }

        private static void BlockInput(object sender, TextCompositionEventArgs e) => e.Handled = true;

        private static void BlockKey(object sender, KeyEventArgs e)
        {
            // Cho phép các phím: Ctrl+C, Ctrl+A, điều hướng
            bool allowed =
                (e.Key == Key.C && Keyboard.Modifiers == ModifierKeys.Control) ||
                (e.Key == Key.A && Keyboard.Modifiers == ModifierKeys.Control) ||
                (e.Key == Key.Left || e.Key == Key.Right || e.Key == Key.Up || e.Key == Key.Down ||
                 e.Key == Key.PageUp || e.Key == Key.PageDown || e.Key == Key.Home || e.Key == Key.End);

            if (!allowed)
                e.Handled = true;
        }
    }
}
