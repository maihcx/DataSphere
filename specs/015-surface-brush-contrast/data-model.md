# Data Model & Theme Token Architecture: Surface & Tab Selected Theme Brush Contrast Enhancement

**Feature**: `015-surface-brush-contrast`
**Spec**: [spec.md](./spec.md)
**Research**: [research.md](./research.md)

---

## 1. Theme Resource Token Mapping

The feature standardizes visual surfaces across Light and Dark theme dictionaries using native WinUI 3 Fluent 2 design tokens:

```mermaid
classDiagram
    class FluentDesignThemeSystem {
        +ThemeResource Light
        +ThemeResource Dark
    }

    class CardBackgroundFillColorDefaultBrush {
        +Light: #FFFFFF (Solid White / B3 Translucent)
        +Dark: #2D2D2D (Elevated Dark Card Fill)
        +BorderPair: CardStrokeColorDefaultBrush
    }

    class SurfaceConsumers {
        +PillTabViewItemStyle Selected States
        +DatabasePage Workspace Grid
        +ConnectViewControl Root Grid
        +DatabaseViewControl Root Grid
        +VirtualTable Grid Canvas
    }

    FluentDesignThemeSystem --> CardBackgroundFillColorDefaultBrush : Resolves at Runtime
    CardBackgroundFillColorDefaultBrush --> SurfaceConsumers : ThemeResource Dynamic Binding
```

---

## 2. Visual State Mapping in `PillTabViewItemStyle`

In `DataSphere/Themes/TabStyles.xaml`, the `PillBorder` element transitions between visual states based on user interaction:

| Visual State | Target Element | Property | Previous Token (Faint in Dark) | New Standard Token (Elevated Contrast) |
|---|---|---|---|---|
| `Normal` | `PillBorder` | `Background` | `Transparent` | `Transparent` (Unchanged) |
| `PointerOver` | `PillBorder` | `Background` | `SubtleFillColorSecondaryBrush` | `SubtleFillColorSecondaryBrush` (Unchanged) |
| `Pressed` | `PillBorder` | `Background` | `SubtleFillColorTertiaryBrush` | `SubtleFillColorTertiaryBrush` (Unchanged) |
| **`Selected`** | `PillBorder` | `Background` | `LayerFillColorDefaultBrush` ❌ | **`CardBackgroundFillColorDefaultBrush`** ✅ |
| **`PointerOverSelected`** | `PillBorder` | `Background` | `LayerFillColorDefaultBrush` ❌ | **`CardBackgroundFillColorDefaultBrush`** ✅ |
| **`PressedSelected`** | `PillBorder` | `Background` | `LayerFillColorDefaultBrush` ❌ | **`CardBackgroundFillColorDefaultBrush`** ✅ |

---

## 3. Container Surface Hierarchy

```mermaid
flowchart TD
    Window["ShellWindow (System Backdrop: Mica / Mica Alt)"]
    TitleBar["ShellTabView (Header & Pill Tabs)"]
    
    subgraph Tabs ["Tab Strip Components"]
        TabNormal["Unselected Tab: Transparent Background"]
        TabSelected["Selected Tab: CardBackgroundFillColorDefaultBrush + CardStroke"]
    end
    
    subgraph Viewport ["Workspace Canvas (Row 1)"]
        DBPage["DatabasePage: CardBackgroundFillColorDefaultBrush"]
        ConnectView["ConnectViewControl: CardBackgroundFillColorDefaultBrush"]
        DBView["DatabaseViewControl: CardBackgroundFillColorDefaultBrush"]
        VTable["VirtualTable: CardBackgroundFillColorDefaultBrush"]
    end

    Window --> TitleBar
    TitleBar --> TabNormal
    TitleBar --> TabSelected
    Window --> Viewport
    Viewport --> DBPage
    DBPage --> ConnectView
    DBPage --> DBView
    DBView --> VTable
```

---

## 4. Theme Transition Lifecycle State Machine

```mermaid
stateDiagram-v2
    [*] --> InitialTheme: Application Launch

    state InitialTheme {
        [*] --> ReadSystemTheme: Query ApplicationThemeManager
        ReadSystemTheme --> ApplyThemeResources: Light or Dark Mode Active
        ApplyThemeResources --> RenderHighContrastSurfaces: CardBackgroundFillColorDefaultBrush resolved
    }

    InitialTheme --> ThemeToggled: User switches theme in Settings
    ThemeToggled --> InstantResourceReevaluation: WinUI 3 ThemeResource Tree Walk
    InstantResourceReevaluation --> InitialTheme: All tabs and surfaces update in <100ms
```
