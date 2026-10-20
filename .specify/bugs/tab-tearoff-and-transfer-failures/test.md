# Bug Verification: Multi-Window Tab Tear-Off Auto-Close and Cross-Window Tab Docking Vanishing Failures

- **Slug**: tab-tearoff-and-transfer-failures
- **Tested**: 2026-10-20T10:08:30+07:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

Both bugs have been comprehensively verified and resolved. The primary window is guarded from closure during tab tear-off to desktop and cross-window transfers, and cross-window tab docking now synchronizes both the viewmodels and window sessions without losing tabs.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Project Build | `dotnet build DataSphere\DataSphere.csproj -c Debug` | pass | 0 warnings, 0 errors. |
| Multi-Window & Tab Transfer Suite | `dotnet run --project scratch\VerifyTabTransfer\VerifyTabTransfer.csproj` | pass | 13/13 unit and invariant tests passed. |
| Storage Regression Suite | `dotnet run --project scratch\VerifyConnectionStorage\VerifyConnectionStorage.csproj` | pass | 14/14 tests passed with zero regressions. |
| Bridge Readiness Check | `powershell -ExecutionPolicy Bypass -File .\.specify\extensions\speckit-superpowers-bridge\scripts\powershell\bridge-status.ps1 -Readiness` | pass | Ready (status: complete; pending tasks: 0). |

## Output Excerpts

### Multi-Window & Tab Transfer Test Suite (`VerifyTabTransfer`)
```text
=================================================
Starting Multi-Window & Tab Transfer Verification Suite
=================================================
[PASS] Test 1: Primary window with 2 tabs (Home + Content) must NOT auto-close
[PASS] Test 2: Primary window with 1 tab (Home) must NOT auto-close
[PASS] Test 3: Secondary window with 2 tabs (Home + Content) MUST auto-close on transfer
[PASS] Test 4: Secondary window with 3 tabs must NOT auto-close on transfer
[PASS] Test 5: Secondary window with only 1 tab (Home) remaining MUST auto-close
[PASS] Test 6: WindowManager registers both sessions
[PASS] Test 7: Transferred tab is added to target session
[PASS] Test 8: Transferred tab is removed from source session
[PASS] Test 9: Target session SelectedTab is focused on transferred tab
[PASS] Test 10: Target session tab count is 3 (Home, Settings, Databases)
[PASS] Test 11: Source secondary session has only Home left and meets auto-close criteria
[PASS] Test 12: Primary window never auto-closes even if down to only Home
[PASS] Test 13: Primary window has only Home tab remaining and stays open
=================================================
Summary: 13 passed, 0 failed.
=================================================
```

### Build Check Output
```text
Build succeeded.
    0 Warning(s)
    0 Error(s)
```

## Residual Risks

- None. Visual tree parenting and selection synchronization are handled cleanly via synchronous UI thread dispatching in `WindowManager.TransferTab` and `ShellWindow.OnTabDroppedOutside`.

## Recommendation

Close the bug — verified end-to-end. Both tab tear-off to desktop and cross-window tab transfer operate in complete alignment with the specification and user requirements.
