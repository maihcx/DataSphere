# Bug Fix: Unhandled COMException (0x800F1000) When Tearing Off Tab to New Window

- **Slug**: tab-tearoff-new-window-crash
- **Date**: 2026-10-24T01:56:00+07:00
- **Status**: applied
- **Assessment**: [assessment.md](./assessment.md)

## Summary of Changes

Fixed the unhandled `System.Runtime.InteropServices.COMException: 'No installed components were detected.'` (HRESULT `0x800F1000`) that occurred whenever a user dragged an open tab outside the application window to tear it off into a new independent window.

Key implementations:
1. **Parent Disconnect Guard in `CachedContentControl`**:
   - Added `EnsureDisconnectedFromOtherParent(UIElement element)` and `DisconnectFromParent(UIElement? element)`.
   - Before attempting `Children.Add(element)` in `CachedContentControl.UpdateActiveContent`, checks if `VisualTreeHelper.GetParent(element)` or `element.Parent` belongs to another container (such as a donor window's viewport).
   - If an existing parent exists, cleanly detaches `element` from `oldParent.Children` (or resets `Content` / `Child` for `ContentControl` / `Border`), freeing the element to be adopted by the new window's visual tree and `XamlRoot`.
   - Wrapped `Children.Add(element)` in defensive exception handling with diagnostic logging to prevent unexpected process crashes.
2. **Explicit Disconnection During Tear-Off in `ShellWindow.xaml.cs`**:
   - In `OnTabDroppedOutside`, explicitly invoked `CachedContentControl.DisconnectFromParent(tabModel.Content as UIElement)` on the donor side prior to handing the tab over to `_windowManager.TearOffTabToNewWindow`.
3. **Explicit Disconnection in `WindowManager.cs`**:
   - In `TearOffTabToNewWindow` and `TransferTab`, added `CachedContentControl.DisconnectFromParent(tab.Content as UIElement)` calls to guarantee that both tear-offs and cross-window tab docking transfers never attempt to insert an element while it remains registered in another window's visual tree.

## Changed Files

- `DataSphere/Controls/CachedContentControl.cs`:
  - Added `DisconnectFromParent(UIElement? element)` public helper method.
  - Added `EnsureDisconnectedFromOtherParent(UIElement element)` private guard.
  - Updated `UpdateActiveContent` to call `EnsureDisconnectedFromOtherParent` and wrapped `Children.Add` in defensive try/catch.
- `DataSphere/Views/Windows/ShellWindow.xaml.cs`:
  - Added `CachedContentControl.DisconnectFromParent(tabModel.Content as UIElement)` in `OnTabDroppedOutside`.
- `DataSphere/Services/WindowManager.cs`:
  - Added `CachedContentControl.DisconnectFromParent(tab.Content as UIElement)` in `TearOffTabToNewWindow` and `TransferTab`.
- `scripts/reproduce-tab-tearoff-crash.ps1`:
  - Automated UI Automation script verifying tab tear-off without crash on real desktop `WinSta0\default`.

## Deviations from Assessment

None. The remediation directly implemented the proposed architecture.

## Verification Results

### 1. Build Verification
- Command: `dotnet build DataSphere\DataSphere.csproj -c Debug`
- Result: **Build succeeded with 0 Warnings, 0 Errors**.

### 2. Live Desktop Automation Verification (`WinSta0\default`)
- Command: `powershell -ExecutionPolicy Bypass -File scripts\reproduce-tab-tearoff-crash.ps1`
- Flow:
  1. Launched DataSphere PID 28296 on `WinSta0\default`.
  2. Opened Databases tab (`TabItems.Count = 3`).
  3. Dragged Tab 1 ("Cơ sở dữ liệu") from `(1171, 697)` upwards outside the window to `(1171, 525)`.
  4. Observed process state and window count:
     - **Before Fix**: Process crashed immediately with APPCRASH `0x800F1000` (`Windows count: 0`).
     - **After Fix**: Process 28296 is still running; `Windows count for process: 2`.
  5. Both windows successfully captured (`step2_after_drag_window0.png` and `step2_after_drag_window1.png`).
  6. Verified Windows Event Log: 0 crashes logged.
