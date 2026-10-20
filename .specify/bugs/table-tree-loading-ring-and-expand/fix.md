# Bug Fix: Schema Tree Loading Ring Never Ends and Node Fails to Auto-Expand Post Load

- **Slug**: table-tree-loading-ring-and-expand
- **Fixed**: 2026-10-20T15:58:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Fixed the persistent spinning `ProgressRing` by querying and removing dynamic `ProgressRing` elements directly from `chevronGrid.Children` instead of failing with `FindName`. Fixed the node expansion behavior by explicitly assigning `args.Node.IsExpanded = true;` post-realization so tables display immediately on the first click without requiring a second click.

## Changes

| File | Change | Notes |
|------|--------|-------|
| [`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs) | modified | Updated `SetChevronLoading` to use `chevronGrid.Children.OfType<ProgressRing>()` and remove rings when loading finishes; updated `SchemaTree_Expanding` to assign `args.Node.IsExpanded = true;` post-await; updated `SchemaTree_ItemInvoked` to guard expansion with `!dtn.IsLoading`. |
| [`scratch/VerifyDatabaseView/Program.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/scratch/VerifyDatabaseView/Program.cs) | modified | Updated Test 42 and added Tests 43–44 verifying dynamic `ProgressRing` removal, explicit post-realization `IsExpanded = true`, and `!dtn.IsLoading` invocation guard. |

## Diff Highlights

### 1. `SetChevronLoading` ProgressRing Removal
```csharp
private void SetChevronLoading(TreeViewItem? tvi, bool isLoading)
{
    if (tvi == null) return;

    var chevronGrid = FindVisualChild<Grid>(tvi, "ExpandCollapseChevron");
    if (chevronGrid == null) return;

    var expandedGlyph = FindVisualChild<TextBlock>(chevronGrid, "ExpandedGlyph");
    var existingRings = chevronGrid.Children.OfType<ProgressRing>().ToList();

    if (isLoading)
    {
        if (expandedGlyph != null)
        {
            expandedGlyph.Opacity = 0;
        }

        if (existingRings.Count == 0)
        {
            var ring = new ProgressRing
            {
                Width = 14,
                Height = 14,
                IsActive = true,
                Visibility = Visibility.Visible,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            };
            chevronGrid.Children.Add(ring);
        }
        else
        {
            foreach (var ring in existingRings)
            {
                ring.Visibility = Visibility.Visible;
                ring.IsActive = true;
            }
        }
    }
    else
    {
        foreach (var ring in existingRings)
        {
            ring.IsActive = false;
            ring.Visibility = Visibility.Collapsed;
            chevronGrid.Children.Remove(ring);
        }

        if (expandedGlyph != null)
        {
            expandedGlyph.Opacity = 1;
        }
    }
}
```

### 2. Explicit Post-Await `args.Node.IsExpanded = true;`
```csharp
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

// Explicitly set IsExpanded = true post-await so WinUI 3 immediately renders realized tables on single click
args.Node.IsExpanded = true;
```

## Tests Added or Updated

- `scratch/VerifyDatabaseView/Program.cs`:
  - `Test 42`: Verifies `SetChevronLoading` cleans up `ProgressRing` instances using `chevronGrid.Children.OfType<ProgressRing>()` and `chevronGrid.Children.Remove(ring)`.
  - `Test 43`: Asserts `args.Node.IsExpanded = true;` is explicitly assigned after realizing tables to eliminate the need for a second click.
  - `Test 44`: Asserts `SchemaTree_ItemInvoked` guards toggling with `!dtn.IsLoading`.

## Local Verification

- `dotnet build DataSphere\DataSphere.csproj -c Debug` → 0 Warning(s), 0 Error(s).
- `dotnet run --project scratch\VerifyDatabaseView\VerifyDatabaseView.csproj` → 44 passed, 0 failed (100% PASS).

## Deviations from Assessment

None. The preferred remediation was applied verbatim.

## Follow-ups

- Proceed to `/speckit-bug-test slug=table-tree-loading-ring-and-expand` for live desktop verification.
