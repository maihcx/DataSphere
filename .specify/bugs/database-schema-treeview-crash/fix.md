# Bug Fix: TreeView UI Virtualization Visual Tree Reparenting Crash on Rapid Node Expand/Collapse

- **Slug**: database-schema-treeview-crash
- **Fixed**: 2026-10-20T13:54:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Eliminated the visual tree reparenting crash (`E_INVALIDARG` / `0x80070057` in `ContentControl.set_Content`) by introducing pure data model `DatabaseTreeNode` for `TreeViewNode.Content` and declaring the visual template (`StackPanel`, `FontIcon`, `TextBlock`) directly in XAML. Added immediate re-entrancy flags on expanding nodes and thread-safe locking in `DatabaseControlViewModel.LoadTablesAsync` to prevent concurrent expansion churn.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Models/Database/DatabaseTreeNode.cs` | added | Lightweight POCO data model (`Title`, `IconGlyph`, `DataContext`) decoupling node data from visual UI elements. |
| `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml` | modified | Replaced `<ContentControl Content="{x:Bind Content}" />` with direct visual element declarations and typed compiled bindings. |
| `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs` | modified | Refactored `CreateNode` to instantiate `DatabaseTreeNode` instead of `StackPanel`, guarded `HasUnrealizedChildren = false` before `await`, and updated `ItemInvoked` and `ContextRequested`. |
| `DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseControlViewModel.cs` | modified | Added `_loadingDatabases` lock guard to prevent concurrent duplicate table queries for the same schema. |
| `scratch/VerifyDatabaseView/Program.cs` | modified | Updated and added Tests 19, 30–32 verifying pure data model binding, lock safety, and zero `UIElement` contamination. |

## Diff Highlights

```xml
<!-- DatabaseViewControl.xaml -->
<TreeView.ItemTemplate>
    <DataTemplate x:DataType="TreeViewNode">
        <StackPanel
            Orientation="Horizontal"
            Spacing="8"
            Padding="2,4"
            ContextRequested="TreeNode_ContextRequested">
            <FontIcon Glyph="{x:Bind ((dbmodels:DatabaseTreeNode)Content).IconGlyph, Mode=OneWay}" FontSize="14" />
            <TextBlock Text="{x:Bind ((dbmodels:DatabaseTreeNode)Content).Title, Mode=OneWay}" VerticalAlignment="Center" />
        </StackPanel>
    </DataTemplate>
</TreeView.ItemTemplate>
```

```csharp
// DatabaseViewControl.xaml.cs
private TreeViewNode CreateNode(string text, string iconGlyph, object dataContext)
{
    var nodeData = new DatabaseTreeNode
    {
        Title = text,
        IconGlyph = iconGlyph,
        DataContext = dataContext
    };

    return new TreeViewNode
    {
        Content = nodeData
    };
}
```

```csharp
// SchemaTree_Expanding
if (args.Node.Content is DatabaseTreeNode dtn && dtn.DataContext is DatabaseInfo db)
{
    if (args.Node.HasUnrealizedChildren)
    {
        // Guard immediately to prevent concurrent re-entrant expansion requests
        args.Node.HasUnrealizedChildren = false;

        await ViewModel.LoadTablesAsync(db);
        args.Node.Children.Clear();
        ...
```

## Tests Added or Updated

- `scratch/VerifyDatabaseView/Program.cs`:
  - `Test 19`: Verified `DatabaseViewControl.xaml` defines `TreeView.ItemTemplate` binding to `((dbmodels:DatabaseTreeNode)Content).Title`.
  - `Test 30`: Verified `DatabaseTreeNode` is a pure data POCO that does not inherit or reference `UIElement`.
  - `Test 31`: Verified `DatabaseViewControl.xaml.cs` creates `DatabaseTreeNode` instances and sets `HasUnrealizedChildren = false` before `await`.
  - `Test 32`: Verified `DatabaseControlViewModel.cs` protects `LoadTablesAsync` with `_loadingDatabases` lock.

## Local Verification

- Commands run:
  - `dotnet build DataSphere\DataSphere.csproj -c Debug` → Succeeded (0 Warning, 0 Error).
  - `dotnet run --project scratch/VerifyDatabaseView/VerifyDatabaseView.csproj` → 32 passed, 0 failed.

## Deviations from Assessment

None. All implementations aligned with the preferred remediation in `assessment.md`.

## Follow-ups

- Execute `/speckit-bug-test slug=database-schema-treeview-crash` to validate the fix and record the test verification report.
