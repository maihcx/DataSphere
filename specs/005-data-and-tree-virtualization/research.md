# Technical Research: Data Table & Schema Tree UI Virtualization

**Branch**: `005-data-and-tree-virtualization` | **Date**: 2026-10-20 | **Spec**: [spec.md](./spec.md)

## 1. Problem Space & Architecture Overview

In desktop database administration systems, user satisfaction is fundamentally tied to data exploration responsiveness. DataSphere users routinely view:
1. Tables with thousands of rows and dozens of columns.
2. Servers hosting tens of databases, each with hundreds of tables, views, and functions.

Without proper UI virtualization, the XAML visual tree materializes every element simultaneously, resulting in:
- Severe UI freezes during page loads and schema expansion.
- Sluggish vertical and horizontal scrolling (< 20 FPS).
- Ballooning memory footprints (hundreds of megabytes allocated for off-screen UI elements).

This research evaluates virtualization patterns for WinUI 3 / Windows App SDK 2.5+ on .NET 10 to establish 60 FPS fluid rendering, low memory overhead, and 100% Clean MVVM compliance.

---

## 2. Table Data Viewport Virtualization

### 2.1 Analysis of Current Deficiency in `DataViewControl.xaml`
In the current implementation:
```xml
<ScrollViewer Grid.Row="1" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto">
    <StackPanel HorizontalAlignment="Left">
        <Border><!-- Header ItemsControl --></Border>
        <ListView ItemsSource="{x:Bind ViewModel.DataPage.Rows, Mode=OneWay}">
            <!-- Rows ItemsControl -->
        </ListView>
    </StackPanel>
</ScrollViewer>
```
**Why Virtualization Was Disabled**:
1. Placing a `ListView` inside an unconstrained `StackPanel` or within a vertically-scrolling `ScrollViewer` supplies the `ListView` with infinite available height (`double.PositiveInfinity`).
2. When height is unconstrained, `ListView`'s internal `ItemsStackPanel` measures all items at once to determine total height, instantly materializing 100% of the row containers (`ListViewItem`).
3. For 1,000 rows across 8 columns, 8,000+ visual text blocks and border elements are instantiated simultaneously.

### 2.2 Proposed Virtualization Architecture: Two-Tier Virtualized Grid Viewport
To restore true row virtualization while preserving synchronized horizontal scrolling across column headers and rows:

```text
+-------------------------------------------------------------------------------+
| Grid.Row="1" (Constrained Viewport Height)                                    |
|                                                                               |
|  +-------------------------------------------------------------------------+  |
|  | HorizontalScrollViewer (Horizontal: Auto, Vertical: Disabled)           |  |
|  |                                                                         |  |
|  |  +-------------------------------------------------------------------+  |  |
|  |  | MinWidth = TotalColumnsWidth                                      |  |  |
|  |  |                                                                   |  |  |
|  |  |  [Row 0: Sticky Column Header Bar]                                |  |  |
|  |  |  +-------------------------------------------------------------+  |  |  |
|  |  |  | Column 1 (140px) | Column 2 (140px) | ... | Column N (140px)    |  |  |  |
|  |  |  +-------------------------------------------------------------+  |  |  |
|  |  |                                                                   |  |  |
|  |  |  [Row 1: Virtualized TableRecordsListView]                         |  |  |
|  |  |  +-------------------------------------------------------------+  |  |  |
|  |  |  | (ItemsStackPanel with CacheLength=2.0)                      |  |  |  |
|  |  |  | - Only visible rows (~20) + buffer materialized             |  |  |  |
|  |  |  | - Direct compiled data binding ({x:Bind})                   |  |  |  |
|  |  |  | - Single selection & TextSelectionEnabled preserved        |  |  |  |
|  |  |  +-------------------------------------------------------------+  |  |  |
|  |  +-------------------------------------------------------------------+  |  |
|  +-------------------------------------------------------------------------+  |
+-------------------------------------------------------------------------------+
```

