# Feature Specification: Home Tab in TabStripHeader with Lifecycle Logic Preservation

**Feature Branch**: `013-home-tab-tabstripheader`

**Created**: 2026-10-22

**Status**: Draft

**Input**: User description: "đem tab home vào TabStripHeader và duy trì logic hiện tại: - khi chỉ có tab home thì home mới xuất hiện nút close - tab home không có khả năng di chuyển - tab home đóng lại đồng nghĩa với việc đóng app - tab home không thể đóng khi có nhiều hơn 2 tab"

## Clarifications

### Session 2026-10-22

- Q: Bạn muốn cấu trúc và vị trí của tệp theme chứa Style tab pill được lưu trữ tại đâu trong dự án? → A: Option A - Tạo tệp riêng `Themes/TabStyles.xaml` (chứa `PillTabViewItemStyle` và các TabView theme overrides) rồi merge vào `App.xaml` để cả `ShellWindow` và `DatabasePage` tái sử dụng.
- Q: Bạn muốn TabView con (InnerTabView) trong DatabasePage có áp dụng cả kiểu dáng không viền dưới (borderless tab strip) giống như ShellTabView không? → A: Nền từ thanh tab con đến toàn bộ vùng nội dung bên dưới tab trong DatabasePage sẽ có màu nền đồng nhất với màu nền của tab đang chọn (chỉ áp dụng riêng cho DatabasePage, không làm thay đổi nền trong suốt của ShellWindow).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Home Tab Anchored in TabStripHeader (Priority: P1)

As an application user, I want the Home tab to be anchored inside the `TabStripHeader` region to the left of the dynamic tab strip, so that Home remains a dedicated, fixed entry point that is visually distinct from ephemeral workspace tabs.

**Why this priority**: Anchoring the Home tab in `TabStripHeader` establishes a clean structural hierarchy between the permanent home dashboard and dynamic database/query tabs, preventing accidental rearrangement or tab clutter.

**Independent Test**: Launch DataSphere and observe the titlebar tab strip. Verify that the Home tab is positioned inside the header area to the left of the dynamic tab items, styled with standard pill capsule visual aesthetics, and provides a clear title and icon.

**Acceptance Scenarios**:

1. **Given** the application starts up, **When** the shell window is displayed, **Then** the Home tab is rendered inside the `TabStripHeader` at the leftmost position of the tab strip.
2. **Given** one or more dynamic database tabs are opened, **When** reviewing the tab strip layout, **Then** dynamic tabs appear in the scrollable tab list to the right of the anchored Home tab.
3. **Given** the Home tab in `TabStripHeader`, **When** inspected visually, **Then** its pill capsule styling (border radius, padding, icon glyph, and text font) matches the application's modern Fluent Design 2 pill tab visual standard.

---

### User Story 2 - Seamless Selection & Unified Viewport Navigation (Priority: P2)

As an application user, I want clicking the Home tab in `TabStripHeader` to activate the Home view in the central viewport, while selecting any dynamic tab displays that tab's content and visually unselects the Home tab.

**Why this priority**: Tab switching must remain intuitive and unified. The user expects mutual exclusion where exactly one view (Home or a dynamic tab) is selected and displayed in the main viewport at any given moment.

**Independent Test**: Open a dynamic tab (e.g. Database connection or Query editor), click between the Home tab in `TabStripHeader` and the dynamic tab in `ShellTabView`, and verify that the main viewport content presenter switches accurately and instantly.

**Acceptance Scenarios**:

1. **Given** a dynamic tab is currently active, **When** the user clicks the Home tab in `TabStripHeader`, **Then** the main viewport displays `HomePage`, the Home tab reflects the selected visual state, and the dynamic tab in `ShellTabView` is unselected.
2. **Given** the Home tab is currently active, **When** the user clicks any dynamic tab in `ShellTabView`, **Then** the main viewport immediately displays that dynamic tab's content, that dynamic tab becomes selected, and the Home tab reflects the unselected visual state.
3. **Given** multiple dynamic tabs exist and the active dynamic tab is closed, **When** another dynamic tab remains, **Then** selection shifts to an adjacent dynamic tab; **When** no dynamic tabs remain, **Then** selection automatically shifts to the Home tab.

---

### User Story 3 - Home Close Button Visibility & Window Shutdown Lifecycle (Priority: P3)

As an application user, I want the Home tab's close button to appear only when Home is the sole tab open, so that closing Home explicitly closes the entire application, while preventing Home from being closed whenever additional tabs are present.

**Why this priority**: Preserves the core lifecycle rule of DataSphere: Home is the root tab. If the user closes the last remaining tab (Home), the application exits cleanly. If any work tabs are open, Home cannot be closed, preventing accidental session termination.

**Independent Test**:
1. At application launch with only Home open: confirm the close button ('X') is visible on the Home tab. Click 'X' and confirm the window closes and application terminates.
2. Open one dynamic tab (total 2 tabs): confirm the close button ('X') on the Home tab vanishes.
3. Open two dynamic tabs (total 3 tabs): confirm the close button ('X') on the Home tab remains hidden.
4. Close all dynamic tabs until only Home remains: confirm the close button ('X') reappears on Home.

