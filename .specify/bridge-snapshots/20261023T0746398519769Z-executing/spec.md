# Feature Specification: Fluent Tab Selection Pill, Sliding Background & Directional Page Motion

**Feature Branch**: `018-tab-motion-and-indicator`

**Created**: 2026-10-23

**Status**: Ready for Planning

**Input**: User description: "chỉnh sửa TabMotionConfiguration và SlidingTabIndicatorBehavior:
- với tab: thanh màu nhấn không tuân thủ màu nhấn accent của win11, và nó trông khá thô, giúp tôi thu nhỏ nó lại cho đỡ thô hơn và bo góc nó cho giống với pill selected của tree (hình 1 - localhost, trong tree thì nó dọc nhưng tôi muốn nó ngang cho Tab) - hiện tại chỉ có Indicator là chuyển, có cách nào dịch chuyển luôn cả background không?
- với trang (TabMotionConfiguration) tôi muốn có hiệu ứng trượt ngang theo thứ tự tab và hiệu ứng diễn ra dài hơn 1 chút, hiện tại là quá ngắn"

## Clarifications

### Session 2026-10-23

- Q: Bạn muốn cơ chế chuyển đổi background của tab được hiển thị như thế nào khi chuyển tab? → A: Option A - Sliding Background Capsule (Tạo một background capsule bo góc CornerRadius 6px trượt mượt mà cùng với accent indicator từ tab cũ sang tab mới. Các tab chưa chọn có nền trong suốt, tạo hiệu ứng tab floating pill hiện đại chuẩn Fluent Design).
- Q: Kích thước cụ thể của thanh pill nằm ngang ở tab nên được cấu hình ra sao? → A: Option A - Compact Fixed-Width Pill (20px × 3px, bo tròn CornerRadius 1.5px, căn giữa theo chiều ngang ở đáy tab active giống với pill dọc trong tree view).
- Q: Thời lượng hiệu ứng trượt ngang của trang nên kéo dài bao lâu? → A: Option B - 300ms với độ trượt ngang ±32px và Decelerate Easing curve (0.1, 0.9, 0.2, 1.0) cho cảm giác chuyển trang đằm, mượt và rõ rệt hơn.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Refined Windows 11 Accent Pill Indicator & Sliding Tab Background (Priority: P1)

