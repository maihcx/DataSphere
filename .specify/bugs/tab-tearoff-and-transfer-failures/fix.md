# Bug Fix: Multi-Window Tab Tear-Off Auto-Close and Cross-Window Tab Docking Vanishing Failures

- **Slug**: tab-tearoff-and-transfer-failures
- **Fixed**: 2026-10-20T10:07:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Eliminated erroneous donor window closure during tab tear-off to desktop, guarded the primary window from ever auto-closing, and fixed cross-window tab docking by updating the presentation ViewModels synchronously on the UI thread during tab transfers.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Models/WindowSession.cs` | modified | Added invariant `if (IsPrimary) return false;` to `CanAutoCloseOnTransfer()` so the primary window never closes on transfer. |
| `DataSphere/Views/Windows/ShellWindow.xaml.cs` | modified | Removed `shouldCloseDonor` check and `Close()` call from `OnTabDroppedOutside`, ensuring donor windows stay open on tear-off; switched selection prior to tab removal. |
| `DataSphere/Services/WindowManager.cs` | modified | Reused existing `ShellWindow.Session` in `TearOffTabToNewWindow` to avoid duplicate registrations; dispatched tab removal and insertion directly to `donorWindow.ViewModel.Tabs` and `targetWindow.ViewModel.Tabs` in `TransferTab`. |
| `scratch/VerifyTabTransfer/Program.cs` | added | Headless verification suite testing primary/secondary window auto-close invariants and cross-window tab transfer mechanics. |

## Diff Highlights

### 1. `DataSphere/Models/WindowSession.cs`
```csharp
public bool CanAutoCloseOnTransfer()
{
    if (IsPrimary)
    {
        return false;
    }

    return Tabs.Count <= 1 || (Tabs.Count == 2 && Tabs.Any(t => !t.IsClosable));
}
```

### 2. `DataSphere/Views/Windows/ShellWindow.xaml.cs`
```csharp
private void OnTabDroppedOutside(TabView sender, TabViewTabDroppedOutsideEventArgs args)
{
    if (args.Item is TabItemModel tabModel && tabModel.IsClosable)
    {
        if (Equals(ViewModel.SelectedTab, tabModel))
        {
            int index = ViewModel.Tabs.IndexOf(tabModel);
            int fallbackIndex = Math.Max(0, index - 1);
            ViewModel.Tabs.Remove(tabModel);
            if (ViewModel.Tabs.Count > 0)
            {
                ViewModel.SelectedTab = ViewModel.Tabs[Math.Min(fallbackIndex, ViewModel.Tabs.Count - 1)];
            }
        }
        else
        {
            ViewModel.Tabs.Remove(tabModel);
        }

        var cursorPos = SimpleCursorPosition.GetCursorPos();
        var screenPoint = new Point(cursorPos.X, cursorPos.Y);

        _windowManager.TearOffTabToNewWindow(tabModel, screenPoint);
    }
}
```

### 3. `DataSphere/Services/WindowManager.cs`
```csharp
// 1. Remove from source window ViewModel
if (donorWindow != null)
{
    ExecuteOnUi(donorWindow, () =>
    {
        if (Equals(donorWindow.ViewModel.SelectedTab, tab))
        {
            int currentIndex = donorWindow.ViewModel.Tabs.IndexOf(tab);
            int fallbackIndex = Math.Max(0, currentIndex - 1);
            donorWindow.ViewModel.Tabs.Remove(tab);
            if (donorWindow.ViewModel.Tabs.Count > 0)
            {
                donorWindow.ViewModel.SelectedTab = donorWindow.ViewModel.Tabs[Math.Min(fallbackIndex, donorWindow.ViewModel.Tabs.Count - 1)];
            }
        }
        else
        {
            donorWindow.ViewModel.Tabs.Remove(tab);
        }
    });
}

// 2. Insert into target window ViewModel
if (targetWindow != null)
{
    ExecuteOnUi(targetWindow, () =>
    {
        int insertIndex = Math.Clamp(targetIndex, 0, targetWindow.ViewModel.Tabs.Count);
        targetWindow.ViewModel.Tabs.Insert(insertIndex, tab);
        targetWindow.ViewModel.SelectedTab = tab;
        tab.State = TabLifecycleState.Active;
        targetWindow.Activate();
    });
}
```

## Tests Added or Updated

- `scratch/VerifyTabTransfer/Program.cs`:
  - `Test 1-2`: Confirms primary window with 2 tabs or 1 tab never auto-closes (`!CanAutoCloseOnTransfer()`).
  - `Test 3-5`: Confirms secondary window with 2 tabs auto-closes, with 3 tabs remains open, and with 1 tab remaining auto-closes.
  - `Test 6-11`: Confirms cross-window tab transfer moves tab from secondary window to primary window, adds to target collection, removes from source collection, sets active selection, and triggers donor auto-close.
  - `Test 12-13`: Confirms transfer from primary window to secondary window preserves primary window.

## Local Verification

- Build: `dotnet build DataSphere\DataSphere.csproj -c Debug` → 0 warnings, 0 errors.
- Verification Suite: `dotnet run --project scratch\VerifyTabTransfer\VerifyTabTransfer.csproj` → 13 passed, 0 failed.
- Regression Suite: `dotnet run --project scratch\VerifyConnectionStorage\VerifyConnectionStorage.csproj` → 14 passed, 0 failed.

## Deviations from Assessment

None. The remediation followed the assessment plan precisely, with the added refinement of safely updating `SelectedTab` to a fallback index before removing the active tab to ensure clean visual tree detachment.

## Follow-ups

- Proceed to `/speckit-bug-test slug=tab-tearoff-and-transfer-failures` to record final verification evidence.
