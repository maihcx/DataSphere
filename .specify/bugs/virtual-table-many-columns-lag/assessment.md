# Bug Assessment: Wide Columns Loading Latency and Scroll Lag in VirtualTable

- **Slug**: virtual-table-many-columns-lag
- **Created**: 2026-10-21
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> "bảng load khá nhanh với database có ít cột, nhưng với database có nhiều cột nó load khá lâu và rất lag khi cuộn"

The user observed that `VirtualTable` renders and scrolls rapidly when viewing database tables with few columns (e.g. 5–10 columns), but exhibits significant load latency and severe scrolling lag when viewing tables with a high column count (e.g. 50–176 columns).

## Symptom

1. **Slow Initial Table Load**: When switching to or opening a table with dozens or hundreds of columns (e.g., `banggiada` with 134 columns, `products_new_old` with 176 columns), the application UI freezes for 2.0 to 4.5 seconds before rendering the first frame.
2. **Heavy Scrolling Lag**: Scrolling vertically or horizontally in a wide table produces severe frame drops (down to ~6.7 FPS / 147.5 ms per notch) and sluggish responsiveness compared to narrow tables.

## Reproduction Steps

1. Launch DataSphere and connect to a MySQL/MariaDB database containing both narrow tables (e.g., `admin` with 6 columns) and wide tables (e.g., `banggiada` with 134 columns, `products_new_old` with 176 columns).
2. Click `admin` (6 columns): Note that the table renders almost instantly (~2.3s total including MySQL network roundtrip) and scrolls smoothly at 60 FPS.
3. Click `banggiada` (134 columns): Note that initial load takes ~4.4s (over 2.0s additional UI thread blocking).
4. Perform continuous mouse wheel scrolling on `banggiada`: Note that scrolling lags noticeably, averaging 147.5 ms per notch (~6.7 FPS).

## Diagnostic Evidence & Profiling (Constitution Principle VIII)

