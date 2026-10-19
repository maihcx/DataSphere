# Feature Specification: WinUI 3 Modern Tabbed Shell & Multi-Window Navigation

**Feature Branch**: `001-winui3-chrome-tabs`

**Created**: 2026-10-19

**Status**: Draft

**Input**: User description: "chuyển toàn bộ ứng dụng sang WinUI3 với 1 số thay đổi: loại bỏ hoàn toàn navigation, Thêm vào phía trên header bar một chrome tab (thay thế header thành chrome tab giống trình duyệt), trang mặc định hiển thị là Home (home giữ nguyên UI như hiện tại) và không cho phép đóng home, khi tôi vào home và nhấn "Cơ sở dữ liệu" hoặc "Cài Đặt" thì nó sẽ mở trang tương ứng (mở luôn cả tab phía trên), cho phép có nhiều phiên DataSphere mở cùng lúc và hỗ trợ kéo thả tab, kéo tab ra ngoài để tạo 1 cửa sổ mới, cho phép kéo tab từ cửa sổ mới vào tab của cửa sổ khác (trong trường hợp chỉ có 2 tab duy nhất (1 home và 1 settings hoặc 1 trang cơ sở dữ liệu) thì sẽ đóng luôn cửa sổ được kéo sang cửa sổ khác)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Browser-Style Chrome Tab Strip & Sidebar Navigation Removal (Priority: P1)

Users interact with DataSphere through a modern, browser-style tab strip integrated directly into the top window header bar. The traditional vertical sidebar navigation is completely eliminated to maximize workspace area for database tables, records, and SQL editors. The initial default view is the Home dashboard, permanently anchored as the first tab.

**Why this priority**: Establishes the foundational window shell layout, visual aesthetics, and primary viewport required by all subsequent features.

**Independent Test**: Launch the application; verify that no vertical left sidebar exists, the window title bar contains a browser-like tab strip, and the default "Home" tab is selected and displays the existing Home dashboard UI without a close button.

**Acceptance Scenarios**:

1. **Given** the application is launched, **When** the main window appears, **Then** the top header displays a horizontal Chrome-style tab strip and no sidebar navigation panel is visible.
2. **Given** the initial tab strip, **When** inspecting the "Home" tab, **Then** it has no close button (`X`) and cannot be closed via keyboard shortcut or middle-click.
3. **Given** the window title bar, **When** interacting with standard window controls (Minimize, Maximize, Close), **Then** they remain accessible on the top-right corner alongside the tab strip without visual overlapping.

---

### User Story 2 - Dynamic Page Tab Opening from Home Dashboard (Priority: P1)

From the Home Dashboard, when the user clicks on navigation cards such as "Cơ sở dữ liệu" (Database) or "Cài Đặt" (Settings), the system opens the selected page into a new tab in the top tab strip and immediately shifts focus to that tab. Unlike the Home tab, these dynamically opened tabs are closable.

**Why this priority**: Restores seamless accessibility to core app destinations (Database Explorer and Settings) following the retirement of the sidebar navigation.

**Independent Test**: From the Home tab, click the "Cài Đặt" card; verify a new "Cài Đặt" tab is added to the top tab bar, the view switches to the Settings page, and clicking the close button on the tab dismisses it and returns to the Home tab.

**Acceptance Scenarios**:

1. **Given** the user is viewing the Home tab, **When** the user clicks "Cơ sở dữ liệu", **Then** a new tab titled "Cơ sở dữ liệu" appears in the tab strip, becomes the active tab, and displays the database connection and object workspace.
2. **Given** the user is viewing the Home tab, **When** the user clicks "Cài Đặt", **Then** a new tab titled "Cài Đặt" appears in the tab strip, becomes the active tab, and displays the application settings.
3. **Given** an open "Cài Đặt" or "Cơ sở dữ liệu" tab, **When** the user clicks the close icon (`X`) on the tab or presses `Ctrl+W`, **Then** that tab closes and focus switches to the preceding active tab.
4. **Given** an existing open tab for a destination, **When** the user clicks that same card again from the Home tab, **Then** the application switches active focus to the existing open tab rather than creating redundant duplicates (or creates an independent connection tab if explicitly requested).