**Acceptance Scenarios**:

1. **Given** only the Home tab is open (zero dynamic tabs), **When** the user inspects the Home tab, **Then** the close button ('X') is visible and interactive.
2. **Given** only the Home tab is open, **When** the user clicks the close button ('X') on the Home tab, **Then** the application session is closed and the window exits cleanly.
3. **Given** one or more dynamic tabs are open (total tab count >= 2), **When** inspecting the Home tab in `TabStripHeader`, **Then** its close button ('X') is completely hidden (collapsed) and Home cannot be closed through UI or keyboard shortcuts.
4. **Given** one dynamic tab is open alongside Home, **When** the user closes that dynamic tab, **Then** the dynamic tab is removed, Home becomes the sole remaining tab, and the close button ('X') immediately reappears on the Home tab.

---

### User Story 4 - Tab Immobility & Drag Protection for Anchored Home (Priority: P4)

As an application user, I want the Home tab to be completely immune to drag, reorder, or tear-off operations, ensuring it remains permanently stationed at the leftmost anchor point.

**Why this priority**: The Home tab acts as the primary anchor of the window. Allowing it to be dragged or torn off into another window would break the window's foundational hierarchy.

**Independent Test**: Attempt to click and drag the Home tab horizontally or vertically outside the window. Verify that no drag operation starts, the tab does not move, and dragging dynamic tabs around it does not reorder or dislodge Home.

**Acceptance Scenarios**:

1. **Given** the Home tab in `TabStripHeader`, **When** the user clicks and drags the Home tab, **Then** the tab does not move, no drag payload is initiated, and no tear-off occurs.
2. **Given** dynamic tabs in `ShellTabView`, **When** the user drags and reorders dynamic tabs, **Then** dynamic tabs reorder freely among themselves while the Home tab remains immovably anchored in `TabStripHeader`.
3. **Given** dynamic tabs from another DataSphere window, **When** dropped onto the tab strip, **Then** they are appended or inserted into the dynamic tab strip to the right of the Home tab.

---

### User Story 5 - Reusable Pill Tab Theme in Database Workspace (Priority: P5)

As an application user, I want the inner tabs within `DatabasePage` (tables, views, queries) to display the same polished pill capsule styling as the main window tabs, so that visual consistency is maintained across all levels of the application.

**Why this priority**: Unifying the visual presentation of tabs in both top-level and inner workspaces delivers a cohesive, premium Fluent Design 2 experience and eliminates disjointed styling.

**Independent Test**: Navigate to `DatabasePage` with active database connection, open one or more inner tabs (tables, query editors), and verify that inner tabs display the pill-shaped geometry, rounded corners, and state brushes provided by the shared `Themes/TabStyles.xaml` resource dictionary.

**Acceptance Scenarios**:

1. **Given** `DatabasePage` is open with inner tabs, **When** the user views `InnerTabView`, **Then** the inner tab headers display as rounded pill capsules matching the style of `ShellWindow`.
2. **Given** an inner tab in `DatabasePage`, **When** selected or hovered, **Then** its pill background and foreground reflect standard theme brushes without hardcoded color artifacts.
3. **Given** `DatabasePage` is active, **When** inspecting the inner workspace background from `InnerTabView` down through the active tab content area, **Then** the background is uniform with the tab surface color, seamlessly uniting the inner workspace.

---

### Edge Cases

- **Single Tab Launch**: When the application launches with only Home, the close button is visible. Clicking close immediately triggers clean shutdown.
- **Dynamic Tab Opening**: Opening a new tab (e.g. from Home page connection cards) immediately collapses the Home close button without visual flicker.
- **Multiple Tabs Closure to Zero**: Closing the penultimate tab (leaving only 1 dynamic tab + Home) keeps Home unclosable. Closing the final dynamic tab immediately uncollapses the Home close button and sets Home as active.
- **Tab Drag Over Header**: When a dynamic tab is dragged across the tab bar, `TabStripHeader` rejects dropping items before or onto the Home tab, ensuring Home always occupies index 0 conceptually.
- **Window Resizing to Minimum Width**: When the window is resized to its minimum dimensions (`MinWidth="800"`), the Home tab in `TabStripHeader` retains its fixed minimum width, and any tab strip overflow is handled by `ShellTabView`'s internal scroll buttons.
- **Dynamic Localization Change**: When the application language switches between English and Vietnamese, the Home tab title refreshes dynamically to `"Home"` or `"Trang chủ"` via `page_home_title`.
- **System Theme Switch**: Switching between Light and Dark themes dynamically updates the background, border stroke, and text foreground of the Home tab in `TabStripHeader`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST relocate the Home tab into `TabView.TabStripHeader` of `ShellTabView`, separating it from the dynamic `TabItemsSource` collection.
- **FR-002**: System MUST render the Home tab in `TabStripHeader` using visual styling identical to pill tabs (`PillTabViewItemStyle` or equivalent capsule geometry, corner radius, padding, and state brushes).
- **FR-003**: System MUST provide mutual exclusion between Home selection and dynamic tab selection:
  - When Home is selected, `HomePage` is displayed in the main viewport and `ShellTabView.SelectedItem` is deselected.
  - When a dynamic tab is selected, its content is displayed in the main viewport and the Home tab reflects the unselected visual state.
