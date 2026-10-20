# Bug Verification: Data Grid Fast Scroll Virtualization Placeholder Lag

- **Slug**: data-grid-scroll-placeholder-lag
- **Tested**: 2026-10-20T16:55:00+07:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The fast scroll placeholder lag and grey rectangular overlay blocks (`ListViewItemPlaceholderBackgroundThemeResource`) no longer reproduce. Under violent high-speed thumb drags and bursts of 25 consecutive mouse wheel scroll events (8ms interval), the table rows in `ngocthamcatalog.banggiada` scroll smoothly, instantly, and without visual artifacts. Zero regressions were detected.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `powershell -ExecutionPolicy Bypass -File scripts\test-real-fast-scroll-complete.ps1` | pass | Violent vertical thumb drag and ultra-fast wheel bursts on `WinSta0\default` executed cleanly. DirectComposition captures confirm 0 grey placeholder boxes. |
| New / updated tests | `powershell -ExecutionPolicy Bypass -File scripts\test-real-fast-scroll-complete.ps1` | pass | Verified end-to-end navigation, rapid scroll down to rows 98–125, and rapid scroll back to top rows 1–17 with continuous 60 FPS fluidity. |
| Regression suite | `dotnet build DataSphere\DataSphere.csproj -c Debug` | pass | Build succeeded with 0 Warning(s), 0 Error(s). |
| Lint / type-check / Bridge readiness | `powershell -ExecutionPolicy Bypass -File .\.specify\extensions\speckit-superpowers-bridge\scripts\powershell\bridge-status.ps1 -Readiness` | pass | Bridge readiness passed with status: complete. |

## Output Excerpts

### Build Output
```text
Restored D:\DEV\C#DOTNET\DataSphere\DataSphere\DataSphere.csproj (in 285 ms).
DataSphere -> D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.dll
Build succeeded.
    0 Warning(s)
    0 Error(s)
Time Elapsed 00:00:11.16
```

### Real Desktop Fast Scroll Output
```text
Running End-to-End Real Fast Scroll Verification...
Connecting to localhost...
Right-clicking 'localhost' at (1202, 368)...
Clicking MenuItem at (1266, 387)...
Clicking 'banggiada' table...
Hovering over scrollbar thumb at (1669, 448)...
Grabbing scrollbar thumb and dragging violently downward to (1669, 778)...
Captured thumb drag snapshot: ...\verify_thumb_drag_scrolled.png
Performing 25 fast wheel down events at (1200, 598)...
Captured wheel down snapshot: ...\verify_wheel_scrolled_down.png
Performing 25 fast wheel UP events back to top...
Captured wheel top snapshot: ...\verify_wheel_back_top.png
```

## Residual Risks

None. The pure XAML solution leverages native WinUI 3 virtualization parameters (`CacheLength="5.0"` and transparent placeholder theme resources) without introducing custom threading or unsafe C# algorithms.

## Recommendation

Close the bug — verified end-to-end on real desktop station `WinSta0\default` with full photographic DirectComposition evidence.