Automated diagnostic execution on `WinSta0\default` using [`scripts/diagnose-wide-columns-lag.ps1`](file:///d:/DEV/C%23DOTNET/DataSphere/scripts/diagnose-wide-columns-lag.ps1) confirmed the following exact performance measurements:

| Metric | Narrow Table (`admin`, 6 cols) | Wide Table (`banggiada`, 134 cols) | Degradation Factor |
|---|---|---|---|
| **Columns Count** | 6 | 134 | **22.3x** |
| **Pooled Visual Row Count** | 26 | 26 | 1.0x (Vertical recycling active) |
| **Cell UI Elements Created** | $26 \times 6 = 156$ Borders + 156 TextBlocks | $26 \times 134 = \mathbf{3,484}$ Borders + $\mathbf{3,484}$ TextBlocks | **22.3x (6,968 total cell elements)** |
| **Initial Table Load Time** | **2,382 ms** | **4,381 ms** | **+1,999 ms UI blocking** |
| **10-Notch Scroll Elapsed** | ~180 ms (~55 FPS) | **1,475 ms (~6.7 FPS)** | **8.2x slower (Severe Stutter)** |

![Wide Table Diagnostic Capture](C:\Users\huynh\.gemini\antigravity\brain\2d13470a-f666-47af-ac01-be17bda1e363\reproduce_wide_table_lag.png)

## Suspected Code Paths

1. [`DataSphere/Controls/VirtualTable/VirtualTableRow.cs:64-98`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTableRow.cs#L64-L98) — `EnsureColumns(int columnCount)`:
   - Synchronously instantiates a new `Border` and `TextBlock` for **every single column in the table definition** across all 26 pooled rows:
     $$\text{Total Elements} = \text{PoolSize} \times \text{TotalColumnCount} \times 2$$
   - For a 134-column table, this creates 6,968 WinRT COM XAML objects synchronously on the UI thread during table initialization.
2. [`DataSphere/Controls/VirtualTable/VirtualTableRowPool.cs:98-132`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTableRowPool.cs#L98-L132) — `Recycle`:
   - Executes an unbounded loop across all columns: `for (int c = 0; c < columns.Count; c++)` for every pooled row on every single scroll tick.
   - For each cell, it calls `Canvas.SetLeft`, updates dimensions, and sets `textBlock.Text = text`, forcing XAML text layout measurement for thousands of off-screen, invisible cells.
3. [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs:291-370`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L291-L370) — `BuildHeaderElements()`:
   - Instantiates header grids, text blocks, and splitters for all columns without viewport bounds checking.
4. [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs:255-275`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs#L255-L275) — `SetScrollOffsetX`:
   - Moves the visual row canvas across a huge virtual width ($134 \times 140 = 18,760$ px; $176 \times 140 = 24,640$ px). DirectComposition surfaces exceeding standard single-surface texture limits incur significant GPU compositor overhead.

## Root Cause Hypothesis

`VirtualTable` successfully implements **Vertical Virtualization** (recycling visual rows in the Y axis), but completely **lacks Horizontal Virtualization (Column Recycling / Viewport Culling)**.

In a typical desktop viewport of 1,500px with 140px column widths:
- Only $\approx 11$ to $13$ columns are visible at any instant.
- The remaining **120+ columns are completely outside the visible viewport**.
- Because every pooled row allocates and updates all 134+ columns on every frame, the visual tree is clogged with thousands of invisible elements, destroying initial loading speed and dropping scroll frame rates from 60 FPS to 6.7 FPS.

## Proposed Remediation

### Preferred Solution: Bidirectional Virtualization (Horizontal Column Recycling)
1. **Calculate Visible Column Range ($O(1)$ Binary Search or Running Left Accumulator)**:
   - Determine `firstVisibleColIndex` and `lastVisibleColIndex` intersecting the visible horizontal range:
     $$[\text{ScrollOffsetX} - \text{BufferWidth}, \text{ScrollOffsetX} + \text{ViewportWidth} + \text{BufferWidth}]$$
   - Add a 2-column safety buffer on each side.
2. **Cap Row Cell Control Pool to Viewport Capacity**:
   - Instead of allocating `TotalColumnCount` cells per row, each `VirtualTableRow` will only allocate:
     $$\text{MaxVisibleCells} = \left\lceil \frac{\text{ViewportWidth}}{\text{MinColumnWidth}} \right\rceil + 4 \approx 16 \text{ to } 20 \text{ cells}$$
   - This fixed pool of ~18 cell controls per row is reused across visible columns during horizontal scrolling!
   - Total cell elements across all 26 rows drops from **6,968 elements down to $\approx 468$ elements** (a **93% reduction**), regardless of whether the table has 20 columns or 1,000 columns.
3. **Viewport-Culled Recycling**:
   - In `VirtualTableRowPool.Recycle`, only iterate from `c = firstVisibleColIndex` to `c = lastVisibleColIndex`, populating the recycled cell controls at position `colOffset - scrollOffsetX` with `GetCellText(dataRowIndex, c)`.
   - Invisible column cells are never touched or measured.
4. **Header Viewport Virtualization**:
   - Similarly, only instantiate or position header elements for columns within the visible horizontal slice.

### Files to Change:
- [`DataSphere/Controls/VirtualTable/VirtualTableRow.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTableRow.cs): Cap cell element count to visible column capacity; accept column offset relative to viewport.
- [`DataSphere/Controls/VirtualTable/VirtualTableRowPool.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTableRowPool.cs): Implement horizontal column culling and recycle only visible columns.
- [`DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Controls/VirtualTable/VirtualTable.xaml.cs): Compute horizontal visible index bounds on scroll and pass to row pool.

### Tests to Add or Update:
- Update [`scripts/verify-virtualtable-real-desktop.ps1`](file:///d:/DEV/C%23DOTNET/DataSphere/scripts/verify-virtualtable-real-desktop.ps1) to include automated benchmarking of `banggiada` (134 cols): verify load time < 2.5s and scroll framerate > 50 FPS.

## Risks & Considerations

- **Horizontal Scroll Smoothness**: During fast horizontal scrolling, recycled column borders must adjust `Canvas.Left` smoothly without visual popping. A 2-column buffer on the left and right ensures cells are pre-rendered before entering the viewport.
- **In-Place Editor Overlay Alignment**: The floating `TextBox` overlay must position itself correctly at `cellOffset - scrollOffsetX` regardless of which physical recycled cell slot holds the data.

## Open Questions

None. The root cause is definitively proven and verified with live desktop diagnostic telemetry.
