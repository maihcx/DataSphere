# Feature Specification: High-Performance WinUI 3 VirtualTable Control (TVirtualStringTree Architecture)

**Feature Branch**: `008-virtual-table-control`

**Created**: 2026-10-21

**Status**: Draft

**Input**: User description: "bảng sử dụng DataGrid thật sự chưa thỏa mản tôi (hiệu suất kém quá) có cách nào tái tạo TVirtualStringTree trên WinUI không? tôi muốn bạn tạo giúp tôi 1 controls đặt ở trong thư mục Controls/ có tên là VirtualTable tái tạo logic của TVirtualStringTree để có hiệu suất và hiệu quả tốt nhất với ram tốn ít nhất có thể nhưng phải đẹp chuẩn WinUI3"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ultra-High-Performance Virtual Row Recycling Canvas (Priority: P1) 🎯 MVP

As a database administrator or analyst exploring tables with thousands to millions of records, I want table data in DataSphere to be rendered using a dedicated `VirtualTable` control that adopts the architectural paradigm of Delphi's `TVirtualStringTree` (fixed-pool row recycling with on-demand cell text callbacks), so that the application loads instantly, consumes minimal RAM, and maintains buttery-smooth 60+ FPS scrolling without GC stutter or layout freezing.

**Why this priority**: Standard XAML controls (`DataGrid`, `ListView`) allocate visual containers and bindings for every visible cell and row, creating GC pressure, reflection overhead, and layout latency. Recreating the `TVirtualStringTree` paradigm with a fixed pool of ~25 visual rows delivers instant, HeidiSQL-grade performance.

**Independent Test**: Can be tested independently by loading a 100,000-row table into `VirtualTable`, observing that only ~25 row containers exist in memory, scrolling rapidly across thousands of rows, and verifying 60 FPS fluidity with 0 GC allocations during scrolling.

**Acceptance Scenarios**:

1. **Given** a dataset with $N$ rows (where $N$ ranges from 100 to 1,000,000), **When** `VirtualTable` loads, **Then** it instantiates only the exact number of row visual containers needed to fill the visible viewport (e.g. 20-30 rows) plus a 2-row buffer, independent of $N$.
2. **Given** continuous vertical scrolling (via mouse wheel or scrollbar thumb drag), **When** the scroll offset changes, **Then** existing row containers are reused and updated via direct indexed text callbacks (`OnGetCellText`) without allocating new heap objects or invoking XAML `Binding` reflection.
3. **Given** viewport resizing (maximizing window or adjusting splitters), **When** the viewport height increases or decreases, **Then** the control dynamically adjusts its pooled row containers to match the new visible height.

---

### User Story 2 - Fluent Design 2 Column Headers, Resizing & 3-State Sorting (Priority: P1)

As a database user analyzing structured tabular data, I want modern WinUI 3 Fluent Design 2 column headers with draggable splitters to resize column widths, double-click auto-fitting, and clickable headers that cycle through 3-state sorting (Ascending `↑`, Descending `↓`, Clear) with visual glyphs, perfectly aligned with the virtualized data rows below.

**Why this priority**: Ergonomic column resizing and visual sorting are indispensable for inspecting database tables containing diverse string lengths, integer IDs, and metadata.

**Independent Test**: Can be tested independently by dragging a column header divider to widen a column, verifying that the data cells below widen synchronously without tearing, and clicking a column header to observe sort glyph toggling and data re-querying.

**Acceptance Scenarios**:

1. **Given** column headers, **When** the user drags a header separator, **Then** the column and its corresponding visible cells resize smoothly in real time without layout desynchronization.
2. **Given** column headers, **When** the user clicks a column header, **Then** it cycles through Ascending (`↑`), Descending (`↓`), and Natural/Clear states, notifying the data provider or ViewModel to perform server-side sorting.
3. **Given** horizontal scrolling, **When** the user scrolls horizontally, **Then** column headers and cell viewports scroll synchronously at the compositor level without header detaching.

---

### User Story 3 - Row/Cell Selection & Keyboard Navigation (Priority: P2)

As a power user navigating large tables, I want to select rows or individual cells, navigate effortlessly using arrow keys (Up, Down, Left, Right, PageUp, PageDown, Home, End), and copy selected cell text to the Windows clipboard using `Ctrl+C`.

**Why this priority**: Keyboard ergonomics and clipboard export are essential for developer productivity and data extraction.

**Independent Test**: Can be tested independently by clicking a cell, pressing arrow keys to move focus across rows and columns, pressing `Ctrl+C`, and pasting into a text editor to confirm the copied text.

**Acceptance Scenarios**:

1. **Given** a focused cell or row, **When** the user presses arrow keys, **Then** visual focus and selection shift predictably across rows and columns, auto-scrolling the viewport if the target is out of view.
2. **Given** an active selection, **When** the user presses `Ctrl+C`, **Then** the text representation of the selected cell(s) is copied to the Windows clipboard.

---

### User Story 4 - In-Place Cell Editing with Overlay Editor (Priority: P2)

