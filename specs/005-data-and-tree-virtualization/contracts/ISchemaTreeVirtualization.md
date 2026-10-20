# Contract: Schema TreeView Virtualization & Node Recycling

**Interface**: `DataSphere.Services.Contracts.ISchemaTreeVirtualization` / `DatabaseViewControl` Contract

## Overview

Defines the contract and behavioral invariants governing schema explorer treeview virtualization, container recycling, and lazy realization in `DataSphere.Views.Pages.DatabaseGroup.DatabaseViewControl`.

## Architecture Contract

```csharp
namespace DataSphere.Services.Contracts
{
    /// <summary>
    /// Contract governing schema explorer treeview virtualization and recycling safety.
    /// </summary>
    public interface ISchemaTreeVirtualization
    {
        /// <summary>
        /// Gets the total count of schema objects registered across all expanded connections and databases.
        /// </summary>
        int TotalRegisteredNodeCount { get; }

        /// <summary>
        /// Gets the number of TreeViewItem containers actively materialized in the visual tree.
        /// </summary>
        int MaterializedTreeNodeCount { get; }

        /// <summary>
        /// Determines whether a node content payload conforms to pure POCO requirements.
        /// </summary>
        /// <param name="content">The node content instance to check.</param>
        /// <returns><c>true</c> if the content is pure POCO; otherwise <c>false</c>.</returns>
        bool ValidateNodeContentPurity(object content);

        /// <summary>
        /// Asynchronously batches the population of child nodes to maintain 60 FPS UI responsiveness.
        /// </summary>
        /// <param name="parentNode">The target parent node.</param>
        /// <param name="children">The child items to add.</param>
        /// <param name="cancellationToken">Cancellation token for user aborts.</param>
        Task BatchRealizeChildrenAsync(object parentNode, IEnumerable<object> children, CancellationToken cancellationToken);
    }
}
```

## Behavioral Invariants

1. **Zero UIElement in Content**: `TreeViewNode.Content` MUST strictly be an instance of pure POCO `DatabaseTreeNode`. Direct attachment of `UIElement` (such as `StackPanel`, `TextBlock`, `FontIcon`) is strictly prohibited to guarantee zero visual reparenting crashes during container recycling.
2. **Virtualization Bounded Memory**: Off-screen tree nodes must be virtualized by WinUI 3's underlying `ItemsStackPanel`. Scrolling through a tree with 500+ items must maintain memory proportional to the visible tree height, not the total tree node count.
3. **Re-entrancy Guard**: Expanding a node with `HasUnrealizedChildren` MUST reset `HasUnrealizedChildren = false` synchronously before initiating any async query to prevent concurrent re-entrant expansion requests.
