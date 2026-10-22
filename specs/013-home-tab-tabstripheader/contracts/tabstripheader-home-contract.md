# Interface & Layout Contracts: Home Tab in TabStripHeader and Unified Tab Styling

**Branch**: `013-home-tab-tabstripheader`
**Date**: 2026-10-22
**Spec**: [spec.md](./spec.md)

---

## 1. ShellWindow Header & TabView Layout Contract

```xml
<!-- ShellWindow.xaml: TabView header region -->
<TabView x:Name="ShellTabView"
         Grid.Row="0"
         Background="Transparent"
         BorderThickness="0"
         CanDragTabs="True"
         CanReorderTabs="True"
         TabItemsSource="{x:Bind ViewModel.Tabs, Mode=OneWay}"
         SelectedItem="{x:Bind ViewModel.SelectedTab, Mode=TwoWay}"
         TabWidthMode="Compact"
         SelectionChanged="OnTabViewSelectionChanged"
         TabCloseRequested="OnTabCloseRequested"
         TabDragStarting="OnTabDragStarting">

    <!-- TabStripHeader: Anchored Home Tab + Titlebar Left Drag Grip -->
    <TabView.TabStripHeader>
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <!-- Left drag region to grab window by top-left -->
            <Grid x:Name="CustomDragRegionLeft"
                  Background="Transparent"
                  Width="8"
                  Height="34" />

            <!-- Anchored Home TabItem -->
            <TabViewItem x:Name="HomeTabItem"
                         Style="{StaticResource PillTabViewItemStyle}"
                         Header="{x:Bind ViewModel.HomeTab.Title, Mode=OneWay}"
                         IsClosable="{x:Bind ViewModel.HomeTab.IsClosable, Mode=OneWay}"
                         IsSelected="{x:Bind ViewModel.IsHomeSelected, Mode=TwoWay}"
                         Tapped="OnHomeTabTapped"
                         CloseRequested="OnHomeTabCloseRequested">
                <TabViewItem.IconSource>
                    <FontIconSource Glyph="{x:Bind ViewModel.HomeTab.IconGlyph, Mode=OneWay}" />
                </TabViewItem.IconSource>
            </TabViewItem>
        </StackPanel>
    </TabView.TabStripHeader>

    <!-- TabStripFooter: Right titlebar drag region -->
    <TabView.TabStripFooter>
        <Grid x:Name="CustomDragRegion"
              Background="Transparent"
              HorizontalAlignment="Stretch"
              VerticalAlignment="Stretch"
              MinWidth="188" />
    </TabView.TabStripFooter>

    <!-- TabItemTemplate for dynamic tabs -->
    <TabView.TabItemTemplate>
        <DataTemplate x:DataType="models:TabItemModel">
            <TabViewItem Style="{StaticResource PillTabViewItemStyle}"
                         Header="{x:Bind Title, Mode=OneWay}"
                         IsClosable="{x:Bind IsClosable, Mode=OneWay}">
                <TabViewItem.IconSource>
                    <FontIconSource Glyph="{x:Bind IconGlyph, Mode=OneWay}" />
                </TabViewItem.IconSource>
            </TabViewItem>
        </DataTemplate>
    </TabView.TabItemTemplate>
</TabView>

<!-- Decoupled Central Viewport in Grid Row 1 -->
<ContentPresenter Grid.Row="1"
                  Background="Transparent"
                  Content="{x:Bind ViewModel.ActiveViewportContent, Mode=OneWay}"
                  HorizontalAlignment="Stretch"
                  VerticalAlignment="Stretch" />
```

---

## 2. ShellViewModel API Contract

