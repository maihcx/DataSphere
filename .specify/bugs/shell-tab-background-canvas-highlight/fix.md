# Bug Fix: ShellTabBackgroundCanvas Missing Tab Highlight After Closing All Tabs and Reopening

- **Slug**: shell-tab-background-canvas-highlight
- **Fixed**: 2026-10-24T00:09:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Fixed an issue where closing all dynamic tabs and reopening a new tab caused the fluent highlight capsule (`ShellTabCapsule` / `InnerTabCapsule`) to vanish off-screen (positioned at `X = -14952px`). The root cause was that `FindActiveTabViewItem` accepted recycled/unloaded `TabViewItem` containers retained in the visual tree by WinUI 3 with off-screen coordinates and stale `IsSelected == true` flags. The fix introduces `IsValidOnScreenTabItem` to reject off-screen / recycled containers, validates data-context matching, and extends container resolution retry priority to reliably await container realization and measurement.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Controls/SlidingTabIndicatorBehavior.cs` | modified | Added `IsValidOnScreenTabItem` validation (checking bounds, visibility, and data model matching), improved `FindActiveTabViewItem` to reject off-screen/recycled containers, and elevated initial retries to `DispatcherQueuePriority.Normal` up to 10 retries. |
| `scripts/reproduce-tab-highlight-bug.ps1` | added | Automation verification script for physical reproduction and DirectComposition screenshot capturing on `WinSta0\default`. |
| `.specify/bugs/shell-tab-background-canvas-highlight/step5_new_tab_verified_fixed.png` | added | Visual DirectComposition screenshot proving highlight capsule is correctly positioned and visible on Tab 1. |

## Diff Highlights (optional)

```csharp
private static bool IsValidOnScreenTabItem(TabView tabView, TabViewItem item, object? expectedItem)
{
    if (!item.IsLoaded || item.Visibility != Visibility.Visible || item.ActualWidth <= 4.0f)
    {
        return false;
    }

    try
    {
        GeneralTransform transform = item.TransformToVisual(tabView);
        Point pt = transform.TransformPoint(new Point(0, 0));

        // Discard off-screen or recycled items that WinUI virtualizes far away (e.g. at X = -14952)
        if (pt.X < -50 || pt.X > tabView.ActualWidth + 500 || pt.Y < -50 || pt.Y > tabView.ActualHeight + 500)
        {
            return false;
        }
    }
    catch
    {
        return false;
    }

    if (expectedItem != null)
    {
        if (Equals(item, expectedItem) ||
            Equals(item.DataContext, expectedItem) ||
            Equals(item.Content, expectedItem))
        {
            return true;
        }

        if (expectedItem is TabItemModel model)
        {
            if (item.DataContext is TabItemModel itemModel && Equals(itemModel, model))
            {
                return true;
            }

            if (item.Header is string headerStr && !string.IsNullOrEmpty(headerStr))
            {
                if (headerStr == model.Title || (!string.IsNullOrEmpty(model.TitleKey) && headerStr == model.TitleKey))
                {
                    return true;
                }
            }
        }

        return false;
    }

    return item.IsSelected;
}
```

## Tests Added or Updated

- `scripts/reproduce-tab-highlight-bug.ps1` — Real desktop automation test (`WinSta0\default`) executing:
  1. Launch app on `WinSta0\default`.
  2. Open "Cơ sở dữ liệu" tab from Home dashboard.
  3. Return to Home tab.
  4. Open "Cài đặt" tab from Home dashboard.
  5. Close dynamic tabs sequentially from right to left until all dynamic tabs are closed and Home is selected.
  6. Open a new dynamic tab from Home dashboard.
  7. Verify DirectComposition capture proves the newly opened tab possesses the Fluent capsule card highlight (`R=244..245, G=244, B=244`).

## Local Verification

- **Build**: `dotnet build DataSphere\DataSphere.csproj -c Debug` → 0 Warning(s), 0 Error(s).
- **Physical UI Automation on Real Desktop (`WinSta0\default`)**:
  - Full automated sequence executed without crashes.
  - Pixel inspection on `step5_new_tab_verified_fixed.png`:
    - Tab 1 header region (X=80..240, Y=10..40): `R=244..245, G=244, B=244` matching exact `CardBackgroundFillColorDefaultBrush` capsule background.
    - 100% identical highlight signature to original Step 1.
    - Zero white pixels on unselected Home tab, full highlight card active on newly created Tab 1.

## Deviations from Assessment

- In the initial assessment, the delayed container realization was hypothesized to simply expire the 4 low-priority retries. Live diagnostic instrumentation revealed that WinUI 3 retains recycled/disposed tab containers in an off-screen cache located at `X = -14952px, Y = -15011px` with `IsSelected == true`. `FindActiveTabViewItem` matched this off-screen phantom element, causing `ShellTabCapsule` to animate 15,000 pixels off screen instead of retrying. The fix handles both container realization delays and phantom element rejection.

## Follow-ups

- None required. Both `ShellTabView` and `InnerTabView` share `SlidingTabIndicatorBehavior` and inherit the fix automatically.