---

### User Story 3 - Multi-Window Tab Drag & Drop, Tear-Off & Docking (Priority: P2)

Users can drag any open closable tab outside of its parent window to automatically tear it off into a new, independent DataSphere window. Users can also drag a tab from one window and drop it onto the tab strip of another window to dock it. If a donor window only possesses 2 tabs (the non-closable Home tab and 1 content tab such as Settings or a Database connection) and that content tab is dragged out to another window, the donor window automatically closes.

**Why this priority**: Delivers enterprise-grade multi-monitor flexibility, allowing database developers to compare schemas, inspect query outputs, and organize tasks across multiple screens.

**Independent Test**: Open a Database tab in Window 1 (having Home and Database). Drag the Database tab outside to the desktop; verify a new Window 2 appears with the Database tab. Drag the Database tab from Window 2 back into Window 1; verify Window 2 closes automatically because its sole content tab was moved away, leaving Window 1 with both tabs.

**Acceptance Scenarios**:

1. **Given** a window with multiple tabs, **When** a user clicks and drags a content tab away from the tab strip into empty desktop space, **Then** a new window is instantiated hosting the dragged tab.
2. **Given** two separate DataSphere windows, **When** a user drags a content tab from Window B and drops it onto the tab strip of Window A, **Then** the tab is docked into Window A at the dropped position.
3. **Given** a window containing exactly 2 tabs (Home and 1 Content tab), **When** the user drags that Content tab out to dock into another window, **Then** the donor window closes automatically upon transfer completion.
4. **Given** the anchored "Home" tab, **When** a user attempts to drag the "Home" tab outside the window, **Then** the tear-off action is prevented or restricted so that the Home tab remains anchored to its parent window.

---

### User Story 4 - Multi-Instance Concurrency (Priority: P2)

Users can launch multiple independent DataSphere application instances from the Windows Start Menu, desktop shortcut, or taskbar simultaneously without being blocked by single-instance mutex locks.

**Why this priority**: Enables developers to manage completely distinct database cluster sessions in parallel windows without forced instance merging.

**Independent Test**: Launch DataSphere from the executable; once open, launch DataSphere again from another terminal or shortcut; verify that a second independent DataSphere window opens cleanly without closing the first instance.

**Acceptance Scenarios**:

1. **Given** one running DataSphere instance, **When** a user launches a second DataSphere process, **Then** a new DataSphere window opens independently with its own tab strip and Home dashboard.
2. **Given** multiple running instances, **When** database queries execute in one instance, **Then** background threads in other instances remain unaffected and responsive.

---

### Edge Cases