```csharp
namespace DataSphere.ViewModels.Windows
{
    public partial class ShellViewModel : ObservableObject
    {
        /// <summary>
        /// Dedicated singleton TabItemModel representing the permanently anchored Home tab.
        /// </summary>
        public TabItemModel HomeTab { get; }

        /// <summary>
        /// Gets or sets a value indicating whether the Home tab is currently active.
        /// </summary>
        [ObservableProperty]
        [NotifyPropertyChangedFor(nameof(ActiveViewportContent))]
        public partial bool IsHomeSelected { get; set; }

        /// <summary>
        /// Observable collection of dynamic workspace tabs (excluding the Home tab).
        /// </summary>
        public ObservableCollection<TabItemModel> Tabs { get; }

        /// <summary>
        /// Gets or sets the active dynamic tab. Null when Home is selected.
        /// </summary>
        public TabItemModel? SelectedTab { get; set; }

        /// <summary>
        /// Resolves the content to display in the main viewport: Home content when IsHomeSelected is true; otherwise SelectedTab.Content.
        /// </summary>
        public object? ActiveViewportContent => IsHomeSelected ? HomeTab.Content : SelectedTab?.Content;

        /// <summary>
        /// Selects the Home tab, switching the active viewport and clearing dynamic tab selection.
        /// </summary>
        [RelayCommand]
        public void SelectHome();

        /// <summary>
        /// Closes the Home tab. Only permitted when Tabs.Count == 0; triggers RequestCloseWindow.
        /// </summary>
        [RelayCommand]
        public void CloseHome();

        /// <summary>
        /// Closes the specified dynamic tab. If no dynamic tabs remain, falls back to Home.
        /// </summary>
        [RelayCommand]
        public void CloseTab(TabItemModel? tab);

        /// <summary>
        /// Occurs when closing the Home tab as the sole remaining tab requests closing the window and session.
        /// </summary>
        public event EventHandler? RequestCloseWindow;
    }
}
```

---

## 3. Themes/TabStyles.xaml Resource Dictionary Contract

```xml
<ResourceDictionary
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">

    <!-- Reusable Borderless TabView Tokens -->
    <Thickness x:Key="TabViewBorderThickness">0</Thickness>
    <SolidColorBrush x:Key="TabViewBorderBrush" Color="Transparent" />
    <Thickness x:Key="TabViewTabStripBorderThickness">0</Thickness>
    <SolidColorBrush x:Key="TabViewItemStroke" Color="Transparent" />
    <SolidColorBrush x:Key="TabViewItemSeparator" Color="Transparent" />
    <Thickness x:Key="TabViewItemBorderThickness">0</Thickness>
    <Thickness x:Key="TabViewSelectedItemBorderThickness">1</Thickness>
    <Thickness x:Key="TabViewSelectedItemHeaderMargin">0</Thickness>
    <CornerRadius x:Key="TabViewItemCornerRadius">8</CornerRadius>
    <CornerRadius x:Key="OverlayCornerRadius">8</CornerRadius>
    <x:Double x:Key="TabViewItemHeaderMinHeight">34</x:Double>

    <!-- PillTabViewItemStyle: Universal pill capsule style -->
    <Style x:Key="PillTabViewItemStyle" TargetType="TabViewItem">
        <!-- Template with rounded capsule border, Icon, Header, and CloseButton -->
    </Style>
</ResourceDictionary>
```

---

## 4. DatabasePage Inner Workspace Contract

```xml
<!-- DatabasePage.xaml: Uniform background container -->
<Grid Grid.Row="1"
      Background="{ThemeResource LayerFillColorDefaultBrush}">
    <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
        <RowDefinition Height="*" />
    </Grid.RowDefinitions>

    <!-- InnerTabView styled with PillTabViewItemStyle -->
    <TabView Grid.Row="0"
             x:Name="InnerTabView"
             Background="Transparent"
             BorderThickness="0"
             TabItemsSource="{x:Bind ViewModel.InnerTabs, Mode=OneWay}"
             SelectedItem="{x:Bind ViewModel.SelectedInnerTab, Mode=TwoWay}"
             SelectionChanged="InnerTabView_SelectionChanged"
             TabCloseRequested="InnerTabView_TabCloseRequested"
             IsAddTabButtonVisible="False"
             CanReorderTabs="False"
             HorizontalAlignment="Stretch">
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

    <!-- Content area seamlessly continuing the uniform background -->
    <ContentControl Grid.Row="1"
                    Background="Transparent"
                    Content="{x:Bind ViewModel.SelectedInnerTab.Content, Mode=OneWay}"
                    HorizontalContentAlignment="Stretch"
                    VerticalContentAlignment="Stretch" />
</Grid>
```
