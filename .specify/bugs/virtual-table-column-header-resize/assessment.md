# Bug Assessment: Column Header Splitter Fails to Resize Columns in VirtualTable

- **Slug**: virtual-table-column-header-resize
- **Created**: 2026-10-21
- **Source**: "tôi vẫn chưa thể resize cột ở header (thanh tiêu đề của bảng) của VirtualTable"
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

The user reported that they are still unable to resize columns from the column header (title bar) of `VirtualTable`:
> "tôi vẫn chưa thể resize cột ở header (thanh tiêu đề của bảng) của VirtualTable"

Specifically, hovering over the header column boundaries does not show the resize cursor, and clicking/dragging on the boundaries does not resize the columns.

## Symptom

When hovering over the vertical dividing lines between column headers in `VirtualTable`:
1. The mouse cursor does not change to the standard horizontal resize cursor (`SizeWestEast`).
2. Clicking and dragging on the column boundary fails to resize the column width.
3. Instead of resizing, clicking on the boundary triggers 3-state sorting on the preceding column header (displaying `▲` / `▼`).

## Reproduction

1. Launch DataSphere and connect to `localhost`.
2. Expand `ngocthamcatalog` database, expand `Các bảng`, and open the `admin` table.
3. Hover mouse cursor over the boundary between column header `id` and `mid`.
4. Attempt to click and drag from coordinate `(1077, 350)` to `(1157, 350)`.
5. **Observed Behavior**:
   - Column `id` received a click event and displayed the ascending sort glyph `▲`.
   - The width of column `id` remained unchanged at ~120px.
   - Mouse cursor remained the default arrow cursor.
6. **Expected Behavior**:
   - Hovering over the boundary changes the cursor to `SizeWestEast`.
   - Clicking and dragging dynamically resizes column `id` width in real time without triggering sorting.

### Diagnostic Visual Evidence
- **Screenshot**: [`diagnose_header_splitter_not_resizing.png`](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/diagnose_header_splitter_not_resizing.png)
- **Log Proof**:
  ```text
  Divider target coordinate: (1077, 350)
  Attempting DragAndDrop from (1077, 350) to (1157, 350)...
  Captured header splitter state to: diagnose_header_splitter_not_resizing.png
  After drag 'id' text rect: 950,341,101,18
  ```
  The screenshot clearly shows `id ▲` sorted, while column width did not expand.

## Suspected Code Paths

- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs:984-994`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L984-L994):
  `SplitterHandle` is declared as `private sealed class SplitterHandle : ContentControl`.
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs:360-369`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L360-L369):
  `splitter` is instantiated from `SplitterHandle`, and its `Background` is set to `Transparent`.
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs:407-408`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L407-L408):
  `HeaderCanvas.Children.Add(headerBorder)` and `HeaderCanvas.Children.Add(splitter)` are added in an interleaved loop, allowing column $i+1$'s `headerBorder` to visually overlay the right half of column $i$'s splitter.

## Root Cause Hypothesis

In WinUI 3 (Windows App SDK), elements deriving from `Control` (such as `ContentControl`) do not render visual geometry directly. They rely entirely on their `ControlTemplate`. Because `SplitterHandle` is a custom subclass of `ContentControl` without a template, `ApplyTemplate()` never instantiates a visual tree.

Consequently:
1. `splitter.Background = new SolidColorBrush(Colors.Transparent)` is completely ignored by the DirectComposition rendering engine because there is no border or presenter to bind to it.
2. The compositor registers **zero hit-testable geometry** for `splitter`.
3. When the user moves the mouse over the boundary, hit-testing falls completely through `splitter` to the underlying `headerBorder`.
4. `ProtectedCursor` on `splitter` is never activated (cursor stays default).
5. Mouse clicks hit `headerBorder`, executing `OnHeaderClicked(colIdx)` which sorts the column instead of resizing it.

## Proposed Remediation

### Preferred Solution: Derive `SplitterHandle` from `Grid` (`Panel`)

1. Change `SplitterHandle` inheritance from `ContentControl` to `Grid` (`Microsoft.UI.Xaml.Controls.Grid`):
   ```csharp
   private sealed class SplitterHandle : Grid
   {
       public SplitterHandle()
       {
           Background = new SolidColorBrush(Colors.Transparent);
       }

       public void SetCursor(InputCursor cursor)
       {
           ProtectedCursor = cursor;
       }
   }
   ```
   `Grid` is a `Panel` primitive in WinUI 3. It paints its `Background` directly without requiring any `ControlTemplate`. DirectComposition immediately registers a 12x36 hit-testable surface.
2. In `BuildHeaderElements()`:
   - Add all `headerBorder` elements to `HeaderCanvas` first.
   - Add all `splitter` elements to `HeaderCanvas` second.
   - This ensures all splitters have higher visual tree index and Z-index (`Canvas.SetZIndex(splitter, 2000)` vs `headerBorder` at `10`), completely eliminating any boundary occlusion.
3. In `headerBorder.PointerPressed`:
   - Verify `!_isResizingColumn` before invoking `OnHeaderClicked()`.

### Files likely to change:
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs)

### Tests to add or update:
- Create `scripts/verify-column-header-resize.ps1`:
  - Launch app on `WinSta0\default`, open `admin` table.
  - Hover over divider, perform physical drag-and-drop to resize column 0 by +80px.
  - Assert that column 0 width increases from ~120px to ~200px.
  - Assert that sorting glyph (`▲`/`▼`) is NOT toggled on click.
  - Save visual verification screenshot `winui_column_header_resized.png`.

## Risks & Considerations

- **Hitbox Boundary Precision**: Hitbox width of 12px provides a generous ±6px target around the 1px border line, making it easy for users to grab without interfering with header text clicks.
- **Header Culling Compatibility**: When `CullHeaders()` runs during horizontal scrolling, both `_headerBorders[i]` and `_headerSplitters[i]` will continue to be shown/hidden synchronously.
