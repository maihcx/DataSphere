# Bug Fix: Unresponsive Settings and Database Navigation from Home Dashboard

- **Slug**: settings-database-navigation-unresponsive
- **Fixed**: 2026-10-20T09:16:30+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Fixed unresponsive card navigation on the Home dashboard by ensuring `HomePage` is instantiated with the active shell window's `ITabService` instance instead of an isolated transient DI instance. Also added a fallback `ResolveActiveTabService()` resolver to `HomeViewModel` for parameterless DI resolutions.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/ViewModels/Windows/ShellViewModel.cs` | modified | Directly constructs `HomePage` with `homeVm` containing the window's `_tabService`, eliminating transient DI disconnection. |
| `DataSphere/ViewModels/Pages/HomeViewModel.cs` | modified | Added parameterless constructor and `ResolveActiveTabService()` to dynamically resolve the active window's `ITabService` from `IWindowManager`. |
| `DataSphere/Services/TabService.cs` | modified | Guarded page instantiation in `OpenTab` with try-catch fallback. |

## Diff Highlights

```csharp
// ShellViewModel.cs
- homePageInstance = _serviceProvider.GetService(typeof(HomePage)) ?? new HomePage(homeVm);
+ homePageInstance = new HomePage(homeVm);

// HomeViewModel.cs
+ public HomeViewModel() : this(ResolveActiveTabService())
+ {
+ }
+
+ private static ITabService ResolveActiveTabService()
+ {
+     var windowManager = App.GetService<IWindowManager>();
+     if (windowManager?.Windows.Count > 0)
+     {
+         var activeSession = windowManager.Windows.FirstOrDefault(w => w.IsPrimary) ?? windowManager.Windows[0];
+         if (activeSession.WindowInstance is Views.Windows.ShellWindow sw)
+         {
+             return sw.ViewModel.TabService;
+         }
+     }
+     return App.GetRequiredService<ITabService>();
+ }
```

## Tests Added or Updated

- `VerifyUserDataStore/Program.cs::[Test 6]` — Validated that `HomeViewModel.OpenDatabaseCommand` and `HomeViewModel.OpenSettingsCommand` successfully add the new tabs to `ShellViewModel.Tabs`, focus them, and re-focus singleton settings tab without duplication.

## Local Verification

- Build check: `dotnet build DataSphere\DataSphere.csproj -c Debug` &rarr; 0 Warning(s), 0 Error(s).
- Execution check: `dotnet run --project C:\Users\huynh\.gemini\antigravity\brain\aca4648a-7af8-48c3-9b8a-ae269a772d90\scratch\VerifyUserDataStore\VerifyUserDataStore.csproj` &rarr; 6/6 tests passed (0 failures).

## Deviations from Assessment

- None. Fix was applied exactly as proposed.

## Follow-ups

- None. Ready for `/speckit-bug-test`.
