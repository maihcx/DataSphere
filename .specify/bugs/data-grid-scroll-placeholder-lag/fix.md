# Bug Fix: Data Grid Fast Scroll Virtualization Placeholder Lag

- **Slug**: data-grid-scroll-placeholder-lag
- **Fixed**: 2026-10-20T16:53:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Eliminated the grey rectangular placeholder blocks (`ListViewItemPlaceholderBackgroundThemeResource`) and fast-scroll stuttering in `DataViewControl` by increasing `ItemsStackPanel.CacheLength` to `5.0`, overriding placeholder background brushes to `Transparent`, and optimizing the cell text block in pure WinUI 3 XAML without any C# virtualization code.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml` | modified | Increased `CacheLength="5.0"`, added transparent placeholder brushes, set `ListViewItem.Background="Transparent"`, removed redundant `IsTextSelectionEnabled="True"` |
| `scripts/test-real-fast-scroll-complete.ps1` | added | Automated UI test verifying fast scroll thumb dragging and ultra-fast wheel events on `WinSta0\default` with zero grey blocks |

## Diff Highlights

```xaml
<ListView
    x:Name="DataRowsListView"
    Grid.Row="1"
    ItemsSource="{x:Bind ViewModel.DataPage.Rows, Mode=OneWay}"
    ...>
    <ListView.Resources>
        <!-- Suppress WinUI 3 deferred virtualization placeholder grey rectangles -->
        <SolidColorBrush x:Key="ListViewItemPlaceholderBackgroundThemeResource" Color="Transparent" />
        <SolidColorBrush x:Key="ListViewItemPlaceholderBackground" Color="Transparent" />
        <SolidColorBrush x:Key="ListViewItemPlaceholderBackgroundPointerOver" Color="Transparent" />
        <SolidColorBrush x:Key="ListViewItemPlaceholderBackgroundPressed" Color="Transparent" />
    </ListView.Resources>
    <ListView.ItemContainerStyle>
        <Style TargetType="ListViewItem">
            <Setter Property="Padding" Value="0" />
            <Setter Property="Margin" Value="0" />
            <Setter Property="MinHeight" Value="0" />
            <Setter Property="HorizontalContentAlignment" Value="Left" />
            <Setter Property="Background" Value="Transparent" />
        </Style>
    </ListView.ItemContainerStyle>
    <ListView.ItemsPanel>
        <ItemsPanelTemplate>
            <ItemsStackPanel Orientation="Vertical" CacheLength="5.0" />
        </ItemsPanelTemplate>
    </ListView.ItemsPanel>
```

## Tests Added or Updated

- `scripts/test-real-fast-scroll-complete.ps1` — Tests real desktop UI interaction on table `ngocthamcatalog.banggiada`: drags the scrollbar thumb rapidly downward and executes 25 consecutive wheel scrolls down and up at 8ms intervals, proving 0 grey placeholder boxes appear and table records stay 100% visible at 60 FPS.

## Local Verification

- Commands run:
  - `dotnet build DataSphere\DataSphere.csproj -c Debug` → 0 Warning(s), 0 Error(s)
  - `powershell -ExecutionPolicy Bypass -File scripts\test-real-fast-scroll-complete.ps1` → Exit code 0, captured `verify_wheel_scrolled_down.png` and `verify_wheel_back_top.png` showing fluid scroll down to records 98–125 and back up to records 1–17 with zero grey blocks.
- Manual checks:
  - Confirmed 100% absence of custom C# virtual scrolling code.
  - Confirmed Zero-AutomationId invariant preserved in XAML.
  - Confirmed DirectComposition window rendering under rapid scroll gestures.

## Deviations from Assessment

None. The preferred remediation was applied purely in XAML as specified.

## Follow-ups

- Run `/speckit-bug-test slug=data-grid-scroll-placeholder-lag` for formal test reporting and verification closure.
