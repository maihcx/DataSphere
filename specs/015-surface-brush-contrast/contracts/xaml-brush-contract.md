# Interface Contract: XAML Theme Brush Declarations

**Feature**: `015-surface-brush-contrast`
**Spec**: [spec.md](../spec.md)
**Model**: [data-model.md](../data-model.md)

---

## 1. `TabStyles.xaml` Contract

File: `DataSphere/Themes/TabStyles.xaml`

### VisualStates: `Selected`, `PointerOverSelected`, `PressedSelected`

```xml
<VisualState x:Name="Selected">
    <VisualState.Setters>
        <Setter Target="PillBorder.Background"
                Value="{ThemeResource CardBackgroundFillColorDefaultBrush}" />
        <Setter Target="PillBorder.BorderBrush"
                Value="{ThemeResource CardStrokeColorDefaultBrush}" />
        <Setter Target="ContentPresenter.Foreground"
                Value="{ThemeResource TextFillColorPrimaryBrush}" />
        <Setter Target="IconControl.Foreground"
                Value="{ThemeResource TextFillColorPrimaryBrush}" />
        <Setter Target="CloseButton.Foreground"
                Value="{ThemeResource TextFillColorPrimaryBrush}" />
    </VisualState.Setters>
</VisualState>

<VisualState x:Name="PointerOverSelected">
    <VisualState.Setters>
        <Setter Target="PillBorder.Background"
                Value="{ThemeResource CardBackgroundFillColorDefaultBrush}" />
        <Setter Target="PillBorder.BorderBrush"
                Value="{ThemeResource CardStrokeColorDefaultBrush}" />
        <Setter Target="ContentPresenter.Foreground"
                Value="{ThemeResource TextFillColorPrimaryBrush}" />
        <Setter Target="IconControl.Foreground"
                Value="{ThemeResource TextFillColorPrimaryBrush}" />
        <Setter Target="CloseButton.Foreground"
                Value="{ThemeResource TextFillColorPrimaryBrush}" />
    </VisualState.Setters>
</VisualState>

<VisualState x:Name="PressedSelected">
    <VisualState.Setters>
        <Setter Target="PillBorder.Background"
                Value="{ThemeResource CardBackgroundFillColorDefaultBrush}" />
        <Setter Target="PillBorder.BorderBrush"
                Value="{ThemeResource CardStrokeColorDefaultBrush}" />
        <Setter Target="ContentPresenter.Foreground"
                Value="{ThemeResource TextFillColorPrimaryBrush}" />
        <Setter Target="IconControl.Foreground"
                Value="{ThemeResource TextFillColorPrimaryBrush}" />
        <Setter Target="CloseButton.Foreground"
                Value="{ThemeResource TextFillColorPrimaryBrush}" />
    </VisualState.Setters>
</VisualState>
```

---

## 2. Workspace Views Contract

### 2.1 `DatabasePage.xaml` (Row 1 Grid)
```xml
<!-- Inner Tab Workspace with unified card background -->
<Grid Grid.Row="1"
      Background="{ThemeResource CardBackgroundFillColorDefaultBrush}">
    <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
        <RowDefinition Height="*" />
    </Grid.RowDefinitions>
...
```

### 2.2 `ConnectViewControl.xaml` (Root Grid)
```xml
<Grid Background="{ThemeResource CardBackgroundFillColorDefaultBrush}">
...
```

### 2.3 `DatabaseViewControl.xaml` (Root Grid)
```xml
<Grid Background="{ThemeResource CardBackgroundFillColorDefaultBrush}">
...
```

### 2.4 `VirtualTable.xaml` (Root Grid)
```xml
<Grid x:Name="RootGrid"
      Background="{ThemeResource CardBackgroundFillColorDefaultBrush}"
...
```
