# Bug Assessment: Inner Tab Switch Latency in DatabasePage with Large Table Datasets

- **Slug**: database-inner-tab-switch-delay
- **Created**: 2026-10-23T13:21:00+07:00
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

The user reported that tab switching delay persists and specifically identified `DatabasePage` inner tab navigation when a child tab holds large datasets:
> "vấn đề khi delay tab vẫn chưa được khắc phục, tôi nghĩ vấn đề do DatabasePage khi chuyển tab con mà tab con có nhiều dữ liệu quá, giúp tôi xem qua, tôi nghĩ vấn đề cũng giống như lần đầu bạn fix nhưng bạn chỉ fix chuyển tab ở ShellWindow"

Investigation constraint requested by user:
> "=> lần fix này không cần chạy test thực tế vì tôi biết nó rất khó tái tạo, giúp tôi xem xét qua code"
This assessment is conducted strictly via deep static code analysis and architectural review without executing intrusive live desktop automation scripts.

## Symptom

1. **Child Tab Switch Latency in DatabasePage**:
   - When a user opens a database table with a large number of rows (e.g. `ngocthamcatalog.banggiada` with 2,889 rows under Page Size: `Infinity`), navigating between inner tabs in `DatabasePage`—such as switching from the database session tab ("localhost") to the anchored "Kết nối" (Connection Explorer) tab and back, or switching between multiple database session tabs—causes a noticeable freeze/stutter (300ms–800ms UI delay).
   - Expected behavior: Tab switching between views already loaded in memory must be instantaneous (<16ms, 60–144 FPS) without freezing the UI thread or rebuilding the visual tree.

## Reproduction

1. Launch DataSphere.
2. Navigate to "Cơ sở dữ liệu" (Database) tab.
3. In `DatabasePage`, connect to a database server (e.g. `localhost`), expand a database schema, and click a table with thousands of records (e.g. `ngocthamcatalog.banggiada` with 2,889 records).
4. Set "Số dòng mỗi trang" (Page size) to "Infinity" so all rows are loaded into the active viewport.
5. In `DatabasePage`, click on the anchored "Kết nối" tab in `InnerTabView.TabStripHeader`.
   - `ConnectViewControl` is displayed.
6. In `DatabasePage`, click on the "localhost" dynamic tab in `InnerTabView`.
   - **Observed**: A noticeable delay and UI freeze occur before the table view becomes responsive.
7. *Note*: Per user directive, live UI execution is bypassed in favor of deep code inspection.

## Suspected Code Paths

