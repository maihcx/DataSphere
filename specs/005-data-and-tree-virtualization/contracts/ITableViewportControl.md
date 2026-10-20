# Contract: Table Viewport & Row Virtualization

**Interface**: `DataSphere.Services.Contracts.ITableViewport` / `DataViewControl` Architecture Contract

## Overview

Defines the contract and behavioral invariants for the virtualized table record viewport in `DataSphere.Views.Pages.DatabaseGroup.DataViewControl` and its driving ViewModel `DataControlViewModel`.

## Architecture Contract

```csharp
namespace DataSphere.Services.Contracts
{
    /// <summary>
    /// Contract defining virtualized table data viewport presentation metrics and interactions.
    /// </summary>
    public interface ITableViewport
    {
        /// <summary>
        /// Gets the total calculated horizontal table width required to display all columns without clipping.
        /// </summary>
        double TotalTableWidth { get; }

        /// <summary>
        /// Gets the number of row containers actively materialized in the visual tree viewport.
        /// In a virtualized viewport, this value must not exceed (ViewportHeight / RowHeight) + BufferCount.
        /// </summary>
        int MaterializedRowCount { get; }

        /// <summary>
        /// Gets a value indicating whether vertical UI virtualization is actively enabled.
        /// </summary>
        bool IsVirtualizationActive { get; }

        /// <summary>
        /// Synchronously resets or adjusts the horizontal scroll channel across column headers and data rows.
        /// </summary>
        /// <param name="horizontalOffset">The target horizontal pixel offset.</param>
        void SynchronizeHorizontalOffset(double horizontalOffset);
    }
}
```

## Behavioral Invariants

1. **Bounded Element Count**: For any page size $N$ (e.g. 100, 500, 1,000, 5,000), the number of active `ListViewItem` containers materialized in memory MUST be strictly bounded by:
   $$\text{MaterializedContainers} \le \left\lceil \frac{\text{ViewportHeight}}{\text{RowHeight}} \right\rceil \times (1 + 2 \times \text{CacheLength})$$
   Under standard 1080p resolution ($\text{ViewportHeight} \approx 600\text{px}$, $\text{RowHeight} = 40\text{px}$, $\text{CacheLength} = 2.0$), materialized containers MUST NOT exceed 75 rows, even if 1,000 rows are loaded in memory.
2. **Scroll Lockstep**: Column header row and data rows MUST share the exact same horizontal scroll position at all times.
3. **Selection Integrity**: Recycling a `ListViewItem` container MUST NOT alter the selection status of previously unselected rows or lose cell text selection capability.
