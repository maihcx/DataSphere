# Bug Fix: Tab Motion Direction Inversion and Accent Indicator Visibility Flag

- **Slug**: tab-motion-direction-and-indicator-flag
- **Fixed**: 2026-10-23T16:03:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Added an attached configuration flag `IsIndicatorVisible` (defaulting to `false`) to cleanly hide the bottom accent indicator pill while preserving the hardware-accelerated sliding background capsule motion, and corrected the viewport horizontal entrance animation in `CachedContentControl` so that forward navigation (low to high index) reliably enters from the right (`+32px`) and backward navigation (high to low index) reliably enters from the left (`-32px`).

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Controls/TabMotionConfiguration.cs` | modified | Added `IsIndicatorVisible = false` static configuration flag |
| `DataSphere/Controls/SlidingTabIndicatorBehavior.cs` | modified | Added `IsIndicatorVisibleProperty` attached property; conditionally hides `indicatorVisual` while maintaining background capsule glide |
| `DataSphere/Controls/CachedContentControl.cs` | modified | Replaced fragile `_lastSelectedIndex` mutation with robust `_slideDirection` tracking in `OnSelectedIndexChanged`; guarantees deterministic ±32px directional slide |
| `DataSphere/ViewModels/Windows/ShellViewModel.cs` | modified | Reordered property notification sequence to ensure `EffectiveTabIndex` is updated before `ActiveViewportContent` |
| `DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseViewModel.cs` | modified | Reordered property notification sequence to ensure `EffectiveTabIndex` is updated before `ActiveInnerContent` |

## Diff Highlights

### CachedContentControl.cs
```csharp
private int _slideDirection = 1;
private int _lastSelectedIndex = -1;

private static void OnSelectedIndexChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
{
    if (d is CachedContentControl control && e.NewValue is int newIdx && e.OldValue is int oldIdx)
    {
        if (oldIdx >= 0 && newIdx >= 0 && oldIdx != newIdx)
        {
            control._slideDirection = newIdx > oldIdx ? 1 : -1;
        }
        control._lastSelectedIndex = oldIdx;
    }
}

// In UpdateActiveContent:
float offsetX = _slideDirection >= 0
    ? TabMotionConfiguration.EntranceOffsetX
    : -TabMotionConfiguration.EntranceOffsetX;
```

### SlidingTabIndicatorBehavior.cs
```csharp
public static readonly DependencyProperty IsIndicatorVisibleProperty =
    DependencyProperty.RegisterAttached(
        "IsIndicatorVisible",
        typeof(bool),
        typeof(SlidingTabIndicatorBehavior),
        new PropertyMetadata(TabMotionConfiguration.IsIndicatorVisible, OnIsIndicatorVisibleChanged));

// In UpdateVisualsPosition:
bool isIndicatorVisible = GetIsIndicatorVisible(tabView);
indicator.IsVisible = isIndicatorVisible;
if (isIndicatorVisible)
{
    // Animate pill indicator
}
// Animate background capsule (always executed regardless of pill visibility)
```

## Local Verification

- Build compilation: `dotnet build DataSphere\DataSphere.csproj -c Debug` → Succeeded (0 Errors, 0 Warnings).
- UI Automation testing on interactive station `WinSta0\default` (`scripts/verify-feature-018.ps1`) → Succeeded (PID: 12952, exit code 0).
- Visual evidence: The indicator is suppressed by default, the selected capsule glides between tabs smoothly, and directional content slide enters from the right for forward navigation and from the left for backward navigation.

## Deviations from Assessment

None. The implementation followed the preferred remediation outlined in the assessment exactly.

## Follow-ups

- Run `/speckit-bug-test slug=tab-motion-direction-and-indicator-flag` to record final automated validation.