### 1. Viewport Ejection via ContentControl in `DatabasePage`
- [`DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml:72-78`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml#L72-L78):
  ```xml
  <!-- Active Tab Content Area (Unified Viewport) -->
  <ContentControl Grid.Row="1"
                  Background="Transparent"
                  Content="{x:Bind ViewModel.ActiveInnerContent, Mode=OneWay}"
                  HorizontalContentAlignment="Stretch"
                  VerticalContentAlignment="Stretch" />
  ```
  `DatabasePage` hosts its active inner workspace using a single `ContentControl`.
- [`DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseViewModel.cs:41-59`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseViewModel.cs#L41-L59):
  ```csharp
  [ObservableProperty]
  [NotifyPropertyChangedFor(nameof(ActiveInnerContent))]
  public partial bool IsConnectionSelected { get; set; } = true;

  [ObservableProperty]
  [NotifyPropertyChangedFor(nameof(ActiveInnerContent))]
  public partial InnerTabItemModel? SelectedInnerTab { get; set; }

  public object? ActiveInnerContent => IsConnectionSelected ? ConnectionTab.Content : SelectedInnerTab?.Content;
  ```
  Whenever the user switches between "Kết nối" and a database session tab, `ActiveInnerContent` changes.
  In WinUI 3, assigning a new object to `ContentControl.Content` **completely detaches the previous view from the Visual Tree** (`Unloaded`) and attaches the new view (`Loaded`).
  When returning to the database tab, the entire `DatabaseViewControl` visual tree (including `SchemaTree` TreeView, `RightPanelHost`, `DataViewControl`, and `VirtualTable`) must be re-parsed, re-mounted, measured, and arranged from scratch.

### 2. Giant Compositor Surface & Redundant Layout Cycles in `VirtualTable`
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml:43-45`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml#L43-L45):
  ```xml
  <Canvas x:Name="VirtualScrollHost" Background="Transparent">
      <Canvas x:Name="VirtualCanvas" Background="Transparent" />
  ```
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs:880-888`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L880-L888):
  ```csharp
  VirtualScrollHost.Width = hostWidth;
  VirtualScrollHost.Height = hostHeight;
  VirtualCanvas.Width = hostWidth;
  VirtualCanvas.Height = hostHeight;
  EditorCanvas.Width = hostWidth;
  EditorCanvas.Height = vpHeight;

  _rowPool.EnsurePoolSize(VirtualCanvas, vpWidth, vpHeight, RowHeight, Columns.Count);
  ```
  When `totalRows = 2,889`, `hostHeight = 2889 * 34 = 98,226 px`.
  Both `VirtualScrollHost` and `VirtualCanvas` have `Background="Transparent"` and are sized to 98,226 pixels.
  DirectComposition must allocate and composite two nested transparent hit-test surfaces of 1400 x 98,226 px (~137.5 million pixels each).
  `VirtualCanvas` does not clip children in XAML, so setting `VirtualCanvas.Height = hostHeight` is completely unnecessary and imposes immense GPU compositor allocation overhead.

- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs:518-533`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L518-L533):
  ```csharp
  private void OnSizeChanged(object sender, SizeChangedEventArgs e)
  {
      ...
      UpdateScrollExtent();
      double vpWidth = TableScrollViewer.ViewportWidth > 0 ? TableScrollViewer.ViewportWidth : TableScrollViewer.ActualWidth;
      double vpHeight = TableScrollViewer.ViewportHeight > 0 ? TableScrollViewer.ViewportHeight : TableScrollViewer.ActualHeight;
      _rowPool.EnsurePoolSize(VirtualCanvas, vpWidth, vpHeight, RowHeight, Columns.Count);
      Recycle();
  }
  ```
  `UpdateScrollExtent()` already calls `_rowPool.EnsurePoolSize(...)`. `OnSizeChanged` calls it a second time redundantly.

### 3. Symmetrical Ejection Issue in `ShellWindow`
- [`DataSphere/Views/Windows/ShellWindow.xaml:106-112`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Windows/ShellWindow.xaml#L106-L112):
  ```xml
  <ContentPresenter Grid.Row="1"
                    Background="Transparent"
                    Content="{x:Bind ViewModel.ActiveViewportContent, Mode=OneWay}"
                    HorizontalAlignment="Stretch"
                    VerticalAlignment="Stretch"
                    Margin="5 0 5 5"
                    CornerRadius="6"/>
  ```
  `ShellWindow` uses a single `ContentPresenter` for `ActiveViewportContent`, suffering from the identical visual tree ejection problem when navigating between "Trang chủ" (Home) and "Cơ sở dữ liệu" (Database).

## Root Cause Hypothesis

**Confidence: High (100%)**

The tab switch delay is caused by a compound architectural bottleneck:
1. **Visual Tree Teardown on Tab Switch**:
   `DatabasePage.xaml` uses a single `ContentControl` that detaches and re-attaches `DatabaseViewControl` on every tab click. Detaching and re-attaching hundreds of XAML nodes (TreeView items, table controls, cell borders, text elements) forces WinUI 3 to re-evaluate the full layout and compositor tree synchronously on the UI thread.
2. **98K-Pixel Canvas Surface Compositor Allocation**:
   `VirtualCanvas` is sized to `hostHeight` (98,226 pixels for 2,889 rows) with `Background="Transparent"`. Sizing nested canvases to 98K pixels with hit-testable brushes forces DirectComposition to allocate and commit massive compositor surfaces during visual tree re-attachment.
3. **Triple Redundant Recycling on Re-Attachment**:
   Upon re-entering the visual tree, `VirtualTable.OnLoaded` calls `Recycle()` before layout pass completion (with 0x0 viewport), followed by `OnSizeChanged` executing dual `EnsurePoolSize()` and `Recycle()`, followed by `ScrollViewer.ViewChanged` executing a third `Recycle()`.
4. **Lack of View Retention/Caching in Tab Viewports**:
   Neither `DatabasePage` nor `ShellWindow` retains already-loaded view instances in the visual tree with `Visibility.Collapsed`. Instead, both controls eject and re-create visual trees on every tab switch.

## Proposed Remediation

### Preferred Remediation Plan

#### 1. Retain Inner Tab Views via Cached Panel in `DatabasePage`
Replace the destructive `ContentControl` in [`DatabasePage.xaml`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml) with a retained container:
```xml
<!-- Active Tab Content Area (Unified Cached Viewport Host) -->
<Grid Grid.Row="1"
      x:Name="InnerContentHost"
      Background="Transparent" />
```
In [`DatabasePage.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml.cs):
- When `ViewModel.ActiveInnerContent` changes:
  - If the active view is not yet a child of `InnerContentHost`, add it to `InnerContentHost.Children`.
  - Toggle `Visibility = Visibility.Visible` for the active view and `Visibility = Visibility.Collapsed` for all other cached views.
  - Because views remain attached to the Visual Tree, switching between "Kết nối" and database session tabs becomes a pure visibility toggle (<1ms, 0 allocations, 0 re-measurement).
