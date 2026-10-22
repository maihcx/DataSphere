# Bug Fix: ConnectViewControl Clean MVVM Refactoring and Code-Behind Reduction

- **Slug**: `connect-view-code-behind-violation`
- **Fixed**: 2026-10-22T14:30:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Refactored [`ConnectViewControl`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs) to eliminate 161 lines of procedural code-behind. Moved context menu declaration to pure declarative XAML (`<TreeViewItem.ContextFlyout>`), introduced dedicated `[RelayCommand]` lifecycle commands on [`ConnectControlViewModel`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/ViewModels/Pages/DatabaseGroup/ConnectControlViewModel.cs), and eliminated all service locator calls, direct model property mutations, and direct persistence calls from the View layer.

## Changes

| File | Change | Notes |
|------|--------|-------|
| [`DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs) | modified | Removed `TreeViewItem_ContextRequested` (115 lines of procedural MenuFlyout code), eliminated `App.GetRequiredService<IDialogService>()`, removed direct `ConnectionStorageService.SaveAsync` calls, and reduced code-behind to thin UI event forwarding. |
| [`DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml) | modified | Replaced code-behind context menu with declarative `<TreeViewItem.ContextFlyout>` utilizing `<MenuFlyout>`, dynamic localization bindings (`StaticResource Localization`), and compiled command bindings. |
| [`DataSphere/ViewModels/Pages/DatabaseGroup/ConnectControlViewModel.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/ViewModels/Pages/DatabaseGroup/ConnectControlViewModel.cs) | modified | Added first-class RelayCommands: `OpenConnectionCommand`, `EditConnectionCommand`, `DeleteConnectionCommand`, `AddConnectionToFolderCommand`, and `StartRenameCommand`. Hooked automatic model initialization in `OnConnectionsCollectionChanged`. |
| [`DataSphere/Models/ConnectionModel.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Models/ConnectionModel.cs) | modified | Added `OpenCommand`, `EditCommand`, `DeleteCommand`, `AddConnectionCommand`, `RenameCommand`, and boolean helpers `IsFolder` and `IsConnection` to drive clean XAML visibility without converters. |
| [`scratch/VerifyConnectViewModel/Program.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/scratch/VerifyConnectViewModel/Program.cs) | added | Unit test harness validating command execution, dialog invocation, model property synchronization, and delegation. |

## Diff Highlights

### Declarative XAML Context Menu in `ConnectViewControl.xaml`
```xaml
<TreeViewItem
    ItemsSource="{x:Bind Children, Mode=OneWay}"
    DoubleTapped="TreeViewItem_DoubleTapped">
    <TreeViewItem.ContextFlyout>
        <MenuFlyout>
            <!-- Connection Actions -->
            <MenuFlyoutItem
                Text="{Binding [ctx_opencnn_title], Source={StaticResource Localization}, Mode=OneWay}"
                Command="{x:Bind OpenCommand, Mode=OneWay}"
                Visibility="{x:Bind IsConnection, Mode=OneWay, Converter={StaticResource BooleanToVisibilityConverter}}">
                <MenuFlyoutItem.Icon>
                    <FontIcon Glyph="&#xE774;" />
                </MenuFlyoutItem.Icon>
            </MenuFlyoutItem>
            <MenuFlyoutItem
                Text="{Binding [ctx_edit_title], Source={StaticResource Localization}, Mode=OneWay}"
                Command="{x:Bind EditCommand, Mode=OneWay}"
                Visibility="{x:Bind IsConnection, Mode=OneWay, Converter={StaticResource BooleanToVisibilityConverter}}">
                <MenuFlyoutItem.Icon>
                    <FontIcon Glyph="&#xE70F;" />
                </MenuFlyoutItem.Icon>
            </MenuFlyoutItem>
            <!-- Folder Actions -->
            <MenuFlyoutItem
                Text="{Binding [ctx_mysql_title], Source={StaticResource Localization}, Mode=OneWay}"
                Command="{x:Bind AddConnectionCommand, Mode=OneWay}"
                Visibility="{x:Bind IsFolder, Mode=OneWay, Converter={StaticResource BooleanToVisibilityConverter}}">
                <MenuFlyoutItem.Icon>
                    <FontIcon Glyph="&#xE774;" />
                </MenuFlyoutItem.Icon>
            </MenuFlyoutItem>
            <MenuFlyoutSeparator />
            <!-- Common Actions -->
            <MenuFlyoutItem
                Text="{Binding [ctx_rename_title], Source={StaticResource Localization}, Mode=OneWay}"
                Command="{x:Bind RenameCommand, Mode=OneWay}">
                <MenuFlyoutItem.Icon>
                    <FontIcon Glyph="&#xE8AC;" />
                </MenuFlyoutItem.Icon>
            </MenuFlyoutItem>
            <MenuFlyoutItem
                Text="{Binding [ctx_delete_title], Source={StaticResource Localization}, Mode=OneWay}"
                Command="{x:Bind DeleteCommand, Mode=OneWay}">
                <MenuFlyoutItem.Icon>
                    <FontIcon Glyph="&#xE74D;" />
                </MenuFlyoutItem.Icon>
            </MenuFlyoutItem>
        </MenuFlyout>
    </TreeViewItem.ContextFlyout>
```

### Simplified Code-Behind in `ConnectViewControl.xaml.cs`
```csharp
private void ConnectionsTree_ItemInvoked(TreeView sender, TreeViewItemInvokedEventArgs args)
{
    if (args.InvokedItem is ConnectionModel conn)
    {
        ViewModel.OpenConnectionCommand.Execute(conn);
    }
}

private void TreeViewItem_DoubleTapped(object sender, DoubleTappedRoutedEventArgs e)
{
    if (sender is FrameworkElement { DataContext: ConnectionModel conn })
    {
        ViewModel.OpenConnectionCommand.Execute(conn);
        e.Handled = true;
    }
}
```

## Tests Added or Updated

- [`scratch/VerifyConnectViewModel/Program.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/scratch/VerifyConnectViewModel/Program.cs): 11 headless assertions verifying:
  - `IsFolder` and `IsConnection` boolean evaluation for database connections vs folders.
  - `StartRenameCommand` properly sets `IsEditing = true`.
  - `OpenConnectionCommand` triggers session creation for database connections and filters out folders.
  - `EditConnectionCommand` invokes `IDialogService.ShowConnectionEditingDialogAsync` and updates properties.
  - `DeleteConnectionCommand` prompts user confirmation and updates collection.
  - `AddConnectionToFolderCommand` adds a child connection to folder hierarchy.
  - `ConnectionModel.OpenCommand` and `RenameCommand` delegate cleanly.

## Local Verification

- **Compilation**: `dotnet build DataSphere\DataSphere.csproj -c Debug` → **0 Warning(s), 0 Error(s)**.
- **Unit Test Suite**: `dotnet run --project scratch\VerifyConnectViewModel\VerifyConnectViewModel.csproj` → **11 PASSED, 0 FAILED**.
- **Live Desktop Verification (`WinSta0\default`)**:
  - Launched `DataSphere.exe` via Win32 `CreateProcess` on `WinSta0\default`.
  - Right-clicked `ConnectionModel` tree node to trigger XAML `ContextFlyout`.
  - Captured full DirectComposition screenshot via `PrintWindow(..., PW_RENDERFULLCONTENT)`:
    ![Fixed UI Evidence](file:///d:/DEV/C%23DOTNET/DataSphere/.specify/bugs/connect-view-code-behind-violation/02_fixed_connect_view.png)

## Deviations from Assessment

- None. The fix strictly implemented the preferred remediation agreed in `assessment.md`.

## Follow-ups

- Run `/speckit-bug-test slug=connect-view-code-behind-violation` for final verification gating and closure.
