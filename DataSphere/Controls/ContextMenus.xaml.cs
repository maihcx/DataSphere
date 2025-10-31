using System.Collections.ObjectModel;
using System.Reflection.Metadata;
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

        public static readonly DependencyProperty ItemsSourceBindingProperty =
            DependencyProperty.Register(
                nameof(ItemsSourceBinding),
                typeof(ObservableCollection<ContextAction>),
                typeof(ContextMenus),
                new PropertyMetadata(null, OnItemsSourceChanged));

        public static readonly DependencyProperty ParameterProperty =
            DependencyProperty.Register(
                nameof(Parameter), 
                typeof(object), 
                typeof(ContextMenus), 
                new PropertyMetadata(null));

        public ObservableCollection<ContextAction> ItemsSourceBinding
        {
            get => (ObservableCollection<ContextAction>)GetValue(ItemsSourceBindingProperty);
            set => SetValue(ItemsSourceBindingProperty, value);
        }

        public object Parameter
        {
            get => GetValue(ParameterProperty);
            set => SetValue(ParameterProperty, value);
        }

        private static void OnItemsSourceChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is ContextMenus menu)
            {
                menu.ItemsSource = e.NewValue as ObservableCollection<ContextAction>;
            }
        }
    }
}