When a user selects or switches tabs in the application tab bar (both shell-level tabs and database workspace tabs), the active selection visual provides a cohesive, refined Windows 11 Fluent experience:
1. The accent indicator strictly adopts the user's active Windows 11 system accent color rather than a hardcoded default blue/teal.
2. The indicator is styled as an elegant, compact horizontal rounded pill (20px width × 3px height with fully rounded 1.5px corners, mirroring the vertical selection pill seen in the sidebar tree view) positioned horizontally and centered at the bottom of the active tab.
3. The tab selection background transitions smoothly as a floating capsule (matching the tab item's 6px corner radius) sliding from the previous tab to the newly selected tab alongside the accent pill indicator, eliminating visual popping or disjointed movement.

**Why this priority**: Resolves the crude appearance and color misalignment reported by the user, achieving full aesthetic consistency with Windows 11 system theming and Fluent Design standards.

**Independent Test**: Switch between tabs in the tab strip; verify that the indicator matches the active Windows 11 system accent color, renders as a 20px × 3px rounded pill, and the selection background capsule slides smoothly across tabs without visual popping.

**Acceptance Scenarios**:

1. **Given** a user with a customized Windows 11 accent color (e.g. Teal, Purple, Orange, or Blue), **When** DataSphere is running in either Light or Dark theme, **Then** the active tab indicator displays the exact corresponding Windows 11 system accent color.
2. **Given** multiple tabs in the tab strip, **When** switching to a different tab, **Then** the tab selection indicator renders as a horizontal rounded pill (20px × 3px, CornerRadius 1.5px) centered at the bottom of the active tab header.
3. **Given** two or more open tabs, **When** the user clicks an unselected tab, **Then** the selection background capsule slides fluidly from the old tab's bounding box to the new tab's bounding box in tandem with the accent pill.

---

### User Story 2 - Tab-Order-Aware Horizontal Page Content Sliding Transition (Priority: P1)

When switching between tabs in the application shell or database workspace, the active page content hosted in the viewport enters with a smooth horizontal sliding animation whose direction corresponds to the tab sequence (sliding in from the right when navigating to a tab to the right; sliding in from the left when navigating to a tab to the left). Furthermore, the motion duration is tuned to 300ms with a horizontal translation offset of ±32px using Fluent Decelerate easing, allowing users to clearly perceive the fluid spatial relationship between views.

**Why this priority**: Enhances spatial continuity and visual clarity when navigating between tabs, ensuring the page entrance motion reflects directional intent and feels graceful rather than rushed.

**Independent Test**: Open three tabs (Tab 1, Tab 2, Tab 3). Switch from Tab 1 to Tab 3 and observe horizontal slide from right to left; switch from Tab 3 to Tab 1 and observe horizontal slide from left to right; verify the animation duration runs for 300ms with smooth deceleration.

**Acceptance Scenarios**:

1. **Given** Tab 1 is currently active, **When** the user selects Tab 2 (located to the right of Tab 1), **Then** Tab 2's content slides horizontally into view from right to left (+32px to 0px) over 300ms with Fluent Decelerate easing.
2. **Given** Tab 2 is currently active, **When** the user selects Tab 1 (located to the left of Tab 2), **Then** Tab 1's content slides horizontally into view from left to right (-32px to 0px) over 300ms with Fluent Decelerate easing.
3. **Given** rapid consecutive tab switching, **When** transitions are initiated, **Then** the viewport immediately redirects to the target view smoothly without flicker or stuck visual states.

---

### User Story 3 - System Accessibility & Motion Suppression (Priority: P2)

Users who have disabled visual animation effects in Windows system settings (Settings > Accessibility > Visual Effects > Animation effects = Off) receive instantaneous tab selection and page viewport switching with zero animation delay or motion artifacts.

**Why this priority**: Respecting operating system accessibility preferences is essential for accessibility compliance and user comfort.

**Independent Test**: Toggle Windows animation effects off; verify tab selection indicator, background capsule, and page viewport switch instantaneously (<1ms).

**Acceptance Scenarios**:

1. **Given** Windows animation effects are disabled at the OS level, **When** the user switches tabs, **Then** the indicator, background capsule, and page content switch immediately with 0ms transition duration.

---

### Edge Cases

- **Rapid Consecutive Tab Switching**: When a user rapidly clicks multiple tabs in quick succession, running animations for both the tab header and the page viewport must cleanly retarget to the final active tab without ghosting, overlapping content, or misaligned pills.
- **Dynamic Tab Addition and Removal**: When a tab is closed or a new tab is opened, the indicator and background capsule must update coordinates accurately without jumping to invalid positions or throwing errors.
- **Variable Tab Widths**: Tabs with different title lengths (e.g., short "Home" vs. long "localhost (Production MySQL)") must smoothly animate width and position so both the pill indicator and background capsule adapt to the target tab's dimensions.
- **Theme and Accent Color Changes at Runtime**: When the user changes Windows accent color or toggles Dark/Light mode in Settings, the indicator and background capsule must refresh their colors dynamically without requiring an app restart.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The tab selection indicator MUST dynamically retrieve and apply the active Windows 11 system accent color in both Light and Dark themes.
- **FR-002**: The tab selection indicator MUST be styled as a compact horizontal rounded pill with dimensions of 20px (width) × 3px (height) and corner radius of 1.5px (fully rounded ends), centered horizontally at the bottom of the active tab header.
- **FR-003**: The tab selection indicator MUST smoothly slide horizontally from the previous tab's position to the new tab's position using hardware-accelerated composition motion.
- **FR-004**: The tab selection background MUST transition using a smooth, hardware-accelerated sliding background capsule with corner radius 6px (matching tab item capsule geometry) that translates seamlessly between the previous and target tab positions alongside the accent pill indicator, while inactive tabs maintain transparent backgrounds to create a cohesive floating pill selection motion.
- **FR-005**: The page content viewport transition MUST animate along the horizontal axis, with direction dynamically determined by the relative order of the active tab:
  - If target tab index > previous tab index (moving right): incoming content enters from the right (+32px to 0px).
  - If target tab index < previous tab index (moving left): incoming content enters from the left (-32px to 0px).
- **FR-006**: The page content viewport transition MUST execute with a duration of 300ms and a horizontal slide distance of ±32px using the Windows 11 Fluent Decelerate cubic-bezier curve (0.1, 0.9, 0.2, 1.0).
- **FR-007**: Both tab header motion and page viewport motion MUST query operating system accessibility settings (`UISettings.AnimationsEnabled`) and execute instantaneously when animation effects are disabled.
- **FR-008**: The implementation MUST preserve Clean MVVM architecture (zero business logic or manual DOM manipulation in view code-behind; all transitions encapsulated cleanly in control/behavior layers).

### Key Entities

- **`TabSelectionVisual`**: Encapsulates the visual state of the active tab, including the Windows 11 accent pill indicator and the moving background capsule.
- **`TabMotionConfiguration`**: Centralized configuration providing duration, easing curves, offset metrics, and accessibility checks for tab and page transitions.
- **`SlidingTabIndicatorBehavior`**: Attached behavior managing the hardware-accelerated animated positioning of the accent pill and selection background capsule across tab items.
- **`CachedContentControl`**: Viewport host managing cached view lifecycle and executing directional horizontal slide-in animations based on tab navigation order.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Tab selection indicator accurately reflects the active Windows 11 system accent color across Light and Dark themes with 100% color fidelity.
- **SC-002**: Tab selection indicator renders with pill-shaped rounded corners (20px × 3px, CornerRadius 1.5px), reducing perceived visual bulkiness compared to the previous full-width rectangle.
- **SC-003**: Tab selection background capsule transitions smoothly between tabs without instantaneous color jumping or visual snapping.
- **SC-004**: Page content transitions horizontally in the correct directional orientation (right-to-left for forward navigation, left-to-right for backward navigation) with zero visual glitches or reversed motion.
- **SC-005**: Page transition animation executes smoothly at 60 FPS (<16ms per frame) over the configured 300ms duration without UI thread stalling.
- **SC-006**: When OS animations are disabled, tab and page transitions complete instantaneously (<1ms).

## Assumptions

- Target operating environment is Windows 10/11 running WinUI 3 with hardware acceleration enabled.
- The tab strip uses the existing `TabView` control and `CachedContentControl` viewport architecture established in the application shell and database pages.
- Tab indices are sequentially ordered from left to right (0, 1, 2, ...), allowing reliable direction calculation when switching tabs.
- The Windows 11 system accent color is accessible via standard platform resources or `UISettings.GetColorValue(UIColorType.Accent)`.
