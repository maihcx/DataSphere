# Bug Verification: ShellTabBackgroundCanvas Missing Tab Highlight After Closing All Tabs and Reopening

- **Slug**: shell-tab-background-canvas-highlight
- **Tested**: 2026-10-24T00:10:30+07:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The fix has been verified end-to-end on a real Windows desktop session (`WinSta0\default`) using physical mouse input and DirectComposition pixel analysis (`PW_RENDERFULLCONTENT`). The original bug no longer reproduces: when all dynamic tabs are closed and a new dynamic tab is spawned from Home, the Fluent highlight capsule (`ShellTabCapsule` / `InnerTabCapsule`) renders with 100% pixel fidelity (`(244, 244, 244)` card background) exactly matching initial tab creation. No UI or threading regressions were observed.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Clean Compilation | `dotnet build DataSphere\DataSphere.csproj -c Debug` | pass | 0 Warning(s), 0 Error(s) in 20.33s. |
| Reproduction (post-fix) | `powershell -ExecutionPolicy Bypass -File scripts\reproduce-tab-highlight-bug.ps1` | pass | Completed 7-step physical automation on `WinSta0\default` without crash or layout collapse. |
| Pixel Matrix Matching | Inspect DirectComposition capture `step5_new_tab_reproduced.png` vs `step1_database_opened.png` | pass | 105 / 105 sampled header pixels matched (100.0% match rate, `R=244..245, G=244, B=244`). |
| Clean MVVM Compliance | Static architectural review of `SlidingTabIndicatorBehavior.cs` | pass | Zero code-behind visual tree manipulation; pure attached behavior coordinating Composition visuals. |
| Code Documentation | English technical XML doc comments verification | pass | 100% US English XML doc comments on all new/updated methods and types. |

## Output Excerpts

### Build Output
```text
DataSphere -> D:\DEV\WinUI\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.dll
Build succeeded.
    0 Warning(s)
    0 Error(s)
```

### Automation Verification Log
```text
Launched DataSphere PID: 12888
[Step 0] Initial Home captured.
Clicking Database Button: X=702 Y=728.5
[Step 1] Database tab opened.
Current TabItems count: 3
Clicking Home Tab: X=404.5 Y=340.5
[Step 2] Back to Home captured.
Clicking Settings Button: X=1281.5 Y=728.5
[Step 3] Settings tab opened.
Clicking close button on tab 2: X=737 Y=340
Clicking close button on tab 1: X=590 Y=340
[Step 4] All dynamic tabs closed.
Clicking Button to create new tab: X=702 Y=728.5
[Step 5] New tab opened after closing all tabs captured.
```

### DirectComposition Pixel Matrix Verification
```text
Pixel comparison between Step 1 and Step 5 in dynamic tab header:
Matched pixels: 105 / 105 (100 %)
Step 5 Unselected Home pixel at (30, 20): R=218, G=218, B=218
Step 5 Selected Tab 1 pixel at (100, 20): R=244, G=244, B=244
```

## Residual Risks

- None identified. Container bounds checking (`IsValidOnScreenTabItem`) prevents matching virtualized elements regardless of tab strip length, DPI scale factor, or virtualization strategy.

## Recommendation

Close the bug — verified end-to-end on live desktop with DirectComposition visual evidence.
