using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;

namespace DataSphere.Controls
{
    /// <summary>
    /// Interaction logic for TabControl.xaml
    /// </summary>
    public partial class TabsControl : TabControl
    {
        public TabsControl()
        {
            InitializeComponent();
        }

        public ObservableCollection<Models.TabItemView> ItemsSourceBinding
        {
            get => (ObservableCollection<Models.TabItemView>)GetValue(ItemsSourceBindingProperty);
            set => SetValue(ItemsSourceBindingProperty, value);
        }

        public static readonly DependencyProperty ItemsSourceBindingProperty =
            DependencyProperty.Register(
                nameof(ItemsSourceBinding),
                typeof(ObservableCollection<Models.TabItemView>),
                typeof(TabsControl),
                new PropertyMetadata(null, OnItemsSourceChanged));

        private static void OnItemsSourceChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        {
            if (d is TabsControl control)
            {
                control.ItemsSource = e.NewValue as ObservableCollection<Models.TabItemView>;
            }
        }

        private void CloseTabButton_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Wpf.Ui.Controls.Button btn && btn.DataContext is TabItemView tab)
            {
                if (ItemsSourceBinding != null && ItemsSourceBinding.Contains(tab))
                {
                    CloseTab(tab);
                }
            }
        }

        private void CloseTab(TabItemView tab)
        {
            if (tab.Content is IDisposable page) {
                page.Dispose();
            }
            ItemsSourceBinding.Remove(tab);
        }
    }
}
