namespace DataSphere.Helpers
{
    public static class TreeViewHelper
    {
        public static readonly DependencyProperty SelectedItemProperty =
            DependencyProperty.RegisterAttached(
                "SelectedItem",
                typeof(object),
                typeof(TreeViewHelper),
                new FrameworkPropertyMetadata(null, FrameworkPropertyMetadataOptions.BindsTwoWayByDefault, OnSelectedItemChanged));

        public static object GetSelectedItem(DependencyObject obj) =>
            obj.GetValue(SelectedItemProperty);

        public static void SetSelectedItem(DependencyObject obj, object value) =>
            obj.SetValue(SelectedItemProperty, value);

        private static void OnSelectedItemChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is TreeView treeView)
            {
                treeView.SelectedItemChanged -= TreeView_SelectedItemChanged;
                treeView.SelectedItemChanged += TreeView_SelectedItemChanged;
            }
        }

        private static void TreeView_SelectedItemChanged(object sender, RoutedPropertyChangedEventArgs<object> e)
        {
            if (sender is TreeView treeView)
            {
                SetSelectedItem(treeView, e.NewValue);
            }
        }
    }
}
