# Feature Specification: Anchored Connection Tab in TabStripHeader & In-Page Tab Reordering for DatabasePage

**Feature Branch**: `014-database-tabstrip-header`

**Created**: 2026-10-22

**Status**: Draft

**Input**: User description: "tại ShellWindow có sử dụng TabStripHeader để cố định kéo, hãy áp dụng logic tương tự cho DatabasePage:
- hỗ trợ khả năng kéo tab để sắp xếp (không mở cửa sổ mới)
- cố định tab kết nối
- đổi icon khác cho tab kết nối để phù hợp hơn"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Anchored Connection Tab in Inner TabStripHeader (Priority: P1)

As a database administrator, I want the Connection tab in `DatabasePage` to be anchored permanently inside `InnerTabView.TabStripHeader` at the leftmost position, so that the connection catalog remains a fixed, dedicated entry point that cannot be accidentally reordered, displaced, or closed.

**Why this priority**: Anchoring the Connection tab establishes a consistent mental model and visual hierarchy identical to `ShellWindow`'s anchored Home tab, preventing the root connection explorer from being misplaced among transient database and query tabs.

**Independent Test**: Navigate to `DatabasePage` from the Home screen. Verify that the Connection tab is rendered inside the `TabStripHeader` to the left of the dynamic tab list, displays the dedicated Connect icon glyph (`\uE703`), and has no close button ('X').

**Acceptance Scenarios**:

1. **Given** the user navigates to `DatabasePage`, **When** the workspace renders, **Then** the Connection tab is displayed inside `InnerTabView.TabStripHeader` at the leftmost position.
2. **Given** the Connection tab in `TabStripHeader`, **When** inspected visually, **Then** it displays the dedicated connection icon glyph (`\uE703`) instead of the previous globe icon (`\uE774`).
3. **Given** the Connection tab in `TabStripHeader`, **When** the user attempts to close it, **Then** no close button ('X') is rendered and the tab cannot be closed.

---

### User Story 2 - In-Page Dynamic Tab Reordering without New Window Spawn (Priority: P2)

As a database developer, I want to drag and reorder open database session tabs horizontally within `DatabasePage`'s inner tab strip to organize my workspace, while ensuring tabs never tear off into new OS windows.

**Why this priority**: Reordering workspace tabs is essential for productivity when managing multiple databases or table views simultaneously. Restricting tab dragging strictly to in-page reordering preserves clean single-window containment within the page.

**Independent Test**: Open two or more database connection tabs in `DatabasePage`. Click and drag one tab horizontally past another tab. Verify that the tab reorders smoothly within `InnerTabView`, and releasing the mouse outside the tab strip does not spawn a new window.

**Acceptance Scenarios**:

1. **Given** two or more dynamic database tabs open in `DatabasePage`, **When** the user drags a dynamic tab horizontally, **Then** the tab moves smoothly and reorders among other dynamic tabs.
2. **Given** dynamic tabs in `DatabasePage`, **When** the user drags a dynamic tab outside the bounds of `InnerTabView`, **Then** the tab is not torn off and no new OS window is spawned.
3. **Given** dynamic tabs are being reordered, **When** reviewing the Connection tab in `TabStripHeader`, **Then** the Connection tab remains immovably anchored at index 0 and is unaffected by the reorder operation.

---

### User Story 3 - Unified Viewport & Mutual Exclusion Selection (Priority: P3)

As an application user, I want clicking between the anchored Connection tab and dynamic database tabs to switch the active viewport view instantly with clear mutual exclusion visual states.

**Why this priority**: Seamless switching between the connection catalog explorer (`ConnectViewControl`) and active database workspace views (`DatabaseViewControl`) ensures responsive and predictable navigation.

**Independent Test**: Open a database connection tab, click the Connection tab in `TabStripHeader`, verify that `ConnectViewControl` is displayed; click the database tab, verify that `DatabaseViewControl` is displayed; close the database tab and verify selection automatically returns to the Connection tab.

**Acceptance Scenarios**:

1. **Given** a dynamic database tab is active, **When** the user clicks the Connection tab in `TabStripHeader`, **Then** the viewport displays the connection catalog (`ConnectViewControl`), the Connection tab reflects the selected visual state, and dynamic tabs are unselected.
2. **Given** the Connection tab is active, **When** the user clicks any dynamic database tab in `InnerTabView`, **Then** the viewport displays that database's session view (`DatabaseViewControl`), that tab becomes selected, and the Connection tab reflects the unselected state.
3. **Given** multiple dynamic tabs exist and the active tab is closed, **When** another dynamic tab remains, **Then** selection shifts to the adjacent tab; **When** no dynamic tabs remain, **Then** selection automatically falls back to the anchored Connection tab.

---

### User Story 4 - Visual Consistency & Dynamic Localization (Priority: P4)

