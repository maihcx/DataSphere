# Bug Fix: Column Header Layer Horizontal Shift-Scroll DirectComposition 144Hz Synchronization

- **Slug**: column-header-shift-scroll-smoothness
- **Fixed**: 2026-10-21T14:01:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Khắc phục triệt để hiện tượng giật cục 60fps và lệch pha thị giác giữa Column Header Layer và Table Viewport khi cuộn ngang bằng chuột (`Shift + Scroll`) trên màn hình tần số quét cao (144Hz) bằng cách tích hợp cơ chế cuộn chuẩn của WinUI 3: Windows DirectComposition ExpressionAnimation (`Microsoft.UI.Xaml.Hosting.ElementCompositionPreview`) và bộ tích lũy delta cuộn mượt (Target Offset Accumulation).

## Changes

| File | Change | Notes |
|------|--------|-------|
| [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs) | modified | Thêm `SetupHeaderCompositorSync()` liên kết `HeaderCanvas.Offset.X` trực tiếp với `ScrollViewerManipulationPropertySet.Translation.X` trên GPU Compositor thread. Bỏ qua UI-thread `TranslateTransform` khi Compositor sync active. Thêm cơ chế tích lũy `_accumulatedTargetScrollX` cho Shift+Wheel. |

## Diff Highlights

### 1. DirectComposition ExpressionAnimation Linking (Compositor Thread):
```csharp
private void SetupHeaderCompositorSync()
{
    if (_isCompositorSyncConfigured || TableScrollViewer == null || HeaderCanvas == null) return;

    try
    {
        var scrollPropSet = ElementCompositionPreview.GetScrollViewerManipulationPropertySet(TableScrollViewer);
        if (scrollPropSet == null) return;

        var compositor = scrollPropSet.Compositor;
        var headerVisual = ElementCompositionPreview.GetElementVisual(HeaderCanvas);
        if (headerVisual == null) return;

        // Animate HeaderCanvas.Offset.X directly linked to the ScrollViewer Manipulation PropertySet on the Compositor thread
        var expr = compositor.CreateExpressionAnimation("scrollPropSet.Translation.X");
        expr.SetReferenceParameter("scrollPropSet", scrollPropSet);
        headerVisual.StartAnimation("Offset.X", expr);

        HeaderCanvas.RenderTransform = null;
        _isCompositorSyncConfigured = true;
    }
    catch (Exception ex)
    {
        System.Diagnostics.Debug.WriteLine($"Failed to configure compositor header sync: {ex.Message}");
    }
}
```

### 2. Smooth Target Accumulation for Shift + Mouse Wheel:
```csharp
bool isShift = (InputKeyboardSource.GetKeyStateForCurrentThread(VirtualKey.Shift) & CoreVirtualKeyStates.Down) == CoreVirtualKeyStates.Down;
if (isShift)
{
    int delta = props.MouseWheelDelta;
    if (delta != 0)
    {
        double vpWidth = TableScrollViewer.ViewportWidth > 0 ? TableScrollViewer.ViewportWidth : TableScrollViewer.ActualWidth;
        double maxScrollX = Math.Max(0, VirtualScrollHost.Width - vpWidth);
        if (maxScrollX > 0)
        {
            var now = DateTime.UtcNow;
            double baseOffset = (_accumulatedTargetScrollX.HasValue && (now - _lastHorizontalWheelTime).TotalMilliseconds < 350)
                ? _accumulatedTargetScrollX.Value
                : TableScrollViewer.HorizontalOffset;

            double step = (delta / 120.0) * 150.0;
            double targetX = Math.Clamp(baseOffset - step, 0, maxScrollX);
            _accumulatedTargetScrollX = targetX;
            _lastHorizontalWheelTime = now;

            TableScrollViewer.ChangeView(targetX, null, null, disableAnimation: false);
        }
        e.Handled = true;
    }
}
```

## Tests Added or Updated

- [`scripts/verify-header-compositor-sync.ps1`](file:///d:/DEV/C%23DOTNET/DataSphere/scripts/verify-header-compositor-sync.ps1): Kiểm tra tự động hóa thao tác cuộn ngang Shift + Wheel trên desktop thật (`WinSta0\default`), kiểm tra tính đồng bộ của Header và Table Viewport, kiểm tra click sort cột khi đang cuộn ngang.

## Local Verification

- **Biên dịch**: `dotnet build DataSphere\DataSphere.csproj -c Debug` → **0 Warning(s), 0 Error(s)**.
- **Kiểm định UI Automation thực tế (`WinSta0\default`)**:
  - `scripts/verify-header-compositor-sync.ps1` → **ALL DIRECTCOMPOSITION HEADER SYNCHRONIZATION TESTS PASSED!**
  - Bằng chứng hình ảnh DirectComposition:
    - Cuộn ngang đồng bộ: [`winui_compositor_header_scrolled.png`](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/winui_compositor_header_scrolled.png)
    - Sắp xếp cột sau khi cuộn: [`winui_compositor_header_sorted.png`](file:///C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/winui_compositor_header_sorted.png)

## Deviations from Assessment

Không có sai lệch so với giải pháp đề xuất trong assessment.

## Follow-ups

- Chạy kiểm thử nghiệm thu bug thông qua `/speckit-bug-test slug=column-header-shift-scroll-smoothness`.
