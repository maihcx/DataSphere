# Bug Fix: Standardize TreeView Selection, Double-Click Invocation, and Expansion

- **Slug**: `treeview-single-click-auto-invoke`
- **Fixed**: 2026-10-22T14:44:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Eliminated premature single-click invocations across both TreeView explorer interfaces. In [`ConnectViewControl`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml), single-clicking a connection now solely selects the item, while double-clicking, Enter key, or context menu opens the database workspace session. In [`DatabaseViewControl`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml), single-clicking a database or category node selects it without toggling expansion, reserving expansion strictly for the native chevron toggle button or double-click.

## Changes

| File | Change | Notes |
|------|--------|-------|
| [`DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml) | modified | Removed `ItemInvoked="ConnectionsTree_ItemInvoked"` and added `KeyDown="ConnectionsTree_KeyDown"`. |
| [`DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs) | modified | Removed `ConnectionsTree_ItemInvoked` handler. Added `ConnectionsTree_KeyDown` for Enter-key activation. Kept `TreeViewItem_DoubleTapped` for double-click opening. |
| [`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml) | modified | Attached `DoubleTapped="TreeNode_DoubleTapped"` on the TreeView item template StackPanel. |
| [`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs) | modified | Removed procedural `node.IsExpanded = !node.IsExpanded` from `SchemaTree_ItemInvoked` so single click only selects. Added `TreeNode_DoubleTapped` to toggle expansion on double click. |

## Diff Highlights

### Connections TreeView: Double-Click & KeyDown Only
```csharp
// ConnectViewControl.xaml.cs
private void TreeViewItem_DoubleTapped(object sender, DoubleTappedRoutedEventArgs e)
{
    if (sender is FrameworkElement { DataContext: ConnectionModel conn })
    {
        ViewModel.OpenConnectionCommand.Execute(conn);
        e.Handled = true;
    }
}

private void ConnectionsTree_KeyDown(object sender, KeyRoutedEventArgs e)
{
    if (e.Key == global::Windows.System.VirtualKey.Enter)
    {
        if (ConnectionsTree.SelectedItem is ConnectionModel conn)
        {
            ViewModel.OpenConnectionCommand.Execute(conn);
            e.Handled = true;
        }
    }
}
```

### Schema TreeView: Single Click Selects, Double Click Toggles Expansion
```csharp
// DatabaseViewControl.xaml.cs
private void TreeNode_DoubleTapped(object sender, Microsoft.UI.Xaml.Input.DoubleTappedRoutedEventArgs e)
{
    if (sender is FrameworkElement fe && fe.DataContext is TreeViewNode node && node.Content is DatabaseTreeNode dtn)
    {
        if (dtn.DataContext is TableCategoryContext || dtn.DataContext is DatabaseInfo || dtn.DataContext is ConnectionRoot)
        {
            if (!dtn.IsLoading)
            {
                node.IsExpanded = !node.IsExpanded;
                e.Handled = true;
            }
        }
    }
}

private void SchemaTree_ItemInvoked(TreeView sender, TreeViewItemInvokedEventArgs args)
{
    if (args.InvokedItem is TreeViewNode node && node.Content is DatabaseTreeNode dtn)
    {
        if (dtn.DataContext is TableNodeContext tnc)
        {
            ViewModel.SelectTable(tnc.Database, tnc.Table);
        }
    }
}
```

## Tests Added or Updated

- Automated Desktop Automation Script [`scratch/verify_treeview_fix.ps1`](file:///d:/DEV/C%23DOTNET/DataSphere/scratch/verify_treeview_fix.ps1):
  - Test 1: Single left-click on `localhost` tree node → Verifies node is selected and no session tab opens.
  - Test 2: Double left-click on `localhost` tree node → Verifies session tab opens.
  - Test 3: Single left-click on database schema node → Verifies node is selected without expanding children.
- Unit Test Suite [`scratch/VerifyConnectViewModel`](file:///d:/DEV/C%23DOTNET/DataSphere/scratch/VerifyConnectViewModel/Program.cs) → 11/11 PASSED.

## Local Verification

- **Compilation**: `dotnet build DataSphere\DataSphere.csproj -c Debug` → **0 Warning(s), 0 Error(s)**.
- **Unit Tests**: `dotnet run --project scratch\VerifyConnectViewModel\VerifyConnectViewModel.csproj` → **11 PASSED, 0 FAILED**.
- **Real Desktop Verification (`WinSta0\default`)**:
  - Single click on connection node: item highlighted/selected, tab remains on Connections view:
    ![Single-Click Selected Only](file:///d:/DEV/C%23DOTNET/DataSphere/.specify/bugs/treeview-single-click-auto-invoke/03_fixed_single_click_select_only.png)
  - Double click on connection node: opens database session tab, and single click on schema item selects without expanding:
    ![Double-Click Opened Tab and Tree Select](file:///d:/DEV/C%23DOTNET/DataSphere/.specify/bugs/treeview-single-click-auto-invoke/04_fixed_double_click_open_and_tree_select.png)

## Deviations from Assessment

- None. The fix aligns exactly with the preferred remediation outlined in `assessment.md`.

## Follow-ups

- Run `/speckit-bug-test slug=treeview-single-click-auto-invoke` for formal verification and sign-off.
