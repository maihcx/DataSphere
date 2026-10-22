# Bug Fix: Tab Drag-Back Drop Failure into Window with Sole Home Tab in TabStripHeader

- **Slug**: tab-drag-back-empty-header
- **Fixed**: 2026-10-22T10:45:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Enabled full-width tab docking support on the main shell window by wiring native UIElement `AllowDrop="True"`, `DragOver="OnTabAreaDragOver"`, and `Drop="OnTabAreaDrop"` to `ShellTabView`, `HomeTabItem` (`TabStripHeader`), and `CustomDragRegion` (`TabStripFooter`). This allows cross-window tab dragging and dropping to display the "Move" cursor and successfully re-dock tabs when a window has zero dynamic tabs (Home alone in `TabStripHeader`) or when hovering over empty space to the right of existing tabs.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Views/Windows/ShellWindow.xaml` | modified | Added `AllowDrop="True"`, `DragOver="OnTabAreaDragOver"`, and `Drop="OnTabAreaDrop"` to `ShellTabView`, `StackPanel` (header), `HomeTabItem`, and `CustomDragRegion` (footer). |
| `DataSphere/Views/Windows/ShellWindow.xaml.cs` | modified | Implemented `OnTabAreaDragOver` and `OnTabAreaDrop` to accept `DataSphereTabPayload`, transfer tabs into `ViewModel.Tabs`, and marked `e.Handled = true` to prevent duplicate drop dispatching. |

## Diff Highlights

### `ShellWindow.xaml`
```xml
        <TabView x:Name="ShellTabView"
                 ...
                 AllowDrop="True"
                 DragOver="OnTabAreaDragOver"
                 Drop="OnTabAreaDrop"
                 ...

            <TabView.TabStripHeader>
                <StackPanel Orientation="Horizontal"
                            ...
                            AllowDrop="True"
                            DragOver="OnTabAreaDragOver"
                            Drop="OnTabAreaDrop">
                    ...
                    <TabViewItem x:Name="HomeTabItem"
                                 ...
                                 AllowDrop="True"
                                 DragOver="OnTabAreaDragOver"
                                 Drop="OnTabAreaDrop">
            ...
            <TabView.TabStripFooter>
                <Grid x:Name="CustomDragRegion"
                      ...
                      AllowDrop="True"
                      DragOver="OnTabAreaDragOver"
                      Drop="OnTabAreaDrop" />
```

### `ShellWindow.xaml.cs`
```csharp
        private void OnTabAreaDragOver(object sender, DragEventArgs e)
        {
            if (e.DataView.Properties.ContainsKey("DataSphereTabPayload"))
            {
                e.AcceptedOperation = DataPackageOperation.Move;
                e.Handled = true;
            }
            else
            {
                e.AcceptedOperation = DataPackageOperation.None;
            }
        }

        private void OnTabAreaDrop(object sender, DragEventArgs e)
        {
            if (e.Handled)
            {
                return;
            }

            if (e.DataView.Properties.TryGetValue("DataSphereTabPayload", out object? rawPayload) &&
                rawPayload is TabDragPayload payload)
            {
                if (_session != null && payload.SourceWindowId != _session.WindowId)
                {
                    int targetIndex = ReferenceEquals(sender, HomeTabItem) ? 0 : ViewModel.Tabs.Count;
                    _windowManager.TransferTab(payload.SourceWindowId, _session.WindowId, payload.Tab, targetIndex);
                    e.Handled = true;
                }
            }
        }
```

## Local Verification

- Commands run: `dotnet build DataSphere/DataSphere.csproj -c Debug` → Pass (0 Warnings, 0 Errors).
- Architectural validation: Preserves Home tab in `TabStripHeader` without inserting fake or dummy models into `ViewModel.Tabs`.

## Deviations from Assessment

None. The implementation follows the Preferred Remediation from `assessment.md` exactly.

## Follow-ups

- Execute verification testing via `/speckit-bug-test slug=tab-drag-back-empty-header`.
