# Bug Fix: Primary Key Detection Failure, Column Resize Hit-Testing, and Smooth Wheel Scrolling

- **Slug**: primary-key-detection-column-resize-and-smooth-scroll
- **Fixed**: 2026-10-21
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Implemented automated primary key introspection via `GetPrimaryKeysAsync` and wired it into `DataControlViewModel` so tables with primary keys (such as `admin`) are recognized with in-place cell editing enabled; elevated and expanded column splitters to `ZIndex = 1000` with centered 12px hitboxes and `SizeWestEast` cursors to prevent sort conflict; and added a 60 FPS exponential-easing smooth scroll engine to `VirtualTable` for fluid WinUI 3 mouse wheel scrolling.

## Changes

| File | Change | Notes |
|------|--------|-------|
| [`DataSphere/Services/Database/Interface/IDatabaseConnection.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Services/Database/Interface/IDatabaseConnection.cs) | Modified | Declared `GetPrimaryKeysAsync(databaseName, tableName, cancellationToken)` for schema key resolution. |
| [`DataSphere/Services/Database/Connection/MySqlDatabaseConnection.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Services/Database/Connection/MySqlDatabaseConnection.cs) | Modified | Implemented `GetPrimaryKeysAsync` querying `INFORMATION_SCHEMA.KEY_COLUMN_USAGE` with `CONSTRAINT_NAME = 'PRIMARY'`. |
| [`DataSphere/ViewModels/Pages/DatabaseGroup/DataControlViewModel.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/ViewModels/Pages/DatabaseGroup/DataControlViewModel.cs) | Modified | Added lazy primary key resolution in `LoadPageAsync`; cleared false warning banner when keys exist; enabled in-place editing. |
| [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs) | Modified | Set `Canvas.SetZIndex(splitter, 1000)` and widened hit target to 12px centered on dividers; added 60 FPS `_smoothScrollTimer` with exponential easing (`0.28`) for WinUI 3 fluid wheel scrolling. |

## Diff Highlights

### 1. Primary Key Introspection
```csharp
const string pkQuery = @"
    SELECT COLUMN_NAME
    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
    WHERE TABLE_SCHEMA = @schema AND TABLE_NAME = @table AND CONSTRAINT_NAME = 'PRIMARY'
    ORDER BY ORDINAL_POSITION;";
```

### 2. Splitter Hit-Testing Elevation
```csharp
var splitter = new SplitterHandle
{
    Width = 12,
    Height = 36,
    Background = new SolidColorBrush(Colors.Transparent)
};
splitter.SetCursor(splitterCursor);
Canvas.SetZIndex(splitter, 1000);
Canvas.SetLeft(splitter, left + col.Width - 6);
```

### 3. 60 FPS WinUI 3 Smooth Wheel Scrolling
```csharp
private void OnSmoothScrollTimerTick(object? sender, object e)
{
    double diffY = _targetScrollOffsetY - _scrollOffsetY;
    double diffX = _targetScrollOffsetX - _scrollOffsetX;

    if (Math.Abs(diffY) < 0.5 && Math.Abs(diffX) < 0.5)
    {
        _scrollOffsetY = _targetScrollOffsetY;
        _scrollOffsetX = _targetScrollOffsetX;
        VerticalScrollBar.Value = _scrollOffsetY;
        HorizontalScrollBar.Value = _scrollOffsetX;
        UpdateHeaderScrollTransform();
        Recycle();
        _smoothScrollTimer.Stop();
        return;
    }

    _scrollOffsetY += diffY * 0.28;
    _scrollOffsetX += diffX * 0.28;
    VerticalScrollBar.Value = _scrollOffsetY;
    HorizontalScrollBar.Value = _scrollOffsetX;
    UpdateHeaderScrollTransform();
    Recycle();
}
```

## Tests Added or Updated

- [`scripts/verify-pk-resize-smooth-scroll.ps1`](file:///d:/DEV/C%23DOTNET/DataSphere/scripts/verify-pk-resize-smooth-scroll.ps1): End-to-end automation test executing on `WinSta0\default` to verify that `ngocthamcatalog.admin` loads with primary key `id` recognized, column drag-resizing works without triggering sort, and mouse wheel initiates smooth inertial scrolling.

## Local Verification

- **Compilation**: `dotnet build DataSphere\DataSphere.csproj -c Debug` -> **0 Warning(s), 0 Error(s)**.
- **Primary Key Introspection**: Verified on `ngocthamcatalog.admin`. Warning banner is completely gone, and in-place editing is enabled. Evidence: [`admin_pk_resolved_editable.png`](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/admin_pk_resolved_editable.png).
- **Column Resize Hitbox**: Splitter drag from X=1070 to X=1150 successfully widened column `id` without triggering sort. Evidence: [`column_drag_resized.png`](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/column_drag_resized.png).
- **Smooth Inertial Scrolling**: Viewport smoothly scrolled across rows over multiple 16ms frames via `_smoothScrollTimer`. Evidence: [`smooth_scrolled_rows.png`](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/smooth_scrolled_rows.png).

## Deviations from Assessment

None. All preferred remediations were implemented as specified.

## Follow-ups

- Proceed to test verification and sign-off via `/speckit-bug-test slug=primary-key-detection-column-resize-and-smooth-scroll`.
