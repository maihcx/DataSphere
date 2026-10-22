# Contract: DatabasePage Inner TabView & TabStripHeader XAML Contract

**Feature**: `014-database-tabstrip-header`
**Spec**: [spec.md](../spec.md)
**Model**: [data-model.md](../data-model.md)

---

## 1. XAML View Layout Contract (`DatabasePage.xaml`)

```xml
<Page x:Class="DataSphere.Views.Pages.DatabaseGroup.DatabasePage"
      xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
      xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
      xmlns:models="using:DataSphere.Models"
      xmlns:vm="using:DataSphere.ViewModels.Pages.DatabaseGroup"
      Background="Transparent"
      mc:Ignorable="d">

    <Grid Background="Transparent">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
        </Grid.RowDefinitions>

        <!-- Inner Tab Workspace with unified background matching tab surface -->
        <Grid Grid.Row="1"
              Background="{ThemeResource LayerFillColorDefaultBrush}">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto" />
                <RowDefinition Height="*" />
            </Grid.RowDefinitions>

            <TabView Grid.Row="0"
                     x:Name="InnerTabView"
                     Background="Transparent"
                     BorderThickness="0"
                     TabItemsSource="{x:Bind ViewModel.InnerTabs, Mode=OneWay}"
                     SelectedItem="{x:Bind ViewModel.SelectedInnerTab, Mode=TwoWay}"
                     TabWidthMode="Compact"
                     SelectionChanged="InnerTabView_SelectionChanged"
                     TabCloseRequested="InnerTabView_TabCloseRequested"
                     IsAddTabButtonVisible="False"
                     CanReorderTabs="True"
                     CanDragTabs="False"
                     HorizontalAlignment="Stretch">

                <!-- Anchored Connection Tab in TabStripHeader -->
                <TabView.TabStripHeader>
                    <StackPanel Orientation="Horizontal"
                                VerticalAlignment="Top"
                                Margin="0,3,4,3">
                        <TabViewItem x:Name="ConnectionTabItem"
                                     Style="{StaticResource PillTabViewItemStyle}"
                                     Header="{x:Bind ViewModel.ConnectionTab.Header, Mode=OneWay}"
                                     IsClosable="{x:Bind ViewModel.ConnectionTab.IsClosable, Mode=OneWay}"
                                     IsSelected="{x:Bind ViewModel.IsConnectionSelected, Mode=TwoWay}"
                                     Tapped="OnConnectionTabTapped">
                            <TabViewItem.IconSource>
                                <FontIconSource Glyph="{x:Bind ViewModel.ConnectionTab.IconGlyph, Mode=OneWay}" />
                            </TabViewItem.IconSource>
                        </TabViewItem>
                    </StackPanel>
                </TabView.TabStripHeader>

                <!-- Dynamic Workspace Tabs Template -->
                <TabView.TabItemTemplate>
                    <DataTemplate x:DataType="models:InnerTabItemModel">
                        <TabViewItem Style="{StaticResource PillTabViewItemStyle}"
                                     Header="{x:Bind Header, Mode=OneWay}"
                                     IsClosable="{x:Bind IsClosable, Mode=OneWay}">
                            <TabViewItem.IconSource>
                                <FontIconSource Glyph="{x:Bind IconGlyph, Mode=OneWay}" />
                            </TabViewItem.IconSource>
                        </TabViewItem>
                    </DataTemplate>
                </TabView.TabItemTemplate>
            </TabView>

            <!-- Active Tab Content Area (Unified Viewport) -->
            <ContentControl Grid.Row="1"
                            Background="Transparent"
                            Content="{x:Bind ViewModel.ActiveInnerContent, Mode=OneWay}"
                            HorizontalContentAlignment="Stretch"
                            VerticalContentAlignment="Stretch" />
        </Grid>
    </Grid>
</Page>
```

---

## 2. Code-Behind Plumbing Contract (`DatabasePage.xaml.cs`)

```csharp
namespace DataSphere.Views.Pages.DatabaseGroup
{
    public sealed partial class DatabasePage : Page
    {
        public DatabaseViewModel ViewModel { get; }

        public DatabasePage(DatabaseViewModel viewModel)
        {
            ViewModel = viewModel ?? throw new ArgumentNullException(nameof(viewModel));
            InitializeComponent();

            // Synchronize selection: deselect dynamic tabs when Connection tab is selected
            ViewModel.PropertyChanged += (s, e) =>
            {
                if (e.PropertyName == nameof(DatabaseViewModel.IsConnectionSelected) && ViewModel.IsConnectionSelected)
                {
                    InnerTabView.SelectedItem = null;
                }
            };
        }

        private void OnConnectionTabTapped(object sender, TappedRoutedEventArgs e)
        {
            ViewModel.SelectConnectionCommand.Execute(null);
            InnerTabView.SelectedItem = null;
        }

        private void InnerTabView_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (InnerTabView.SelectedItem is InnerTabItemModel selected && !Equals(ViewModel.SelectedInnerTab, selected))
            {
                ViewModel.SelectedInnerTab = selected;
            }
        }

        private void InnerTabView_TabCloseRequested(TabView sender, TabViewTabCloseRequestedEventArgs args)
        {
            if (args.Item is InnerTabItemModel tab)
            {
                ViewModel.CloseTab(tab);
            }
        }
    }
}
```

---

## 3. Localization Keys Contract

| Resource Key | English Value (`String.en.resx`) | Vietnamese Value (`String.vi.resx`) |
|---|---|---|
| `tab_connections_header` | Connections | Kết nối |
| `database_tab_title` | Database | Cơ sở dữ liệu |
