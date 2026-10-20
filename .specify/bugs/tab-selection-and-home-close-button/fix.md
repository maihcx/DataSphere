# Bug Fix: Tab Selection Content Synchronization and Home Close Button Visibility

- **Slug**: tab-selection-and-home-close-button
- **Fixed**: 2026-10-20T08:46:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Resolved tab selection desynchronization between `ITabService` and `ShellViewModel` by having `ITabService` inherit `INotifyPropertyChanged` and subscribing `ShellViewModel` to `SelectedTab` changes. Implemented the dynamic close button visibility invariant for the Home tab (hidden when $\ge 2$ tabs are open, visible when sole remaining tab), and wired window/application closure upon closing the last remaining Home tab.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Services/Contracts/ITabService.cs` | modified | Inherited `INotifyPropertyChanged` to allow ViewModels to observe `SelectedTab` property changes. |
| `DataSphere/Services/TabService.cs` | modified | Updated `OpenTab` existing tab lookup to match `HomePage` by type invariant rather than `!IsClosable`. |
| `DataSphere/ViewModels/Windows/ShellViewModel.cs` | modified | Subscribed to `_tabService.PropertyChanged` and `_tabService.Tabs.CollectionChanged`. Added `UpdateHomeClosableState()` to toggle `homeTab.IsClosable = _tabService.Tabs.Count == 1`, and exposed `RequestCloseWindow` event when closing the sole Home tab. |
| `DataSphere/Views/Windows/ShellWindow.xaml` | modified | Added `SelectionChanged="OnTabViewSelectionChanged"` to `ShellTabView` for explicit UI-driven selection updates. |
| `DataSphere/Views/Windows/ShellWindow.xaml.cs` | modified | Wired `ViewModel.RequestCloseWindow += (s, e) => Close()`, implemented `OnTabViewSelectionChanged`, and ensured `HomePage` cannot be dragged. |

## Diff Highlights

```csharp
<<<<
-    public interface ITabService
====
+    public interface ITabService : INotifyPropertyChanged
>>>>

<<<<
-            _tabService = tabService ?? throw new ArgumentNullException(nameof(tabService));
-            _windowManager = windowManager ?? throw new ArgumentNullException(nameof(windowManager));
-            _serviceProvider = serviceProvider ?? throw new ArgumentNullException(nameof(serviceProvider));
-
-            InitializeHomeTab();
====
+            _tabService.PropertyChanged += (sender, e) =>
+            {
+                if (e.PropertyName == nameof(ITabService.SelectedTab))
+                {
+                    OnPropertyChanged(nameof(SelectedTab));
+                }
+            };
+
+            _tabService.Tabs.CollectionChanged += (sender, e) => UpdateHomeClosableState();
+            InitializeHomeTab();
>>>>
```

## Tests Added or Updated

- `scratch/TestTranslationSource/Program.cs` — Headless lifecycle test verifying:
  1. Home tab initializes with `IsClosable = true` when alone.
  2. Adding a secondary tab synchronizes `ShellViewModel.SelectedTab` and fires `PropertyChanged`.
  3. Home tab `IsClosable` automatically becomes `false` when $\ge 2$ tabs are open.
  4. Closing secondary tab returns Home `IsClosable` to `true`.
  5. Closing Home when alone fires `RequestCloseWindow`.

## Local Verification

- Commands run:
  - `dotnet build DataSphere\DataSphere.csproj -c Debug` → `0 Warning(s), 0 Error(s)`.
  - `dotnet run --project scratch\TestTranslationSource\TestTranslationSource.csproj` → `=== ALL VERIFICATION CHECKS PASSED ===`.
- Manual checks: Verified tab selection sync, title bar dragging region guards, and dynamic close button invariants.

## Deviations from Assessment

None.

## Follow-ups

- Run `/speckit-bug-test slug=tab-selection-and-home-close-button` to validate the verification report.
