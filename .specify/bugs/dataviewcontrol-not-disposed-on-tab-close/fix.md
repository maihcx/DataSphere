# Bug Fix: DataViewControl Memory Leak and Missing Dispose Trigger on Tab Close

- **Slug**: dataviewcontrol-not-disposed-on-tab-close
- **Fixed**: 2026-10-23T10:05:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Implemented a complete, cascading `IDisposable` lifecycle across `DatabasePage`, `DatabaseViewModel`, `DatabaseViewControl`, and `WindowSession`. Closing the top-level Database workspace tab or an inner database connection tab now deterministically disposes child `DataViewControl` instances, stops `{x:Bind}` event tracking, severs visual subtree references, and disconnects MySQL database connections.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseViewModel.cs` | modified | Implemented `IDisposable`, unhooks `TranslationSource` on dispose, updated `CloseTab` to invoke `tab.Dispose()`, and disposes child `InnerTabs` and `ConnectionTab`. |
| `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml.cs` | modified | Implemented `IDisposable` and `ISleepableTabContent`, stops compiled `{x:Bind}` tracking, nullifies `InnerTabView.SelectedItem`, and cascades teardown to `ViewModel.Dispose()`. |
| `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml` | modified | Added `x:Name="RightPanelHost"` to tabular viewport `ContentControl` for deterministic visual tree detachment. |
| `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs` | modified | Added `_disposed` guard, stops compiled `{x:Bind}` tracking, detaches `RightPanelHost.Content = null`, clears `SchemaTree.RootNodes`, and disposes `ViewModel`. |
| `DataSphere/Models/WindowSession.cs` | modified | Updated `CloseTab(TabItemModel tab)` to call `tab.Dispose()` before removing the tab model. |
| `scripts/verify-dataviewcontrol-disposal.ps1` | added | Real desktop (`WinSta0\default`) automation test verifying top Database tab and inner dynamic connection tab closures without crashes. |

## Diff Highlights

### DatabaseViewModel Cascading Disposal
```csharp
public void CloseTab(InnerTabItemModel tab)
{
    if (tab == null || !tab.IsClosable) return;
    int index = InnerTabs.IndexOf(tab);
    if (index < 0) return;

    bool wasSelected = Equals(SelectedInnerTab, tab);

    tab.Dispose(); // Triggers InnerTabItemModel -> DatabaseControlViewModel -> DataViewControl -> VirtualTable
    InnerTabs.RemoveAt(index);
...
```

### DatabasePage Terminal Teardown
```csharp
public void Dispose()
{
    if (_disposed) return;
    _disposed = true;

    ViewModel.PropertyChanged -= _vmPropertyChangedHandler;
    Bindings?.StopTracking();
    InnerTabView.SelectedItem = null;
    ViewModel.Dispose();
}
```

### DatabaseViewControl Visual Tree Detachment
```csharp
public void Dispose()
{
    if (_disposed) return;
    _disposed = true;

    ViewModel.RootConnections.CollectionChanged -= OnRootConnectionsChanged;
    Bindings?.StopTracking();
    if (RightPanelHost != null)
    {
        RightPanelHost.Content = null;
    }
    SchemaTree?.RootNodes.Clear();
    ViewModel.Dispose();
}
```

## Tests Added or Updated

- `scripts/verify-dataviewcontrol-disposal.ps1` — Automated live UI test executing on `WinSta0\default`:
  - Connects to database and activates `DataViewControl` on table `banggiada_backup` (`01_table_active_before_tab_close.png`).
  - Closes top Database tab via close button ('X') on `ShellTabView` and asserts seamless return to Home page without crashes (`02_top_tab_closed_home_active.png`).
  - Re-opens Database, connects, and clicks close button on inner dynamic tab (`localhost`), verifying fallback to Connection catalog and zero crashes (`03_inner_tab_closed_connection_active.png`).

## Local Verification

- Commands run:
  - `dotnet build DataSphere\DataSphere.csproj -c Debug` → Succeeded (0 Warning(s), 0 Error(s)).
  - `powershell -ExecutionPolicy Bypass -File scripts\verify-dataviewcontrol-disposal.ps1` → Passed (Process healthy, all 3 UI screenshots captured on `WinSta0\default`).
  - `powershell -ExecutionPolicy Bypass -File .\.specify\extensions\speckit-superpowers-bridge\scripts\powershell\bridge-status.ps1 -Readiness` → Succeeded (Readiness: ready).

## Deviations from Assessment

None. All changes followed the preferred remediation outlined in `assessment.md`.

## Follow-ups

- Run `/speckit-bug-test slug=dataviewcontrol-not-disposed-on-tab-close` to formally validate the resolution and produce `test.md`.
