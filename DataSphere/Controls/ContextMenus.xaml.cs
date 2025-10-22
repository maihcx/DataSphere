using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Controls;

namespace DataSphere.Controls
{
    public partial class ContextMenus : ContextMenu
    {
        public ContextMenus()
        {
            InitializeComponent();
        }

        protected override void OnOpened(RoutedEventArgs e)
        {
            base.OnOpened(e);

            if (PlacementTarget is FrameworkElement parent)
                DataContext = parent.DataContext;
        }

        public ObservableCollection<ContextAction> ItemsSourceBinding
        {
            get => (ObservableCollection<ContextAction>)GetValue(ItemsSourceBindingProperty);
            set => SetValue(ItemsSourceBindingProperty, value);
        }

        public static readonly DependencyProperty ItemsSourceBindingProperty =
            DependencyProperty.Register(
                nameof(ItemsSourceBinding),
                typeof(ObservableCollection<ContextAction>),
                typeof(ContextMenus),
                new PropertyMetadata(null, OnItemsSourceChanged));

        private static void OnItemsSourceChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is ContextMenus menu)
            {
                menu.ItemsSource = e.NewValue as ObservableCollection<ContextAction>;
            }
        }
    }
}