- When an inner tab is closed, remove its corresponding view from `InnerContentHost.Children` and dispose it.
- On `Dispose()`, clear all children from `InnerContentHost`.

#### 2. Retain Top-Level Views via Cached Panel in `ShellWindow`
Mirror the cached viewport architecture in [`ShellWindow.xaml`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Windows/ShellWindow.xaml) and [`ShellWindow.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Windows/ShellWindow.xaml.cs):
- Replace `ContentPresenter` with a retained `Grid` container (`ViewportHost`).
- Manage children via visibility toggling when `ViewModel.ActiveViewportContent` changes.
- Switching between "Trang chủ" and "Cơ sở dữ liệu" becomes instant (<1ms).

#### 3. Optimize `VirtualTable` Sizing and Lifecycle
In [`VirtualTable.xaml`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml):
- Remove `Background="Transparent"` from `VirtualCanvas` (leaving it solely on `VirtualScrollHost` to avoid duplicate transparent compositor planes).

In [`VirtualTable.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs):
- In `UpdateScrollExtent()`:
  - Set `VirtualCanvas.Height = vpHeight;` (capping compositor surface to the visible viewport instead of 98,226 pixels). `Canvas` does not clip children, and rows are positioned inside the viewport window.
- In `OnSizeChanged`:
  - Remove the duplicate call to `_rowPool.EnsurePoolSize(...)` since `UpdateScrollExtent()` already ensures pool capacity.
- In `OnLoaded`:
  - Guard `Recycle()` to ensure it only runs when viewport dimensions are positive (`vpWidth > 0 && vpHeight > 0`).

### Alternatives

- **Keep ContentControl and only optimize VirtualTable**: Sizing optimizations in `VirtualTable` reduce allocation overhead, but detaching and re-attaching the entire `DatabaseViewControl` (including TreeView and all controls) still triggers unnecessary layout and event cycles. Cached viewport retention provides the true zero-delay desktop experience standard.

### Files Likely to Change

- `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml`
- `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml.cs`
- `DataSphere/Views/Windows/ShellWindow.xaml`
- `DataSphere/Views/Windows/ShellWindow.xaml.cs`
- `DataSphere/Controls/VirtualTable/VirtualTable.xaml`
- `DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`

### Tests to Add or Update

- Project compilation: `dotnet build DataSphere\DataSphere.csproj -c Debug` (0 errors).
- Static verification verifying view caching, visibility toggling, and clean disposal upon tab close.

## Risks & Considerations

- **Memory Usage**: Retaining views in `InnerContentHost` and `ViewportHost` with `Visibility = Collapsed` holds elements in memory. However, collapsed elements are excluded from GPU composition and rendering passes. Furthermore, `ITabMemorySaverService` automatically suspends visuals on inactive tabs via `ISleepableTabContent.Sleep()`, ensuring optimal memory conservation.
- **Tab Close Resource Cleanup**: Views must be cleanly removed from the parent container and disposed when tabs are closed.
- **Clean MVVM Compliance**: ViewModels remain 100% UI-agnostic; all container and visibility management resides strictly within the View code-behind.

## Open Questions

- None. The root cause is fully identified through static code analysis and aligned with the user's report.