- **FR-004**: System MUST display the close button ('X') on the Home tab if and only if Home is the sole remaining tab in the window (dynamic tabs count == 0).
- **FR-005**: System MUST hide (collapse) and disable the close button on the Home tab whenever one or more dynamic tabs are open (dynamic tabs count >= 1, meaning total tabs >= 2).
- **FR-006**: System MUST terminate the application session and close the window when the user triggers the close action on the Home tab while it is the sole remaining tab.
- **FR-007**: System MUST prohibit dragging, reordering, or tearing off the Home tab, keeping it immovably anchored inside `TabStripHeader`.
- **FR-008**: System MUST automatically transition active selection to the Home tab when the last remaining dynamic tab in `ShellTabView` is closed.
- **FR-009**: System MUST bind the Home tab header text to the localization resource key `page_home_title` via `TranslationSource` to support instant dynamic i18n without application restart (Principle VII).
- **FR-010**: System MUST maintain custom titlebar drag regions adjacent to the Home tab in `TabStripHeader` and in `TabStripFooter` to preserve smooth window dragging and snapping.
- **FR-011**: System MUST keep the main content viewport decoupled from `TabView` in a separate layout row (Principle VII layout mandate).
- **FR-012**: System MUST document all modified and new classes, methods, and properties with 100% US English XML doc comments (Principle V).
- **FR-013**: System MUST extract `PillTabViewItemStyle` and shared TabView styling resources from `ShellWindow.xaml` into a dedicated theme dictionary file at `DataSphere/Themes/TabStyles.xaml` and merge it into `App.xaml` (`ResourceDictionary.MergedDictionaries`).
- **FR-014**: System MUST update `DatabasePage.xaml`'s `InnerTabView` to apply `PillTabViewItemStyle` to its `TabViewItem` items, reusing the shared theme resource.
- **FR-015**: System MUST configure the background of the `DatabasePage` inner workspace (from the tab strip through the active content viewport below) to be uniform with the tab's background (`LayerFillColorDefaultBrush` / container fill), uniquely applied to `DatabasePage` without affecting `ShellWindow`'s transparent titlebar backdrop.

### Key Entities *(include if feature involves data)*

- **`TabStripHeader`**: The visual container at the left of the `ShellTabView` header row, housing the anchored Home tab and the left titlebar drag handle.
- **`TabItemModel`**: Domain entity representing individual tab metadata (`TitleKey`, `Title`, `IconGlyph`, `IsClosable`, `Content`, `PageType`, `State`).
- **`ShellViewModel`**: Presentation coordinator managing the dynamic tabs collection (`Tabs`), Home tab state (`HomeTab`, `IsHomeSelected`), selection transitions, closability rules, and window closure events.
- **`HomePage` / `HomeViewModel`**: The primary dashboard view and viewmodel hosted within the Home tab.
- **`Themes/TabStyles.xaml`**: Standalone shared ResourceDictionary defining `PillTabViewItemStyle` and reusable TabView visual tokens.
- **`DatabasePage`**: Page host managing inner tabs (`InnerTabs`) utilizing the shared `PillTabViewItemStyle`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Home tab is rendered exclusively inside `TabStripHeader` and never appears in the draggable `TabItemsSource` collection.
- **SC-002**: When only Home is open, the close button ('X') is visible with 100% reliability, and clicking it closes the window and application process in under 500ms.
- **SC-003**: When dynamic tabs count >= 1 (total tabs >= 2), the Home close button is 100% hidden, and the Home tab cannot be closed.
- **SC-004**: Tab switching between the Home tab and dynamic tabs occurs with zero perceptible latency (<16ms, maintaining 60 FPS).
- **SC-005**: Dragging actions on the Home tab are 100% ignored (0 movement, 0 tear-off triggers).
- **SC-006**: Closing the last open dynamic tab immediately refocuses Home in under 100ms and restores the Home close button.
- **SC-007**: 100% compliance with zero hardcoded user-facing strings (all strings resolved via `.resx`) and 0 build errors.

## Assumptions

- The Home tab remains a singleton view throughout the window session and cannot be duplicated.
- Window titlebar drag handling continues to operate smoothly using `CustomDragRegionLeft` and `CustomDragRegion` in `TabStripFooter`.
- Dynamic tabs in `ShellTabView` continue to support tab dragging, reordering, tearing off to new windows, and closing.
- Decoupled `ContentPresenter` architecture in Grid Row 1 remains unchanged.