**Key Architectural Properties**:
- **Constrained Vertical Space**: The inner `ListView` directly occupies `Grid.Row="1"`, giving it an exact, bounded viewport height.
- **Active Vertical Virtualization**: The `ListView`'s built-in `ItemsStackPanel` only creates visual containers for rows currently visible on screen plus a 2-page buffer (`CacheLength="2.0"`).
- **Synchronous Horizontal Scroll**: The outer `ScrollViewer` handles ONLY horizontal scrolling (`VerticalScrollMode="Disabled"`). When the user scrolls horizontally, both the column header row and all virtualized data rows translate horizontally in lockstep with zero offset drift.
- **Container Recycling Safety**: Row cells bind to lightweight string collections or row record models. Container reuse does not carry over state or leak visual tree bindings.

---

## 3. Schema TreeView Virtualization

### 3.1 WinUI 3 `TreeView` Virtualization Mechanics
WinUI 3's `TreeView` is implemented on top of `TreeViewList`, which inherently derives from `ListView` and utilizes `ItemsStackPanel`.

To ensure optimal performance when handling large schemas:
1. **Pure POCO Content Model**:
   - `TreeViewNode.Content` MUST strictly store pure POCO data (`DatabaseTreeNode`) rather than UI controls (`StackPanel`, `FontIcon`).
   - The visual presentation is declared purely inside `TreeView.ItemTemplate`. This prevents container reparenting exceptions (`0xC000027B`) during rapid item virtualization recycling.
2. **Asynchronous Batched Loading**:
   - For database schemas containing 300+ tables, table node creation must occur asynchronously without locking the UI dispatcher.
   - Initial categorization (Tables, Views, Procedures, Functions) keeps top-level child lists compact until expanded.
3. **Smooth Scroll Tuning**:
   - Explicit padding and item height uniformity ensure the virtualization layout engine can calculate item offsets instantaneously without re-measuring off-screen elements.

---

## 4. Performance & Memory Benchmarks (Estimated)

| Metric | Without Virtualization (1,000 rows) | With Proposed Virtualization (1,000 rows) | Improvement |
|---|---|---|---|
| Initial Render Time | ~650 ms | ~45 ms | **14x Faster** |
| Active Visual Elements | 8,000+ controls | ~160 controls (20 rows x 8 cols) | **98% Fewer Controls** |
| Scrolling Frame Rate | 15 - 28 FPS (jittery) | 60 FPS (<16ms/frame) | **Rock-solid 60 FPS** |
| Working Set Memory | +85 MB | +12 MB | **86% Memory Savings** |
| Schema Tree Expand (300 items) | ~320 ms | ~30 ms | **10x Faster** |

---

## 5. Decision Log

1. **Keep ListView with ItemsStackPanel vs Third-Party Grid**:
   - *Decision*: Retain native WinUI 3 `ListView` with `ItemsStackPanel` constrained in a horizontal scroll viewport.
   - *Rationale*: Zero third-party dependency overhead, native Fluent Design styling, full compatibility with `Wpf.Ui` / WinUI 3 theme engines, and 100% compliance with Hiến chương.
2. **Outer Horizontal Scroll vs Header Scroll Synchronization**:
   - *Decision*: Use outer horizontal `ScrollViewer` (`VerticalScrollMode="Disabled"`) containing the header and the vertical-virtualizing `ListView`.
   - *Rationale*: Native GPU composition translates both elements simultaneously without event-based latency or scroll desynchronization jitter.
3. **Container Recycling Safety**:
   - *Decision*: Maintain pure POCO records (`TableRowData`, `DatabaseTreeNode`), compile bindings with `{x:Bind Mode=OneWay}`, and use `NullToVisibilityConverter`.
   - *Rationale*: Guarantees zero `E_INVALIDARG` / `0xC000027B` recycling exceptions during aggressive scrolling and node expansion.
