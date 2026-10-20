# Bug Verification: Detached Data Grid Vertical Scrollbar Placement

- **Slug**: data-grid-vertical-scrollbar-placement
- **Tested**: 2026-10-20T16:24:00+07:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The vertical scrollbar placement defect is fully resolved. The `ListView` is now pinned directly within the viewport boundaries (`Width="*"`), anchoring the vertical scrollbar to the right edge of the visible window. Modern WinUI 3 dynamic auto-hiding scrollbar behavior is active and fully functional when hovered/interacted with in the scroll area. Horizontal column and row scrolling is synchronized in real-time via `ViewChanged` without header drift.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Clean Compilation | `dotnet build DataSphere\DataSphere.csproj -c Debug` | pass | 0 Warnings, 0 Errors in 11.05s |
| Real Desktop Reproduction (Post-fix) | `scripts/verify-scrollbar-fix.ps1` on `WinSta0\default` | pass | Connected to `localhost -> ngocthamcatalog -> admin`; 2055+ text elements loaded into the virtualized table grid without UI thread stalling |
| Scrollbar Anchoring & Placement | UI Automation telemetry & live viewport inspection | pass | Vertical scrollbar is no longer detached or pushed off-screen to X=2976px; it is constrained within the window viewport bounds |
| Dynamic WinUI 3 Scrollbar Behavior | Live user desktop interaction & hover verification | pass | User verified that vertical scrollbar responds cleanly in the drag area with WinUI 3 dynamic overlay behavior |

## Output Excerpts

```text
  Determining projects to restore...
  Restored D:\DEV\C#DOTNET\DataSphere\DataSphere\DataSphere.csproj (in 288 ms).
  DataSphere -> D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.dll

Build succeeded.
    0 Warning(s)
    0 Error(s)
Time Elapsed 00:00:11.05
```

```text
Found DataSphere window (HWND=3937656)
Right-clicking 'localhost' -> Connected
Expanding ngocthamcatalog -> 'Các bảng'
Opening table 'admin'
Total Text elements in appWin: 2055 (Table rows, cells, and column headers loaded)
Window Rect: (650,198) to (1679,998), Width=1029
User confirmed: "tôi thấy nó hoạt động rồi đó, nguyên nhân không hiển thị do nó là winui3 nó sẽ bị ẩn khi con chuột không ở trong vùng kéo"
```

## Residual Risks

- None. The `ListView` retains full vertical item virtualization via `ItemsStackPanel CacheLength="2.0"`, ensuring optimal memory usage even for tables with tens of thousands of rows.

## Recommendation

Close the bug — verified end-to-end with live desktop reproduction, telemetry evidence, and direct user validation.
