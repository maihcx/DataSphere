# Feature Specification: Native CommunityToolkit DataGrid with Interactive Sorting

**Feature Branch**: `006-datagrid-table-view`

**Created**: 2026-10-21

**Status**: Draft

**Input**: User description: "hãy thay ListView trong DataViewControl bằng https://learn.microsoft.com/en-us/windows/communitytoolkit/controls/datagrid_guidance/group_sort_filter#2-sorting"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Native Tabular Data Presentation via DataGrid (Priority: P1)

As a database developer or data analyst using DataSphere, I want table records in the database view to be presented in a professional desktop DataGrid with integrated column headers, native gridlines, and high-performance row virtualization, so that I can inspect structured records with clarity and speed without custom synchronization hacks.

**Why this priority**: Displaying database records in a standard, performant grid is the core functionality of any database management system. Replacing the composite ListView + nested ItemsControl architecture with a native DataGrid establishes the foundational data surface.

**Independent Test**: Can be tested independently by navigating to any database table (e.g. `ngocthamcatalog.banggiada`), observing that columns align with headers, gridlines delimit cells, and records render instantly across pagination boundaries.

**Acceptance Scenarios**:

1. **Given** an active connection and a selected table, **When** the table view loads, **Then** all columns defined in the table schema are rendered as distinct grid columns with proper headers and data type metadata.
2. **Given** a paginated page with 100 rows and 20 columns, **When** the user scrolls vertically or horizontally, **Then** the grid virtualization smoothly renders rows and cells at 60 FPS without layout jitter, detached headers, or visual tearing.

---

### User Story 2 - Interactive Column Header Sorting (Priority: P1)

As a database analyst, I want to click on any column header in the DataGrid to sort table rows in ascending or descending order, with visual sort direction indicators (up/down arrows), so that I can quickly organize, inspect, and find relevant records in the dataset.

**Why this priority**: Sorting is one of the most frequently used analytical actions in database tooling. Conforming to the Windows Community Toolkit DataGrid sorting guidance (`#2-sorting`) delivers intuitive, standard desktop ergonomics.

**Independent Test**: Can be tested independently by clicking a column header (e.g. `id` or `code`), verifying that the sort direction glyph updates (Ascending ➔ Descending ➔ Unsorted/Default) and records reorder according to the selected column's data type.

**Acceptance Scenarios**:

1. **Given** unsorted table data, **When** the user clicks on a column header, **Then** the column sorts in ascending order and displays an upward arrow glyph in the column header.
2. **Given** an ascending-sorted column, **When** the user clicks the same column header again, **Then** the column sorts in descending order and displays a downward arrow glyph.
3. **Given** a descending-sorted column, **When** the user clicks the header a third time (or clicks with a reset modifier), **Then** the sort clears to natural database order and the arrow glyph disappears.
4. **Given** sorted rows on a numeric or date column, **When** the sort is executed, **Then** rows sort according to their intrinsic data type value rather than raw alphabetical character comparisons.

---

### User Story 3 - Interactive Column Width Resizing & Layout Adaptation (Priority: P2)

As a user viewing wide tables or long string values, I want to drag column boundary dividers to resize column widths, or double-click to auto-fit to content, so that I can view long values without truncation and optimize screen real estate.

**Why this priority**: Database columns vary widely from small integer IDs to lengthy descriptions or JSON blobs. Interactive column resizing gives users full control over readability.

**Independent Test**: Can be tested independently by hovering over the divider between two column headers, dragging left or right, and verifying that the column width resizes fluidly while maintaining cell alignment.

**Acceptance Scenarios**:

1. **Given** a table with varying text lengths, **When** the user drags a column header splitter to the right, **Then** the column widens smoothly and subsequent columns shift accordingly.
2. **Given** column widths exceeding the visible viewport, **When** the user scrolls horizontally, **Then** columns virtualize and render correctly without header desynchronization.

---

### User Story 4 - Cell Selection, Keyboard Navigation & Clipboard Export (Priority: P3)

As a power user, I want to navigate through grid cells using arrow keys, select individual cells or entire rows, and copy selected cell text to the Windows clipboard via standard shortcuts (Ctrl+C), so that I can extract data values for external use.

**Why this priority**: Keyboard navigation and clipboard access accelerate workflow efficiency for technical database administrators and developers.

**Independent Test**: Can be tested independently by selecting a cell, pressing arrow keys to move focus, pressing Ctrl+C, and pasting into a text editor to confirm the copied value.

