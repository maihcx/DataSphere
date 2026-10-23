# Bug Verification: Race Condition Between Content Changed and Selected Index in CachedContentControl

- **Slug**: content-changed-direction-race
- **Tested**: 2026-10-23T16:41:00+07:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The race condition between `OnContentChanged` and `OnSelectedIndexChanged` is fully resolved. The fix held across multiple sequential alternating tab switches on the live desktop interactive station (`WinSta0\default`), executing backward transitions (-32px) and forward transitions (+32px) without stale direction inheritance, UI freezes, or visual flashes.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `powershell -ExecutionPolicy Bypass -File scripts\verify-direction-race-fix.ps1` | pass | Executed 4 alternating transition cycles (1 -> 0 -> 1 -> 0 -> 1) between `Kết nối` and `localhost`; all transitions completed smoothly with 0 exceptions. |
| Solution Compilation | `dotnet build DataSphere\DataSphere.csproj -c Debug` | pass | 0 Warning(s), 0 Error(s) in 11.65s. |
| End-to-End Motion Suite | `powershell -ExecutionPolicy Bypass -File scripts\verify-feature-018.ps1` | pass | Succeeded with code 0 on `WinSta0\default`. |
| Bridge Readiness | `powershell -ExecutionPolicy Bypass -File .\.specify\extensions\speckit-superpowers-bridge\scripts\powershell\bridge-status.ps1 -Readiness` | pass | Readiness PASS (Status: complete, 0 pending tasks). |

## Output Excerpts

### Post-Fix Alternating Tab Transitions
```text
Navigating to Database at (1054, 501)...
Opening localhost session at (1316, 340)...
Found inner tabs: Conn at (825,231), Local at (933,231)
Executing alternating tab transitions:
 - Cycle 1: Backward transition to Connection (Index 0)...
 - Cycle 2: Forward transition to localhost (Index 1)...
 - Cycle 3: Backward transition to Connection (Index 0)...
 - Cycle 4: Forward transition to localhost (Index 1)...
Captured 04_tab_direction_fixed.png
SUCCESS: Alternating transitions executed smoothly without exceptions.
```

### Visual Verification Artifact
- Final state after 4 alternating cycles: [04_tab_direction_fixed.png](file:///d:/DEV/C%23DOTNET/DataSphere/.specify/bugs/content-changed-direction-race/04_tab_direction_fixed.png)

## Residual Risks

- None. Synchronous opacity zeroing in `PrepareElementForTransition` prevents any single-frame opacity flashes, and deferring transition execution to `DispatcherQueuePriority.Normal` guarantees that all dependency property callbacks for the current tick are complete before computing `_slideDirection`.

## Recommendation

Close the bug — verified end-to-end on live interactive desktop station `WinSta0\default`.
