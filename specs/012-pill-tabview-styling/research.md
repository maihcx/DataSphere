# Research: Pill-Shaped TabViewItem Styling and Borderless TabStrip

**Feature Branch**: `012-pill-tabview-styling`
**Date**: 2026-10-21
**Spec**: [spec.md](./spec.md)

## Overview & UI Architecture Context

In Windows App SDK (WinUI 3), `TabView` by default employs standard Microsoft Edge / Google Chrome flat tabs. These tabs have square bottom edges, slanted or slightly rounded top corners (typically 4-8px), and sit flush against a 1px horizontal bottom divider line (`TabViewBorderThickness = 0,0,0,1`).

The user requirement specifies:
1. Tab headers display in a pill / capsule shape (fully rounded corners on all 4 corners).
2. The bottom border separating the TabView and the page content is completely eliminated.

---

## Technical Findings & Decisions

### Decision 1: Capsule Pill Geometry via `CornerRadius` and Balanced Margins

- **Chosen**:
  - Apply `CornerRadius="16"` across `TabViewItem`. With standard tab heights of 32px to 36px, a radius of 16px creates a perfect pill/capsule shape on both ends.
  - Apply `Margin="3,4,3,4"` around each tab item. This lifts the tab off the bottom and top edges, allowing it to float as an isolated capsule element rather than connecting to adjacent tabs.
  - Apply `BorderThickness="1"` with `{ThemeResource CardStrokeColorDefaultBrush}` or `BorderThickness="0"` for smooth blending.
- **Rationale**:
  - Provides a modern Fluent Design 2 aesthetic similar to Windows 11 segmented pills, browser tabs, and modern developer tools.
  - Capsule geometry prevents visual collisions when tabs are dragged or hovered.
- **Alternatives Considered**:
  - *Standard rectangular tabs with top-only radius*: Rejected because it maintains the legacy flat chrome appearance and doesn't meet the pill shape requirement.

---

### Decision 2: Elimination of TabView Bottom Divider Line

- **Chosen**:
  - Set `BorderThickness="0"` and `BorderBrush="Transparent"` directly on `<TabView x:Name="ShellTabView">`.
  - Override WinUI 3 theme resources in `<TabView.Resources>`:
    ```xml
    <Thickness x:Key="TabViewBorderThickness">0</Thickness>
    <SolidColorBrush x:Key="TabViewBorderBrush" Color="Transparent" />
    <Thickness x:Key="TabViewTabStripBorderThickness">0</Thickness>
    <SolidColorBrush x:Key="TabViewItemStroke" Color="Transparent" />
    <SolidColorBrush x:Key="TabViewItemSeparator" Color="Transparent" />
    ```
- **Rationale**:
  - WinUI 3 `TabView` internally renders a border line using `TabViewBorderBrush` and `TabViewBorderThickness`. Setting these values to 0 and Transparent completely eradicates the horizontal dividing line across all themes (Light, Dark, High Contrast) and system backdrops (Mica, Acrylic, Solid).
- **Alternatives Considered**:
  - *Negative top margin on the page presenter (`Margin="0,-1,0,0"`)*: Rejected as a hacky layout workaround that can cause 1px rendering clipping during DPI scaling. Overriding the actual XAML resources and properties is clean and robust.

---

### Decision 3: Dynamic Theme Brushes for Pill States

- **Chosen**:
  - **Selected Pill**:
    - Light Mode: Background `{ThemeResource SolidBackgroundFillColorBaseBrush}` or `{ThemeResource CardBackgroundFillColorDefaultBrush}`, Border `{ThemeResource CardStrokeColorDefaultBrush}`.
    - Dark Mode: Background `{ThemeResource LayerFillColorDefaultBrush}` or `{ThemeResource CardBackgroundFillColorDefaultBrush}` (`#2D2D2D`), Border `{ThemeResource CardStrokeColorDefaultBrush}`.
  - **Unselected Pill**: Background `Transparent`, Border `Transparent`.
  - **PointerOver Pill**: Background `{ThemeResource SubtleFillColorSecondaryBrush}`.
  - **Pressed Pill**: Background `{ThemeResource SubtleFillColorTertiaryBrush}`.
- **Rationale**:
  - Using `{ThemeResource}` ensures instant, seamless theme synchronization without hardcoded hex codes.
  - Matches the contrast and accessibility standards of Windows 11 Fluent Design 2.
- **Alternatives Considered**:
  - *Hardcoded solid colors*: Explicitly forbidden by Principle VII and Principle II.

---

### Decision 4: Architecture Integration with `ShellWindow.xaml`

- **Chosen**:
  - Define the `PillTabViewItemStyle` in `ShellWindow.xaml.Resources`.
  - Apply `Style="{StaticResource PillTabViewItemStyle}"` directly on `<TabViewItem>` inside `<TabView.TabItemTemplate>`.
  - Apply resource overrides in `<TabView.Resources>`.
- **Rationale**:
  - Keeps scope localized to `ShellWindow.xaml` where the application tab strip lives, maintaining high cohesion and zero risk of side effects on other controls.
