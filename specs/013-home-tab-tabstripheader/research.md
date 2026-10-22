# Architecture Research & Technical Decisions: Home Tab in TabStripHeader and Unified Tab Styling

**Branch**: `013-home-tab-tabstripheader`
**Date**: 2026-10-22
**Spec**: [spec.md](./spec.md)

---

## 1. Research Questions & Design Choices

### Decision 1: Home Tab Representation in `TabView.TabStripHeader`
- **Context**: WinUI 3 `TabView.TabStripHeader` is an arbitrary content region positioned to the left of the scrollable tab item strip. We need the Home tab to look and feel identical to a pill tab (`PillTabViewItemStyle`), support selection state, support an optional close button ('X') when Home is the only tab, and be 100% immune to dragging.
- **Evaluation**:
  1. *Approach A: Standalone `TabViewItem` with `PillTabViewItemStyle`*: Placing a `TabViewItem` inside `TabStripHeader` reusing `Style="{StaticResource PillTabViewItemStyle}"`. Because it resides in `TabStripHeader`, it is not an element of `ShellTabView.TabItemsSource` or `Items`, so it cannot be reordered or dragged. Its visual state (`Selected` vs `Normal`) can be driven via `IsSelected="{x:Bind ViewModel.IsHomeSelected, Mode=TwoWay}"` or VisualStateManager setters.
  2. *Approach B: Dedicated Custom Button/Control*: Creating a custom button with capsule geometry matching `PillTabViewItemStyle`.
- **Decision**: **Approach A**. Using `TabViewItem` with `Style="{StaticResource PillTabViewItemStyle}"` inside `TabStripHeader` ensures 100% pixel-perfect visual parity, exact font size, icon alignment, hover/pressed state brushes, and close button behavior, without duplicating XAML templates.
- **Rationale**: Minimal code duplication, zero visual discrepancy, and native support for `IsClosable` and close button templating.

---

### Decision 2: ViewModel Coordination & Selection Mutual Exclusion
- **Context**: The main viewport (`ContentPresenter`) in `ShellWindow` needs to render either `HomePage` (when Home is selected) or the selected dynamic tab's content (when a dynamic tab is selected).
- **Evaluation**:
  1. *Single combined Tabs collection*: Keeping Home at index 0 of `Tabs` and somehow hacking the layout. Rejected: WinUI 3 `TabView` does not support splitting `TabItemsSource` across `TabStripHeader` and the tab strip.
  2. *Decoupled HomeTab & Dynamic Tabs*: `ShellViewModel` maintains:
     - `HomeTab` (`TabItemModel`): Dedicated singleton model for Home.
     - `Tabs` (`ObservableCollection<TabItemModel>`): Dynamic workspace tabs (Database, Connections, Settings).
     - `IsHomeSelected` (bool): `true` when Home is active, `false` when a dynamic tab is active.
     - `SelectedTab` (`TabItemModel?`): Currently selected dynamic tab (null if Home is active).
     - `ActiveViewportContent` (object?): Resolves to `HomeTab.Content` if `IsHomeSelected` is true, otherwise `SelectedTab.Content`.
- **Decision**: **Approach 2 (Decoupled State)**.
- **Rationale**:
  - Eliminates fragile index tricks.
  - Guarantees Home is never in the draggable `Tabs` collection (ensuring immobility).
  - Explicitly manages close button visibility: `HomeTab.IsClosable = (Tabs.Count == 0)`.
  - When `Tabs.Count == 0`, `IsHomeSelected` is automatically set to `true`.
  - Clean MVVM adherence with zero visual tree dependencies.

---

### Decision 3: Resource Dictionary Architecture (`Themes/TabStyles.xaml`)
- **Context**: Both `ShellWindow.xaml` and `DatabasePage.xaml` need `PillTabViewItemStyle` and TabView borderless tokens.
- **Evaluation**:
  1. *Global `App.xaml` inline*: Placing the style directly into `App.xaml`. Clutters `App.xaml` with 250+ lines of XAML.
  2. *Dedicated `Themes/TabStyles.xaml`*: Extracting the style and related TabView override resources into `DataSphere/Themes/TabStyles.xaml` and merging it into `App.xaml` via `<ResourceDictionary Source="ms-appx:///Themes/TabStyles.xaml" />`.
- **Decision**: **Approach 2 (Dedicated Resource Dictionary)**.
- **Rationale**: Clean modular architecture, reusable across any window or page, easily maintainable and isolated.

---

### Decision 4: Uniform Background for `DatabasePage` Inner Workspace
- **Context**: User clarified: "Tôi muốn nền từ đó đến dưới tab đồng nhất với tab (chỉ trang DatabasePage)". The background from `InnerTabView` down through the active content area in `DatabasePage` should be uniform with the tab surface.
- **Evaluation**:
  1. *Transparent background (current)*: Exposes the window backdrop (Mica/Acrylic).
  2. *Uniform Container Background*: Enclosing `InnerTabView` and the `ContentControl` in a container with `Background="{ThemeResource LayerFillColorDefaultBrush}"` (or card fill), while setting `InnerTabView.Background="Transparent"`.
- **Decision**: Set the container Grid enclosing `InnerTabView` and `Active Tab Content Area` to `Background="{ThemeResource LayerFillColorDefaultBrush}"` in `DatabasePage.xaml`.
- **Rationale**: Creates a cohesive, solid workspace canvas for table grids and query editors while preserving the window-level Mica backdrop in `ShellWindow`.

---

## 2. Technical Dependencies & Constraints Summary

| Item | Choice | Justification |
|---|---|---|
| **Framework** | Windows App SDK (WinUI 3) + .NET 10 | Existing project target (`net10.0-windows10.0.26100.0`). |
| **MVVM Library** | `CommunityToolkit.Mvvm` v8.4 | Source generators (`[ObservableProperty]`, `[RelayCommand]`). |
| **Styling** | `Themes/TabStyles.xaml` | Centralized pill geometry, brushes, and borderless overrides. |
| **Localization** | `TranslationSource` (`page_home_title`) | Zero hardcoded strings per Principle VII. |
| **UI Verification** | `WinSta0\default` + `PrintWindow` | Live desktop testing per Principle VIII. |
