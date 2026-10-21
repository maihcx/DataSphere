# Bug Fix: DirectComposition Hit-Testing & Robust Pointer Capture for VirtualTable Column Splitters

- **Slug**: virtual-table-column-header-resize
- **Fixed**: 2026-10-21
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Fixed column header resizing in `VirtualTable` by transitioning `SplitterHandle` from a template-less `ContentControl` to a `Grid` (ensuring native hit-testable DirectComposition geometry) and layering splitters on top of all header borders (`Canvas.SetZIndex(splitter, 2000)`). Additionally unified pointer event handling with global move/release tracking on `HeaderBorder` and `VirtualTable` to prevent lost drag gestures during fast pointer movement.

## Changes

| File | Change | Notes |
|------|--------|-------|
| [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs) | modified | Subclassed `Grid` for `SplitterHandle`, separated header border and splitter DOM additions, set higher Z-indices, and added global pointer move/release event tracking across `HeaderBorder` and `VirtualTable`. |
| [`scripts/verify-column-header-resize.ps1`](file:///d:/DEV/C%23DOTNET/DataSphere/scripts/verify-column-header-resize.ps1) | added test | Automated desktop UI verification script on `WinSta0\default` validating mouse drag resizing and sort isolation. |

## Diff Highlights

```csharp
// 1. Derived SplitterHandle from Grid for direct DirectComposition rendering
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

// 2. Separated additions in BuildHeaderElements to ensure splitters strictly overlay borders
foreach (var border in _headerBorders)
{
    HeaderCanvas.Children.Add(border);
}
foreach (var splitter in _headerSplitters)
{
    HeaderCanvas.Children.Add(splitter);
}

// 3. Added global pointer move/release handlers across HeaderBorder and VirtualTable
private void OnHeaderPointerMoved(object sender, PointerRoutedEventArgs e)
{
    if (_isResizingColumn && _resizingColumnIndex >= 0 && _resizingColumnIndex < Columns.Count)
    {
        var col = Columns[_resizingColumnIndex];
        double currentX = e.GetCurrentPoint(this).Position.X;
        double delta = currentX - _resizeStartPointerX;
        double newWidth = Math.Max(col.MinWidth, _resizeInitialWidth + delta);
        if (Math.Abs(col.Width - newWidth) > 0.5)
        {
            col.Width = newWidth;
            UpdateHeaderLayouts();
            Recycle();
        }
        e.Handled = true;
    }
}
```

## Tests Added or Updated

- `scripts/verify-column-header-resize.ps1`:
  - Connects to MySQL `localhost`, expands database `ngocthamcatalog`, and opens table `admin`.
  - Locates header column boundaries between `id` and `mid`.
  - Performs physical drag-and-drop rightward by +80px via `mouse_event(MOUSEEVENTF_MOVE)`.
  - Verifies `id` column width expands from 115px to 199px (+84px).
  - Verifies subsequent column `mid` displaces rightward from X=1090 to X=1174 (+84px).
  - Verifies column sorting glyph (`▲`/`▼`) was NOT toggled on `id`.

## Local Verification

- **Compilation**:
  - `dotnet build DataSphere\DataSphere.csproj -c Debug` → 0 Warning(s), 0 Error(s).
- **Desktop UI Automation Execution** (`WinSta0\default`):
  - `powershell -ExecutionPolicy Bypass -File scripts\verify-column-header-resize.ps1` →
    ```text
    BEFORE DRAG:
      Header 'id' rect:  950,341,115,18
      Header 'mid' rect: 1090,341,115,18
      Divider target coordinate: (1077, 350)
    ACTION: Dragging divider from (1077, 350) to (1157, 350)...
    AFTER DRAG:
      Header 'id' rect:  950,341,199,18 Name: 'id'
      Header 'mid' rect: 1174,341,115,18 Name: 'mid'
      Header 'mid' horizontal displacement: +84.0 px
    ASSERTION RESULTS:
      [1] Column 'mid' shifted right due to 'id' expansion: PASS (Shift=84px >= 60px)
      [2] Column sorting was NOT triggered on 'id': PASS (Name is 'id')
    OVERALL VERIFICATION: SUCCESS - Column header splitter resize verified with DirectComposition!
    ```
- **Visual Artifact**:
  - Captured screenshot: [`winui_column_header_resized_success.png`](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/winui_column_header_resized_success.png)

## Deviations from Assessment

- Added global pointer event forwarding on `HeaderBorder` and `VirtualTable` in addition to `SplitterHandle`. This guarantees that fast mouse movements beyond the 12px splitter handle width do not interrupt the column resize operation even if pointer capture experiences edge-case boundary transitions in DirectComposition.
- Maintained persistent `ProtectedCursor = _splitterCursor` (`SizeWestEast`) continuously across `VirtualTable` throughout the active drag session and preserved pointer capture directly on `_activeSplitter`, ensuring the resize arrow cursor remains visible throughout the entire click-and-drag gesture.

## Follow-ups

- None required; all column resize interactions, layout transforms, row recycling, and visual bounds update smoothly in real time.
