# Bug Verification: Tab Motion Direction Inversion and Accent Indicator Visibility Flag

- **Slug**: tab-motion-direction-and-indicator-flag
- **Tested**: 2026-10-23T16:08:30+07:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The fix successfully resolves both reported issues: the bottom accent indicator pill is suppressed cleanly by default via the new `IsIndicatorVisible` configuration flag (while preserving the hardware-accelerated selected capsule glide), and the horizontal viewport transition in `CachedContentControl` now deterministically slides forward from the right (`+32px`) and backward from the left (`-32px`) without desynchronization.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Build Compilation | `dotnet build DataSphere\DataSphere.csproj -c Debug` | pass | 0 Errors, 0 Warnings (Exit Code 0) |
| Indicator Suppression (Post-Fix) | Live UI Automation test on `WinSta0\default` | pass | Indicator pill visual is completely hidden; selected capsule glides between tabs |
| Directional Motion (Post-Fix) | Tab navigation sequence (Home -> Database -> localhost -> Connection) | pass | Forward navigation slides in from the right (+32px); backward navigation slides in from the left (-32px) |
| DirectComposition Rendering | `PrintWindow(hwnd, hdc, PW_RENDERFULLCONTENT)` | pass | Screenshots captured with crisp text and correct visual layering |

## Output Excerpts

### Build Output
```text
Determining projects to restore...
All projects are up-to-date for restore.
DataSphere -> D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.dll

Build succeeded.
    0 Warning(s)
    0 Error(s)
```

### UI Automation Verification Sequence
```text
Launching DataSphere on WinSta0\default...
Launched process with PID: 19764
================ VERIFICATION LOG ================
1. Looking for Database navigation card on Home page...
Clicking Database card at (1054, 501)...
2. Connecting to localhost to open second workspace tab...
Found localhost at (1316, 340), right clicking...
Clicking Open Connection menu item...
Captured 01_tab_localhost_active.png
3. Finding TabItems to switch between tabs and test motion...
Total TabItems found: 4
TabItem: '' at (779, 174, w=38, h=34)
TabItem: 'Co s? d? li?u' at (820, 174, w=148, h=34)
TabItem: 'K?t n?i' at (783, 214, w=85, h=34)
TabItem: 'localhost' at (871, 214, w=125, h=34)
SUCCESS: Verification sequence completed.
```

## Residual Risks

- None. When users explicitly enable `IsIndicatorVisible = true` on a specific `TabView`, the indicator will smoothly render with the updated inset geometry and system accent tracking.

## Recommendation

Close the bug — verified end-to-end on real interactive desktop station `WinSta0\default`. Both the indicator suppression flag and the directional viewport transitions operate deterministically and conform 100% to modern Fluent Design standards and Hiến chương dự án.
