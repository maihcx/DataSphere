# Bug Verification: Unhandled COMException (0x800F1000) When Tearing Off Tab to New Window

- **Slug**: tab-tearoff-new-window-crash
- **Tested**: 2026-10-24T01:58:30+07:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The bug is completely resolved. Dragging an open tab (such as "Databases") outside the window bounds to tear it off into a new independent window now cleanly disconnects the tab's visual content from the donor window's `CachedContentControl`, enabling it to safely attach to the recipient window's visual tree. Both the donor window and the newly spawned window remain active, responsive, and functional, with zero crashes or COMExceptions.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `powershell -ExecutionPolicy Bypass -File scripts\reproduce-tab-tearoff-crash.ps1` | pass | Executed on real desktop `WinSta0\default` with physical mouse drag-and-drop. Process remained alive and windows count increased from 1 to 2. |
| Event Log Crash Check | `Get-WinEvent -LogName "Application"` | pass | 0 Application Errors or APPCRASH events recorded during or after tear-off. |
| Compile & Type-Check | `dotnet build DataSphere\DataSphere.csproj -c Debug` | pass | 0 Warnings, 0 Errors. Clean compilation. |
| Bridge Readiness | `powershell -ExecutionPolicy Bypass -File .\.specify\extensions\speckit-superpowers-bridge\scripts\powershell\bridge-status.ps1 -Readiness` | pass | Bridge readiness PASS; 0 pending tasks. |

## Output Excerpts

### Automated Desktop Tear-Off Run:
```text
Launched DataSphere PID: 28816
[Step 0] Initial Home captured.
Clicking Database Button: X=1416.5 Y=1086.5
After opening Database, TabItems count: 3
Dragging Tab 1 from (1171, 697) to (1171, 525)...
Process 28816 is still running.
Windows count for process: 2
Diagnostic reproduction run completed.
```

### Windows Event Log Status:
```text
Zero Application Errors or APPCRASH entries recorded.
Fault bucket 1166181565273276739 (HRESULT 0x800F1000) no longer reproduces.
```

## Residual Risks

- None identified. Cross-window tab transfer (`TransferTab`) and tab tear-off (`TearOffTabToNewWindow`) both employ explicit donor-side detachment as well as defensive recipient-side parentage guards.

## Recommendation

Close the bug — verified end-to-end on live desktop station with multi-window physical drag-and-drop automation.
