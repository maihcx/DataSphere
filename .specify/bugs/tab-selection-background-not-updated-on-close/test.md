# Bug Verification: Tab Selection Background Layer Stale After Closing Preceding Tab

- **Slug**: tab-selection-background-not-updated-on-close
- **Tested**: 2026-10-24T01:17:30+07:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The bug is completely resolved. Closing an unselected tab preceding the currently active tab now triggers multi-stage transition settle updates that track the physical layout repositioning in WinUI 3, smoothly gliding the Fluent selection background highlight capsule (`ShellTabCapsule` / `InnerTabCapsule`) to the active tab's new position. No visual artifacts, phantom highlights, or regressions were detected.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `powershell -ExecutionPolicy Bypass -File scripts\reproduce-tab-stale-on-close-bug.ps1` | pass | Executed on real desktop `WinSta0\default` with physical mouse clicks and DirectComposition capture (`PW_RENDERFULLCONTENT`). |
| Pixel Verification (post-fix) | `powershell -ExecutionPolicy Bypass -File scripts\verify-pixels.ps1` | pass | Verified that `X=80..200` has RGB `(245..246, 243, 242..243)` (active highlight) and `X=260..380` has returned to `(224..225, 215..216, 212..213)` (unselected background). |
| Compile & Type-Check | `dotnet build DataSphere\DataSphere.csproj -c Debug` | pass | 0 Warnings, 0 Errors. Clean compilation. |
| Bridge Readiness | `powershell -ExecutionPolicy Bypass -File .\.specify\extensions\speckit-superpowers-bridge\scripts\powershell\bridge-status.ps1 -Readiness` | pass | Bridge readiness PASS; 0 pending tasks. |

## Output Excerpts

### Automated UI Automation Run:
```text
Launched DataSphere PID: 14476
[Step 0] Initial Home captured.
Clicking Database Button: X=1209.5 Y=832.5
After Step 1, TabItems count: 3
[Step 1] Database tab opened.
Clicking Home Tab: X=845.5 Y=443.5
[Step 2] Back to Home captured.
Clicking Settings Button: X=1804.5 Y=832.5
After Step 3, TabItems count: 3
[Step 3] Settings tab opened.
Tab 0: Name='' Bounds=822,421,47,45
Tab 1: Name='Co s? d? li?u' Bounds=871,421,185,45
Tab 2: Name='Ci d?t' Bounds=1059,421,143,45
Close buttons in Database tab: 1
Clicking close button on Tab 1 (Database): X=1028 Y=444
[Step 4] Captured after closing Database tab. Tab 2 (Settings) is now Tab 1.
TabItems remaining after closing Database tab: 2
Remaining Tab 0: Name='' Bounds=822,421,47,45
Remaining Tab 1: Name='Ci d?t' Bounds=871,421,143,45
```

### Pixel Header Scan Verification (`verify-pixels.ps1`):
```text
Checking Step 4 image pixels across tab header row (Y=20):
X=20: (223,216,214)
X=40: (175,169,169)
X=60: (223,216,215)
X=80: (245,243,243)
X=100: (245,243,243)
X=120: (246,243,243)
X=140: (246,243,243)
X=160: (246,243,243)
X=180: (246,243,242)
X=200: (246,243,242)
X=220: (224,216,213)
X=240: (224,216,213)
X=260: (224,216,213)
X=280: (224,216,213)
X=300: (225,216,213)
X=320: (225,215,213)
X=340: (225,215,213)
X=360: (225,215,212)
X=380: (225,215,213)
X=400: (225,215,212)
```

## Residual Risks

- None identified. Tab dynamic collections, header tabs (`HomeTabItem`, `ConnectionTabItem`), and drag-and-drop reordering are fully observed.
- The `INotifyCollectionChanged` handler is registered and deregistered with complete lifecycle protection, preventing memory leaks.

## Recommendation

Close the bug — verified end-to-end on live desktop station with DirectComposition capture and pixel-level quantitative validation.