**Acceptance Scenarios**:

1. **Given** focused data cells, **When** the user presses arrow keys, **Then** grid cell focus shifts predictably up, down, left, and right.
2. **Given** one or more selected cells, **When** the user presses Ctrl+C, **Then** the text representation of the selected data is copied to the clipboard.

---

### Edge Cases

- **Very Wide Tables (50+ Columns)**: The grid must virtualize columns horizontally so that tables with numerous columns do not exhaust UI element allocations or cause layout lag.
- **Null and Empty Values**: Database `NULL` values must be formatted distinctly (e.g. italicized or subtle placeholder text) without throwing null reference exceptions during sort comparisons.
- **Type-Aware Sorting on Dynamic Rows**: Columns typed as integers, floating points, dates, or timestamps must sort by their parsed value rather than string collation (e.g. 10 must sort after 2, not before).
- **Sorting with Pagination**: When pagination is active, the sort applies to the currently loaded page or coordinates with the pagination engine, maintaining correct page summary counters.
- **Rapid Alternating Column Clicks**: Clicking multiple different headers in rapid succession must cancel previous in-flight sort operations gracefully without thread starvation.
- **Zero Records / Empty Table**: When a table contains 0 rows, the DataGrid must render column headers cleanly with an appropriate localized empty-state indicator.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST replace the composite `ScrollViewer` + `ListView` + nested `ItemsControl` in `DataViewControl` with the native Windows Community Toolkit `DataGrid`.
- **FR-002**: System MUST dynamically generate DataGrid columns matching the active database table schema, displaying column names and data types.
- **FR-003**: System MUST support interactive column header sorting adhering to the CommunityToolkit guidance, cycling through Ascending, Descending, and Unsorted states upon header clicks.
- **FR-004**: System MUST render visual sort direction indicator glyphs in the sorted column header matching Fluent Design standards.
- **FR-005**: System MUST perform type-aware sorting so that numeric, date, and text fields sort according to their underlying data semantics.
- **FR-006**: System MUST allow users to interactively resize column widths by dragging header splitters.
- **FR-007**: System MUST support standard row/cell selection and keyboard navigation across grid cells.
- **FR-008**: System MUST support copying selected cell text to the Windows clipboard via standard shortcuts (`Ctrl+C`).
- **FR-009**: System MUST preserve dynamic internationalization (i18n) by obtaining all grid-related status text, empty-state labels, and tooltips from `TranslationSource` without hardcoded user-facing strings.
- **FR-010**: System MUST maintain fluid UI virtualization (60 FPS) during high-velocity vertical and horizontal scrolling across all page sizes (100, 200, 500 rows).

### Key Entities

- **TableColumnMetadata**: Represents schema information for a database column, including column name, ordinal position, SQL data type, nullability, and primary key status.
- **TableRowRecord**: Represents an individual record within the active page, containing indexed cell values with strong or boxed type fidelity.
- **ColumnSortDescriptor**: Encapsulates the active sort configuration, including target column identifier, sort direction (`Ascending`, `Descending`, `None`), and comparison delegate.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Initial rendering of a 100-row, 15-column table page completes in under 250 milliseconds on modern desktop hardware.
- **SC-002**: Clicking a column header completes the in-memory sort reordering and updates the visual sort glyph in under 100 milliseconds for a 100-row page.
- **SC-003**: Continuous fast scrolling (vertical and horizontal) maintains 60 FPS without dropped frames, visual stuttering, or detached column headers.
- **SC-004**: 100% of user-facing strings comply with dynamic i18n via resource files with zero hardcoded strings.
- **SC-005**: All sorting, resizing, and navigation features are verifiable through automated UI testing on `WinSta0\default` with DirectComposition visual confirmation.

## Assumptions

- The target runtime environment is .NET 10 (`net10.0-windows10.0.26100.0`) on Windows 10/11 with Windows App SDK 2.5+.
- The Windows Community Toolkit WinUI DataGrid package (`CommunityToolkit.WinUI.UI.Controls.DataGrid` or `CommunityToolkit.WinUI.Controls.DataGrid`) is compatible with the project's Windows App SDK version.
- Sorting on the active view applies to the current paginated dataset slice loaded in memory. Server-side sorting can be layered in future database query extensions.
- Column header resizing and sorting configurations are maintained in memory for the active session and do not need to persist to disk across app restarts in v1.