As an international user, I want the Connection tab in `TabStripHeader` to maintain pixel-perfect pill styling matching `ShellWindow` and update its localized title dynamically when the application language changes.

**Why this priority**: Preserves Principle II (Fluent Design 2 standards) and Principle VII (Zero hardcoded strings and dynamic runtime internationalization).

**Independent Test**: Change the application language between English and Vietnamese in Settings. Verify that the Connection tab title updates immediately from "Connections" to "Kết nối" (and vice versa) without restarting the application or causing layout shift.

**Acceptance Scenarios**:

1. **Given** the Connection tab in `TabStripHeader`, **When** styled, **Then** it applies `PillTabViewItemStyle` with pill capsule geometry and background consistent with `DatabasePage`'s workspace canvas.
2. **Given** the application language is toggled in Settings, **When** returning to `DatabasePage`, **Then** the Connection tab header reflects the new language string instantly.

---

### Edge Cases

- **Only Connection Tab Open**: When 0 dynamic tabs are open, `InnerTabView` has 0 items; `ConnectViewControl` fills the viewport, and the Connection tab is the active visual tab.
- **Closing the Last Dynamic Tab**: When the last remaining dynamic database tab is closed, the view automatically activates the anchored Connection tab without leaving the viewport blank.
- **Drag Attempt on Anchored Connection Tab**: The Connection tab in `TabStripHeader` is non-draggable (`CanDrag="False"` / not in draggable item list), so dragging it produces no motion and does not initiate a reorder.
- **Opening an Already Open Connection**: Clicking "Open" on a connection in `ConnectViewControl` that is already open in a tab switches selection to that existing tab rather than opening a duplicate.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `DatabasePage` MUST anchor the Connection tab inside `InnerTabView.TabStripHeader` at the leftmost position, completely decoupled from `InnerTabs`.
- **FR-002**: The Connection tab MUST be permanently fixed, non-draggable, non-reorderable, and non-closable (`IsClosable="False"`).
- **FR-003**: The Connection tab MUST display the dedicated Connect icon glyph (`\uE703`) representing database connectivity, replacing the generic globe icon (`\uE774`).
- **FR-004**: `InnerTabView` MUST enable horizontal tab reordering (`CanReorderTabs="True"`) exclusively for dynamic tabs hosted in `InnerTabs`.
- **FR-005**: `InnerTabView` MUST NOT support tab tear-off to external windows (`CanDragTabs="False"`). Tab movement MUST be strictly bounded within the inner tab strip.
- **FR-006**: `DatabaseViewModel` MUST manage selection state with mutual exclusion between `IsConnectionSelected` (for the anchored Connection tab) and `SelectedInnerTab` (for dynamic workspace tabs).
- **FR-007**: Viewport content in `DatabasePage` MUST dynamically display `ConnectViewControl` when `IsConnectionSelected` is `true`, and the selected dynamic tab's content when a dynamic tab is active.
- **FR-008**: When all dynamic tabs in `InnerTabs` are closed, `DatabaseViewModel` MUST automatically set `IsConnectionSelected = true` and display the connection catalog.
- **FR-009**: The Connection tab title MUST bind dynamically via `TranslationSource` (`tab_connections_header`) to support live language switching per Principle VII.

### Key Entities

- **`ConnectionTab`**: The anchored, immovable tab item model / view component housed in `InnerTabView.TabStripHeader` representing the root connection catalog (`ConnectViewControl`).
- **`InnerTabItemModel`**: The model representing dynamic database workspace tabs (sessions, tables, query editors) managed inside `DatabaseViewModel.InnerTabs`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can drag and reorder dynamic database tabs horizontally within `DatabasePage` smoothly (<16ms frame time, 60 FPS).
- **SC-002**: 100% of drag operations on tabs within `DatabasePage` remain contained within the page; exactly 0 new OS windows are spawned.
- **SC-003**: The Connection tab remains 100% permanently anchored at the leftmost position across all tab additions, closures, and reorders.
- **SC-004**: Closing the last dynamic tab switches the viewport to `ConnectViewControl` in under 50ms with zero blank frames or visual clipping.
- **SC-005**: Language toggles in Settings reflect on the Connection tab header instantly (<50ms) across all open instances.

## Assumptions

- Dynamic tabs inside `DatabasePage` represent database sessions and child views (tables, queries) belonging strictly to the current window; they are not intended to be detached into independent top-level desktop windows.
- The dedicated glyph `\uE703` (Segoe Fluent Icon for "Connect") is fully available in Windows App SDK Segoe UI Variable fonts on Windows 10/11.
- `PillTabViewItemStyle` defined in `Themes/TabStyles.xaml` is reused directly for the anchored Connection tab in `InnerTabView.TabStripHeader`.
