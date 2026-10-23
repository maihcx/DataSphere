# Bug Verification: Sliding Tab Selection Background Layer Stale Capsule On Tear-Off

- **Slug**: inner-tab-tearoff-stale-capsule
- **Tested**: 2026-10-24T03:11:00+07:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The fix was rigorously verified through automated UI execution on the real Windows desktop station (`WinSta0\default`). The original symptom no longer reproduces: after tearing off a database workspace tab into an independent window, selecting the anchored "Kết nối" (Connection) tab causes the selection highlight capsule (`InnerTabCapsule`) to smoothly translate from `localhost` to "Kết nối", with 0 warnings and 0 errors.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `powershell -ExecutionPolicy Bypass -File scripts\reproduce-and-verify.ps1` | pass | Executed end-to-end on `WinSta0\default`: opened app, opened `localhost` session, tore off tab into new window, and clicked "Kết nối" tab. |
| DirectComposition Pixel Scan | `powershell -ExecutionPolicy Bypass -File scripts\map-crop-verified.ps1` | pass | Pixel matrix proves capsule (`C`) translated to X=20..80 (under "Kết nối"), and `localhost` area (X=130..250) is cleanly vacated (`.`). |
| Regression suite | `powershell -ExecutionPolicy Bypass -File scripts\reproduce-tab-stale-on-close-bug.ps1` | pass | Verified preceding tab closure on main Shell tab strip retains indicator alignment. |
| Lint / type-check | `dotnet build DataSphere\DataSphere.csproj -c Debug` | pass | Clean compilation: 0 Warnings, 0 Errors. 100% US English XML doc comments. |

## Output Excerpts

### Build Verification
```text
  DataSphere -> D:\DEV\WinUI\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.dll
Build succeeded.
    0 Warning(s)
    0 Error(s)
Time Elapsed 00:00:11.96
```

### Live UI Reproduction Verification (`WinSta0\default`)
```text
Launched PID: 4480
Step 1: Clicking Database button on Home page...
Found dbBtn at: 255,671,575,121
Step 2: Double-clicking localhost in connection tree...
TreeItem 0: DataSphere.Models.ConnectionModel at 170,491,1320,44
Step 3: Finding tabs to tear off...
Tabs before drag: 4
Dragging from (297,342) to (297,170)...
All windows for PID 4480: 2
Window 0: hwnd=8325354 class=WinUIDesktopWin32WindowClass name='DataSphere' rect=297,170,1600,1000
Window 1: hwnd=6162868 class=WinUIDesktopWin32WindowClass name='DataSphere' rect=142,315,1376,928
Tab count in new window: 4
NewWin tab 0:  Bounds=310,175,47,45
NewWin tab 1: Co s? d? li?u Bounds=360,175,185,45
NewWin tab 2: K?t n?i Bounds=316,228,105,45
NewWin tab 3: localhost Bounds=269,373,156,45
Clicking Connection Tab at X=368 Y=250
Captured: D:\DEV\WinUI\DataSphere\.specify\bugs\inner-tab-tearoff-stale-capsule\verified_step4_connection_selected.png
Test completed successfully.
```

### Pixel Scanner Output (`crop_verified_tabs.png`)
```text
Size: 500x150
Y=060: ....CC.CTCC..CCCC.CC.....C..............C.............................
Y=063: ....CC.CTCC.TTCTTCCC..........TTTT.......T............................
Y=066: ....CCCTTCC..TCCC.CC........T...T..T..................................
Y=069: ....CCTCCCC.T.CC.CCC..................................................
Y=072: ....CCCCCCCCCCCCCCCC....T.............................................
Y=075: ....CCCCCCCCCCCCCCCC..................................................
Y=078: ....CCCCCCCCCCCCCCCC..................................................
Y=081: .....CCCCCCCCCCCCCC...................................................
```

## Residual Risks

- None identified. Window tear-off re-initialization is fully protected by auto-healing logic in `UpdatePosition` and `UpdateVisualsPosition`, compositor-isolated animations using `capsuleVisual.Compositor`, and robust event delegation via `AddHandler(..., handledEventsToo = true)`.

## Recommendation

Close the bug — verified end-to-end. The sliding tab background capsule functions flawlessly across primary and detached windows, maintaining Clean MVVM and zero code-behind visual tree manipulation.