As a database administrator editing records, I want to double-click any cell or press Enter on a focused cell to activate an in-place `TextBox` overlay, modify the value, press Enter to commit the cell edit (or Escape to cancel), and have the modified value reflected in the underlying data provider and marked dirty for toolbar committing.

**Why this priority**: Direct in-place editing is a core requirement of modern database tooling, while an overlay editor keeps the underlying virtual canvas 100% lightweight during browsing.

**Independent Test**: Can be tested independently by double-clicking a cell, typing a new value, pressing Enter, verifying the cell updates and marks the row as dirty, and confirming toolbar commit integration.

**Acceptance Scenarios**:

1. **Given** an editable table with primary keys, **When** the user double-clicks an editable cell, **Then** an in-place `TextBox` overlay appears directly over the cell's bounding rectangle with existing text pre-selected.
2. **Given** an active in-place editor, **When** the user presses Enter or moves focus, **Then** the new text is committed to the data row, the overlay closes, and a `CellEdited` event is raised to enable toolbar Commit/Discard buttons.
3. **Given** an active in-place editor, **When** the user presses Escape, **Then** the overlay closes and the cell retains its original value.

---

### Edge Cases

- **Zero Records / Empty Table**: When `RowCount == 0`, the control renders column headers and an empty-state indicator without index exceptions.
- **Very Wide Tables (50+ Columns)**: Horizontal virtualization skips updating columns outside the visible horizontal window, ensuring high performance on wide schemas.
- **High-DPI & Scale Factors**: Gridlines and cell text snap cleanly to physical pixels (`UseLayoutRounding="True"`) to prevent blurry rendering.
- **Rapid High-Velocity Mouse Wheel Scrolling**: Rapid mouse wheel spins (multiple detents per second) calculate target offsets cleanly without cumulative queue delay.
- **Database NULL Values**: Cells containing database `NULL` are formatted distinctly with subtle italicized placeholder text to distinguish from empty strings `""`.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST create a custom control named `VirtualTable` in `DataSphere/Controls/VirtualTable/` implementing fixed-pool row recycling architecture inspired by Delphi's `TVirtualStringTree`.
- **FR-002**: System MUST maintain an internal pool of visual row containers strictly equal to `ViewportHeight / RowHeight + 2`, never allocating new row containers during vertical scrolling.
- **FR-003**: System MUST obtain cell display data via an on-demand provider interface (`IVirtualTableDataProvider` / `Func<int, int, string>`) to eliminate per-cell XAML `Binding` reflection and dependency property overhead.
- **FR-004**: System MUST render modern Fluent Design 2 column headers with resizable splitters, auto-fit double click, and 3-state sorting indicators.
- **FR-005**: System MUST synchronize vertical and horizontal scrolling between headers, gridlines, and cell containers with native smooth scrollbars.
- **FR-006**: System MUST support row and cell selection with hover highlights, visual focus rings, and full keyboard navigation (arrows, PageUp/Down, Home/End).
- **FR-007**: System MUST support copying selected cell or row data to the Windows clipboard via `Ctrl+C`.
- **FR-008**: System MUST support in-place cell editing using a floating `TextBox` overlay positioned at the exact coordinates of the edited cell.
- **FR-009**: System MUST preserve dynamic internationalization (i18n) via `TranslationSource` with zero hardcoded user-facing strings.
- **FR-010**: System MUST replace `CommunityToolkit.WinUI.UI.Controls.DataGrid` in `DataViewControl` with `VirtualTable` while preserving sorting and commit/discard capabilities.

---

### Key Entities

- **IVirtualTableDataProvider**: Interface defining methods for total row count, column definitions, on-demand cell text retrieval (`GetCellText(int row, int col)`), cell modification, and sort event notifications.
- **VirtualTableColumn**: Encapsulates column properties including name, header text, width, minimum width, sort direction, and data type.
- **VirtualTableRow**: Lightweight pooled visual container representing a single rendered row in the viewport, hosting recycled cell text blocks.
- **VirtualTableCellEditEventArgs**: Event data emitted when a cell edit is committed or cancelled.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Scrolling through 100,000 rows maintains a consistent 60+ FPS without visual tearing, layout jitter, or dropped frames.
- **SC-002**: Memory consumption of the UI viewport remains under 15 MB regardless of whether the table contains 100 rows or 1,000,000 rows.
- **SC-003**: Memory allocation during active continuous scrolling is 0 bytes (zero GC Gen0/Gen1 triggers).
- **SC-004**: Initial rendering of any table page occurs in $<50$ milliseconds.
- **SC-005**: All interactions (sorting, resizing, editing, scrolling) are verified on `WinSta0\default` with DirectComposition visual confirmation.

---

## Assumptions

- Target platform is Windows 10/11 x64 with .NET 10 and Windows App SDK 2.5+.
- Fixed-pool row recycling operates within a standard WinUI 3 `Canvas` or custom virtual panel, using native WinUI 3 controls (`Border`, `TextBlock`, `TextBox`) in a recycled configuration.
- Column count typically ranges from 1 to 100 columns; horizontal virtualization ensures columns outside the visible window are skipped during text updates.
