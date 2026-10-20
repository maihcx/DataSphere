# Bug Fix: Database Schema Tree Auto-Expand and Chevron Loading State

- **Slug**: database-tree-auto-expand-and-loading
- **Fixed**: 2026-10-20T15:40:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Modified the database schema tree expansion behavior so expanding a database node only reveals category nodes (`Các bảng`, `Views`, `Thủ tục lưu trữ`, `Hàm`) with `Các bảng` remaining collapsed by default. Expanding `Các bảng` activates a smooth loading `ProgressRing` directly within the chevron down slot while `LoadTablesAsync` is in-flight, cleanly reverting to the downward chevron down glyph (`ˇ`) once table realization completes.

## Changes

| File | Change | Notes |
|------|--------|-------|
| [`DataSphere/Models/Database/DatabaseTreeNode.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Models/Database/DatabaseTreeNode.cs) | modified | Inherited from `ObservableObject` and added partial property `IsLoading` for observable node loading states without AOT/WinRT warnings. |
| [`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs) | modified | Implemented `TableCategoryContext` lazy loading; removed `tablesCatNode.IsExpanded = true;`; added `SetChevronLoading` and `FindVisualChild` for dynamic chevron spinner transitions; added category context menu. |
| [`scratch/VerifyDatabaseView/Program.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/scratch/VerifyDatabaseView/Program.cs) | modified | Added Tests 39-42 verifying `IsLoading`, removal of eager auto-expansion, collapsed lazy loading configuration, and `SetChevronLoading` implementation. |

## Diff Highlights

### 1. `DatabaseTreeNode.cs`
```csharp
public sealed partial class DatabaseTreeNode : ObservableObject
{
    [ObservableProperty]
    public partial string Title { get; set; } = string.Empty;

    [ObservableProperty]
    public partial string IconGlyph { get; set; } = string.Empty;

    [ObservableProperty]
    public partial bool IsLoading { get; set; }

    public object? DataContext { get; set; }
}
```

### 2. `DatabaseViewControl.xaml.cs` (SchemaTree_Expanding)
```csharp
if (dtn.DataContext is DatabaseInfo db)
{
    if (args.Node.HasUnrealizedChildren)
    {
        args.Node.HasUnrealizedChildren = false;
        args.Node.Children.Clear();

        // Tables category node: Unrealized, collapsed by default
        var tablesCatNode = CreateNode(LanguageBase.GetLangValue("dbinf_tables_title"), "\uE8B7", new TableCategoryContext(db));
        tablesCatNode.HasUnrealizedChildren = true;
        tablesCatNode.IsExpanded = false;
        args.Node.Children.Add(tablesCatNode);

        // Placeholder categories
        args.Node.Children.Add(CreateNode(LanguageBase.GetLangValue("dbinf_views_title"), "\uE890", db));
        args.Node.Children.Add(CreateNode(LanguageBase.GetLangValue("dbinf_sps_title"), "\uE943", db));
        args.Node.Children.Add(CreateNode(LanguageBase.GetLangValue("dbinf_fncs_title"), "\uF168", db));
    }
}
else if (dtn.DataContext is TableCategoryContext tcc)
{
    if (args.Node.HasUnrealizedChildren)
    {
        args.Node.HasUnrealizedChildren = false;
        dtn.IsLoading = true;

        var tvi = sender.ContainerFromNode(args.Node) as TreeViewItem;
        SetChevronLoading(tvi, true);

        try
        {
            await ViewModel.LoadTablesAsync(tcc.Database);
            args.Node.Children.Clear();

            if (tcc.Database.Tables != null)
            {
                foreach (var table in tcc.Database.Tables)
                {
                    var tableNode = CreateNode(table.Name, "\uF0E2", new TableNodeContext(tcc.Database, table));
                    args.Node.Children.Add(tableNode);
                }
            }
        }
        finally
        {
            dtn.IsLoading = false;
            SetChevronLoading(tvi, false);
        }
    }
}
```

## Tests Added or Updated

- `scratch/VerifyDatabaseView/Program.cs`:
  - `Test 39`: Validates `DatabaseTreeNode.IsLoading` observable property.
  - `Test 40`: Asserts removal of `tablesCatNode.IsExpanded = true;`.
  - `Test 41`: Asserts collapsed lazy loading configuration with `TableCategoryContext`, `HasUnrealizedChildren = true`, and `IsExpanded = false`.
  - `Test 42`: Asserts `SetChevronLoading` and `ChevronLoadingRing` integration.

## Local Verification

- Commands run:
  - `dotnet build DataSphere\DataSphere.csproj -c Debug` → Build succeeded with 0 Warning(s) and 0 Error(s).
  - `dotnet run --project scratch\VerifyDatabaseView\VerifyDatabaseView.csproj` → 42 passed, 0 failed.

## Deviations from Assessment

None. The preferred remediation path was implemented verbatim using code-behind visual tree child attachment for `ProgressRing`, preserving native WinUI 3 `TreeViewItem` styles and themes without duplicating large XAML control templates.

## Follow-ups

- Proceed to `/speckit-bug-test slug=database-tree-auto-expand-and-loading` for live UI verification on `WinSta0\default` with DirectComposition capture.
