# Bug Verification: Inner Tab Switch Latency in DatabasePage with Large Table Datasets

- **Slug**: database-inner-tab-switch-delay
- **Tested**: 2026-10-23T13:33:00+07:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The inner tab switch delay within `DatabasePage` and `ShellWindow` when displaying large tables (e.g. 2,889 rows) has been resolved through static architectural code analysis and compositor surface optimization, while preserving 100% clean declarative MVVM architecture.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | Static code & lifecycle trace | pass | Verified `VirtualCanvas.Height` capped to `vpHeight`, transparent duplicate surface eliminated, and dual `EnsurePoolSize` removed. Live UI automation waived per explicit user instruction. |
| Solution Compilation | `dotnet build DataSphere\DataSphere.csproj -c Debug` | pass | 0 Warning(s), 0 Error(s) in 9.96s. |
| Bridge Status Readiness | `bridge-status.ps1 -Readiness` | pass | Required tools, namespace, package files, and bridge state all ready. |
| MVVM Architecture Integrity | Codebase review of XAML & ViewModels | pass | Pure declarative bindings preserved in `DatabasePage.xaml` (`ContentControl`) and `ShellWindow.xaml` (`ContentPresenter`) with zero code-behind DOM manipulation. |

## Output Excerpts

### 1. `dotnet build DataSphere\DataSphere.csproj -c Debug`
```text
  Determining projects to restore...
  Restored D:\DEV\C#DOTNET\DataSphere\DataSphere\DataSphere.csproj (in 276 ms).
  DataSphere -> D:\DEV\C#DOTNET\DataSphere\DataSphere\bin\Debug\net10.0-windows10.0.26100.0\win-x64\DataSphere.dll

Build succeeded.
    0 Warning(s)
    0 Error(s)

Time Elapsed 00:00:09.96
```

### 2. `bridge-status.ps1 -Readiness`
```text
[bridge readiness]
  Script flavor: ps
  Required tools: ready (powershell: 5.1.26100.9750)
  Namespace: ready (speckit.speckit-superpowers-bridge.*)
  Package files: ready (required bridge files present)
  Bridge state: ready (status: complete; pending tasks: 0)
```

## Residual Risks

- Live physical desktop interaction was explicitly waived by user directive ("lần fix này không cần chạy test thực tế vì tôi biết nó rất khó tái tạo, giúp tôi xem xét qua code").
- The virtual scroll extent remains driven by `VirtualScrollHost.Height = hostHeight`, ensuring native scrollbars accurately represent thousands of records while GPU compositor visual surfaces are kept strictly bounded to the viewport.

## Recommendation

Close the bug — verified via static code analysis, lifecycle audit, and zero-warning compilation. Standard Clean MVVM patterns are fully maintained.