- **Re-ordering Tabs within the Same Window**: Dragging a tab horizontally within the tab strip without leaving the header boundary must smoothly re-order the tab index without triggering tear-off.
- **Dropping a Tab into Non-DataSphere Windows**: If a dragged tab is released over an unsupported application or invalid desktop area, it must spawn a new DataSphere window at the drop coordinates rather than vanishing or crashing.
- **Closing a Window with Active Transactions**: If a window with active database queries or uncommitted transactions is closed, the system must prompt the user or cleanly cancel pending asynchronous operations before disposing the window.
- **Multi-Monitor DPI Differences**: Dragging a tab from a 100% DPI monitor to a 150% DPI monitor must properly scale the window layout and font rendering without clipping.
- **Rapid Dragging & Drop Abort**: Pressing `Escape` during a tab drag operation must abort the drag and restore the tab to its original position.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST replace the legacy titlebar and sidebar navigation layout with a top-anchored Chrome-style horizontal tab strip integrated into the window header.
- **FR-002**: The system MUST render an anchored "Home" tab as the default first tab in every window.
- **FR-003**: The "Home" tab MUST NOT display a close button and MUST NOT be closeable via user interaction.
- **FR-004**: The system MUST preserve the visual layout, referral card, and navigation presenter of the existing Home/Dashboard view inside the Home tab.
- **FR-005**: Clicking the "Cơ sở dữ liệu" navigation card from the Home dashboard MUST open a "Cơ sở dữ liệu" tab in the active window's tab strip.
- **FR-006**: Clicking the "Cài Đặt" navigation card from the Home dashboard MUST open a "Cài Đặt" tab in the active window's tab strip.
- **FR-007**: All non-Home tabs MUST display an interactive close button (`X`) and close upon clicking or pressing `Ctrl+W`.
- **FR-008**: The system MUST support dragging any non-Home tab outside the window bounds to tear it off into a new independent DataSphere window.
- **FR-009**: The system MUST support dragging a non-Home tab from one DataSphere window and dropping it onto the tab strip of another DataSphere window to dock it.
- **FR-010**: When a non-Home tab is moved away from a window that only contains 2 tabs (1 Home tab + 1 content tab), the donor window MUST automatically close upon transfer completion.
- **FR-011**: The system MUST allow multiple concurrent DataSphere instances and windows to run without being restricted by a single-instance process lock.
- **FR-012**: When a tab is closed, the system MUST gracefully release associated database connections, background tasks, and view resources.
- **FR-013**: The tab strip MUST include standard caption controls (Minimize, Maximize/Restore, Close) aligned to the right edge with proper hit-testing.
- **FR-014**: The tab strip MUST provide horizontal scrolling or dropdown overflow when the number of open tabs exceeds the available window width.
- **FR-015**: Tab selection changes MUST update the central content area with smooth page transitions and zero visual stutter.

### Key Entities

- **WindowSession**: Represents an active top-level application window containing a tab collection, window caption controls, and root content host.
- **TabItemModel**: Represents an individual tab within the tab strip. Key attributes include:
  - `Id`: Unique identifier for the tab session.
  - `Title`: Display name (e.g. "Home", "Cơ sở dữ liệu", "Cài Đặt").
  - `Icon`: Fluent symbol icon representing the tab content.
  - `ContentType`: Identifier or type of the hosted page.
  - `IsClosable`: Boolean indicating whether the tab can be closed (False for Home, True for content tabs).
  - `IsActive`: Boolean indicating whether the tab is currently focused.
- **NavigationCard**: Data model representing clickable destination cards on the Home dashboard that trigger tab creation.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of vertical sidebar navigation UI elements are removed, providing at least 200px of additional horizontal workspace for database views.
- **SC-002**: Launching the application displays the Home tab in under 1.5 seconds on standard hardware.
- **SC-003**: Clicking a navigation card on the Home dashboard opens the corresponding tab and displays its content in less than 150 milliseconds.
- **SC-004**: Tab tear-off into a new window and tab re-docking between windows complete with 0 visual tearing, 0 process crashes, and 60 FPS fluid drag feedback.
- **SC-005**: 100% of 2-tab donor windows (Home + 1 Content tab) automatically close upon transferring the content tab to another window, leaving zero ghost windows or memory leaks.
- **SC-006**: Multiple application processes can execute concurrently with zero instance collisions.

---

## Assumptions

- The target UI framework is modern Windows App SDK (WinUI 3) on .NET 10, utilizing native `TabView` controls with drag-and-drop tear-out support.
- Localization strings for Vietnamese and English are maintained for all tab titles and dashboard cards.
- Database connection sessions opened within separate tabs operate on independent or shared connection pools as defined by database configuration.
- Existing business logic and database drivers (`MySqlConnector`, `PasswordEncryptor`) remain compatible and require no behavioral alterations during the shell migration.
