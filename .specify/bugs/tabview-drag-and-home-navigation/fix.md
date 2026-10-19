# Bug Fix: TabView Title Bar Dragging and Home Dashboard Navigation Failure

- **Slug**: tabview-drag-and-home-navigation
- **Fixed**: 2026-10-19T17:02:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Fixed window drag capability on the TabView title bar by introducing `CustomDragRegion` in `TabView.TabStripFooter` and binding it via `SetTitleBar()`. Resolved the Home page navigation failure by directly injecting the host window's `_tabService` into `HomeViewModel` and `HomePage`, ensuring action cards open new tabs directly into the active window's tab strip.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Views/Windows/ShellWindow.xaml` | modified | Added `TabStripHeader` and `TabStripFooter` containing `CustomDragRegion` (transparent grid with `MinWidth="188"`). |
| `DataSphere/Views/Windows/ShellWindow.xaml.cs` | modified | Registered `SetTitleBar(CustomDragRegion)` and synchronized `_session.Tabs` with `ViewModel.Tabs.CollectionChanged`. |
| `DataSphere/ViewModels/Windows/ShellViewModel.cs` | modified | Passed window `_tabService` directly into `new HomeViewModel(_tabService)` and `new HomePage(homeVm)`. |
| `DataSphere/Services/WindowManager.cs` | modified | Checked `if (newWindow is Views.Windows.ShellWindow sw)` in `TearOffTabToNewWindow` to add tabs directly to `sw.ViewModel.TabService.Tabs`. |

## Diff Highlights

### 1. TabStrip Drag Region in `ShellWindow.xaml`
```xml
<TabView.TabStripHeader>
    <Grid x:Name="CustomDragRegionLeft" Background="Transparent" Width="8" />
</TabView.TabStripHeader>

<TabView.TabStripFooter>
    <Grid x:Name="CustomDragRegion" Background="Transparent" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" MinWidth="188" />
</TabView.TabStripFooter>
```

### 2. Title Bar Activation & Session Sync in `ShellWindow.xaml.cs`
```csharp
ExtendsContentIntoTitleBar = true;
SetTitleBar(CustomDragRegion);
CustomDragRegion.MinWidth = 188;
```

### 3. Window TabService Injection in `ShellViewModel.cs`
```csharp
var homeVm = new DataSphere.ViewModels.Pages.HomeViewModel(_tabService);
var homePageInstance = new HomePage(homeVm);
```

## Local Verification

- **Compilation**: `dotnet build DataSphere\DataSphere.csproj -c Debug` -> `Build succeeded. 0 Warning(s), 0 Error(s)`.
- **String Audit**: 0 prohibited hardcoded literals found.

## Deviations from Assessment

None.

## Follow-ups

- Run `/speckit-bug-test slug=tabview-drag-and-home-navigation` to record the verification report.
