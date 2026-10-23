# Bug Fix: Race Condition Between Content Changed and Selected Index in CachedContentControl

- **Slug**: content-changed-direction-race
- **Fixed**: 2026-10-23T16:37:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Resolved the timing race condition where `OnContentChanged` executed prior to `OnSelectedIndexChanged` by deferring entrance transition animation dispatching to `DispatcherQueue` (with pre-emptive opacity initialization to eliminate visual flash), and added missing `EffectiveTabIndex` property change notifications in `ShellViewModel` and `DatabaseViewModel`.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Controls/CachedContentControl.cs` | modified | Added internal `_lastSelectedIndex` tracking fallback in `OnSelectedIndexChanged`, introduced `PrepareElementForTransition` to pre-initialize compositor opacity to 0.0f, and deferred `PlayEntranceTransition` execution via `DispatcherQueue.TryEnqueue(Normal, ...)` so `_slideDirection` is guaranteed fresh when computed. |
| `DataSphere/ViewModels/Windows/ShellViewModel.cs` | modified | Added missing `OnPropertyChanged(nameof(EffectiveTabIndex))` calls inside `_tabService.PropertyChanged` listener, `UpdateHomeState()`, `CloseTab()`, and `SelectTab()`. |
| `DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseViewModel.cs` | modified | Added missing `OnPropertyChanged(nameof(EffectiveTabIndex))` call inside `SelectConnection()`. |

## Diff Highlights

### CachedContentControl.cs
```csharp
// In UpdateActiveContent:
PrepareElementForTransition(element);

void RunTransition()
{
    if (element.Visibility == Visibility.Visible && IsTransitionEnabled && TabMotionConfiguration.AreAnimationsEnabled)
    {
        float offsetX = _slideDirection >= 0
            ? TabMotionConfiguration.EntranceOffsetX
            : -TabMotionConfiguration.EntranceOffsetX;
        ...
        PlayEntranceTransition(element, offsetX);
    }
}

if (DispatcherQueue != null)
{
    DispatcherQueue.TryEnqueue(Microsoft.UI.Dispatching.DispatcherQueuePriority.Normal, RunTransition);
}
else
{
    RunTransition();
}
```

### ShellViewModel.cs & DatabaseViewModel.cs
```csharp
// ShellViewModel.cs:
_tabService.PropertyChanged += (sender, e) =>
{
    if (e.PropertyName == nameof(ITabService.SelectedTab))
    {
        ...
        OnPropertyChanged(nameof(SelectedTab));
        OnPropertyChanged(nameof(EffectiveTabIndex)); // Added
        OnPropertyChanged(nameof(ActiveViewportContent));
    }
};

// DatabaseViewModel.cs:
[RelayCommand]
public void SelectConnection()
{
    IsConnectionSelected = true;
    SelectedInnerTab = null;
    OnPropertyChanged(nameof(EffectiveTabIndex)); // Added
    OnPropertyChanged(nameof(ActiveInnerContent));
}
```

## Tests Added or Updated

- `scripts/diagnose-direction-race.ps1` — UI automation script for interactive desktop `WinSta0\default` to inspect tab hierarchy and capture element diagnostics.
- `scripts/verify-feature-018.ps1` — End-to-end live verification exercising alternating tab selections (`localhost` <-> `Kết nối`) and capturing full DirectComposition window screenshots.

## Local Verification

- Commands run:
  - `dotnet build DataSphere\DataSphere.csproj -c Debug` → Build succeeded with 0 Warning(s) and 0 Error(s) (11.65s).
  - `powershell -ExecutionPolicy Bypass -File scripts\verify-feature-018.ps1` → Succeeded with code 0 on `WinSta0\default`, successfully executing tab selections and capturing window frames without crashing or glitching.
  - `bridge-status.ps1 -Readiness` → Readiness PASS.
- Manual checks:
  - Validated that `_slideDirection` is evaluated after all synchronous dependency property updates in the UI thread pass.
  - Validated that `PrepareElementForTransition` prevents single-frame flashes before the queued transition starts.

## Deviations from Assessment

None. The implementation followed the preferred remediation outlined in `assessment.md`.

## Follow-ups

- Proceed to `/speckit-bug-test slug=content-changed-direction-race` to record formal test verification results.
