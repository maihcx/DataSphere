# Interface Contract: Tab Memory Saver & Sleeping Lifecycle

- **Feature**: `016-tab-sleeping-memory-saver`
- **Date**: 2026-10-23
- **Status**: Completed

## 1. `ISleepableTabContent` Interface

Implemented by pages or ViewModels hosted inside `TabItemModel.Content` (e.g. `DataViewControl`, `DatabasePage`):

```csharp
namespace DataSphere.Services.Contracts
{
    /// <summary>
    /// Contract implemented by tab viewports capable of low-power suspension and fast rehydration.
    /// </summary>
    public interface ISleepableTabContent
    {
        /// <summary>
        /// Gets a value indicating whether this tab content is eligible for sleep.
        /// Returns false if active operations, queries, or unsaved changes are present.
        /// </summary>
        bool CanSleep { get; }

        /// <summary>
        /// Releases heavy visual element allocations, stops compositor sync, and trims transient caches.
        /// </summary>
        void Sleep();

        /// <summary>
        /// Rehydrates visual controls and restores active rendering and synchronization upon tab selection.
        /// </summary>
        void WakeUp();
    }
}
```

---

## 2. `ITabMemorySaverService` Interface

Coordinates the background timer and applies the sleeping policy:

```csharp
namespace DataSphere.Services.Contracts
{
    /// <summary>
    /// Manages the background idle evaluation and automated sleeping of inactive tabs.
    /// </summary>
    public interface ITabMemorySaverService : IDisposable
    {
        /// <summary>
        /// Gets or sets a value indicating whether background tab memory saving is active.
        /// </summary>
        bool IsEnabled { get; set; }

        /// <summary>
        /// Gets or sets the idle timeout in minutes before putting an inactive tab to sleep.
        /// </summary>
        int IdleTimeoutMinutes { get; set; }

        /// <summary>
        /// Manually triggers an evaluation pass over all open tabs.
        /// </summary>
        void EvaluateTabs(IEnumerable<TabItemModel> tabs, TabItemModel? activeTab);

        /// <summary>
        /// Awakes a sleeping tab on demand.
        /// </summary>
        /// <param name="tab">The tab to wake up.</param>
        void WakeUpTab(TabItemModel tab);
    }
}
```

---

## 3. UI XAML Contract (Settings Card & Tab Indicator)

### 3.1 Settings Performance Card

```xml
<!-- Section: Performance & Memory Saver -->
<TextBlock Text="{Binding [page_settings_performance_title], Source={StaticResource Localization}, Mode=OneWay}"
           Style="{StaticResource SubtitleTextBlockStyle}" />

<!-- Tab Memory Saver Toggle Card -->
<Border Background="{ThemeResource CardBackgroundFillColorDefaultBrush}" ...>
    <ToggleSwitch IsOn="{x:Bind ViewModel.EnableTabMemorySaver, Mode=TwoWay}" ... />
</Border>

<!-- Idle Timeout Selector Card -->
<Border Background="{ThemeResource CardBackgroundFillColorDefaultBrush}" ...>
    <ComboBox ItemsSource="{x:Bind ViewModel.SleepTimeoutOptions, Mode=OneWay}"
              SelectedItem="{x:Bind ViewModel.SelectedSleepTimeoutOption, Mode=TwoWay}"
              IsEnabled="{x:Bind ViewModel.EnableTabMemorySaver, Mode=OneWay}" ... />
</Border>
```

### 3.2 Sleeping Tab Header Visual Indicator

```xml
<StackPanel Orientation="Horizontal" Spacing="6" Opacity="{x:Bind IsSleepingOpacity, Mode=OneWay}">
    <FontIcon Glyph="{x:Bind IconGlyph, Mode=OneWay}" />
    <TextBlock Text="{x:Bind Title, Mode=OneWay}" />
    <FontIcon Glyph="&#xEC46;" FontSize="11" Visibility="{x:Bind IsSleepingVisibility, Mode=OneWay}" />
</StackPanel>
```
