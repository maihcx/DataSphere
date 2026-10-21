# Interface & XAML Contracts: Pill-Shaped TabViewItem Styling and Borderless TabStrip

**Feature Branch**: `012-pill-tabview-styling`
**Date**: 2026-10-21
**Spec**: [spec.md](../spec.md) | **Component Model**: [data-model.md](../data-model.md)

## 1. `ShellWindow.xaml` Layout Contract

```xml
<Grid x:Name="WindowRoot">
    <!-- WindowRoot uses DP Precedence via Style Setter -->
    <Grid.Style>
        <Style TargetType="Grid">
            <Setter Property="Background" Value="{ThemeResource ApplicationPageBackgroundThemeBrush}" />
        </Style>
    </Grid.Style>

    <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
        <RowDefinition Height="*" />
    </Grid.RowDefinitions>

    <!-- Top Navigation Chrome: Borderless Pill TabView -->
    <TabView
        x:Name="ShellTabView"
        Grid.Row="0"
        Background="Transparent"
        BorderThickness="0"
        BorderBrush="Transparent"
        CanDragTabs="True"
        CanReorderTabs="True"
        IsAddTabButtonVisible="False"
        TabItemsSource="{x:Bind ViewModel.Tabs, Mode=OneWay}"
        SelectedItem="{x:Bind ViewModel.SelectedTab, Mode=TwoWay}"
        SelectionChanged="OnTabViewSelectionChanged"
        TabCloseRequested="OnTabCloseRequested"
        TabDragStarting="OnTabDragStarting"
        TabDroppedOutside="OnTabDroppedOutside"
        TabStripDragOver="OnTabStripDragOver"
        TabStripDrop="OnTabStripDrop">

        <TabView.Resources>
            <!-- Borderless TabStrip Overrides -->
            <Thickness x:Key="TabViewBorderThickness">0</Thickness>
            <SolidColorBrush x:Key="TabViewBorderBrush" Color="Transparent" />
            <Thickness x:Key="TabViewTabStripBorderThickness">0</Thickness>
            <SolidColorBrush x:Key="TabViewItemStroke" Color="Transparent" />
            <SolidColorBrush x:Key="TabViewItemSeparator" Color="Transparent" />

            <!-- Pill Geometry Overrides -->
            <CornerRadius x:Key="TabViewItemCornerRadius">16</CornerRadius>
            <x:Double x:Key="TabViewItemHeaderMinHeight">34</x:Double>
        </TabView.Resources>

        <TabView.TabStripHeader>
            <Grid x:Name="CustomDragRegionLeft" Background="Transparent" Width="8" />
        </TabView.TabStripHeader>

        <TabView.TabStripFooter>
            <Grid x:Name="CustomDragRegion" Background="Transparent" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" MinWidth="188" />
        </TabView.TabStripFooter>

        <TabView.TabItemTemplate>
            <DataTemplate x:DataType="models:TabItemModel">
                <TabViewItem
                    Style="{StaticResource PillTabViewItemStyle}"
                    Header="{x:Bind Title, Mode=OneWay}"
                    IsClosable="{x:Bind IsClosable, Mode=OneWay}">
                    <TabViewItem.IconSource>
                        <FontIconSource Glyph="{x:Bind IconGlyph, Mode=OneWay}" />
                    </TabViewItem.IconSource>
                </TabViewItem>
            </DataTemplate>
        </TabView.TabItemTemplate>
    </TabView>

    <!-- Main Viewport Content Presenter (Decoupled row per Principle VII) -->
    <ContentPresenter
        Grid.Row="1"
        Background="Transparent"
        Content="{x:Bind ViewModel.SelectedTab.Content, Mode=OneWay}"
        HorizontalAlignment="Stretch"
        VerticalAlignment="Stretch" />
</Grid>
```

---

## 2. Style Definition Contract (`PillTabViewItemStyle`)

```xml
<Style x:Key="PillTabViewItemStyle" TargetType="TabViewItem">
    <Setter Property="CornerRadius" Value="16" />
    <Setter Property="Margin" Value="3,4,3,4" />
    <Setter Property="MinHeight" Value="34" />
    <Setter Property="Padding" Value="12,4,8,4" />
    <Setter Property="VerticalAlignment" Value="Center" />
</Style>
```
