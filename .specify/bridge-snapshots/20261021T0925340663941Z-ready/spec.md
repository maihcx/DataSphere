# Feature Specification: Pill-Shaped TabViewItem Styling and Borderless TabStrip

**Feature Branch**: `012-pill-tabview-styling`

**Created**: 2026-10-21

**Status**: Draft

**Input**: User description: "tôi mong muốn các TabViewItem sẽ hiển thị giống hình viên thuốc và loại bỏ viền border phía dưới của nó (ranh giới giữa page và TabView)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pill-Shaped TabViewItem Visual Styling (Priority: P1)

As an application user, I want the window tab headers to display as modern, floating pill-shaped (capsule) items with fully rounded corners, so that each open tab looks distinct, clean, and visually refined according to modern Fluent Design standards.

**Why this priority**: The tab strip is located in the window titlebar and is visible 100% of the time. Replacing conventional rectangular/chrome tabs with pill-shaped tabs directly elevates the visual identity of the entire application.

**Independent Test**: Can be tested by opening DataSphere with one or more tabs (e.g. Home, Database, Settings), inspecting the visual geometry of the tab headers, and verifying that each tab renders as an isolated capsule with rounded corners (`CornerRadius`), clear padding, and distinct visual states for selected, unselected, and hover.

**Acceptance Scenarios**:

1. **Given** multiple open tabs in the window titlebar, **When** the user views the tab strip, **Then** each tab item appears as an independent rounded pill capsule with balanced margins separating it from adjacent tabs.
2. **Given** a pill-shaped tab item, **When** the tab is selected, **Then** its surface displays an active pill background contrasting softly against the window backdrop, with full visual clarity in both Light and Dark themes.
3. **Given** an unselected pill tab, **When** the user hovers the cursor over it, **Then** it presents a subtle rounded hover state before settling back on pointer exit.

---

### User Story 2 - Borderless Seamless Separation between TabView and Page Content (Priority: P2)

As an application user, I want the horizontal divider line underneath the TabView to be completely removed, so that the tab strip seamlessly flows into the page content without an artificial cutting line dividing the titlebar and viewport.

**Why this priority**: Removing the bottom border creates a cohesive, fluid canvas where content and navigation breathe naturally together, eliminating visual clutter.

**Independent Test**: Can be tested by launching the application, observing the boundary between the bottom edge of the TabView tab strip and the top edge of the active page (Home or Database), and confirming that no 1px border line or stroke exists.

**Acceptance Scenarios**:

1. **Given** the application shell window is active, **When** inspecting the horizontal boundary between the TabView header row and the content presenter row, **Then** no bottom border line or separator stroke is visible.
2. **Given** any system backdrop material is active (Mica, Tabbed, Acrylic, or Solid), **When** switching tabs, **Then** the background behind the pill tabs remains translucent or solid according to the window theme, without border artifacts.

---

### User Story 3 - Full Interaction & Chrome Lifecycle Preservation (Priority: P3)

As an application user, I want all existing tab strip interactions (tab switching, closing tabs via close button, reordering tabs via drag, and dragging the window titlebar) to remain fully responsive and functional with the new pill styling.

**Why this priority**: Visual enhancements must preserve 100% of usability and interaction physics without regressions in drag handling, closing, or titlebar integration.

**Independent Test**: Can be tested by opening multiple tabs, reordering tabs by dragging, clicking the close button on closable tabs, and dragging the window by the titlebar drag areas.

**Acceptance Scenarios**:

1. **Given** multiple pill tabs, **When** the user drags a tab to a new position, **Then** the tab reorders smoothly with visual drag feedback and settles into its new slot.
2. **Given** a closable pill tab, **When** the user clicks the 'X' close button, **Then** the tab closes properly and selection shifts to an adjacent tab without layout glitches.
3. **Given** the custom drag regions to the left and right of the pill tab strip, **When** the user clicks and drags, **Then** the application window moves fluidly across the desktop.

---

### Edge Cases

- **Overflow of many tabs**: When many tabs are opened, the TabView scroll buttons must appear and scroll the pill capsules smoothly without clipping pill borders.
- **Theme switching (Light vs Dark)**: Pill background brushes, hover highlights, and text foregrounds must adapt dynamically without hardcoded colors or contrast issues.
- **High-contrast mode**: When Windows High Contrast is enabled, pill borders must render visible focus rectangles and accessibility outlines complying with WCAG contrast ratios.
- **Window resizing**: When the window is made narrow, pill tabs must condense or scroll gracefully without pushing titlebar caption controls off-screen.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST style `TabViewItem` headers with a pill (capsule) shape having uniform rounded corners (`CornerRadius="16"` or proportional capsule radius matching tab height).
- **FR-002**: System MUST apply balanced margins (`Margin="4,4,4,4"` or equivalent horizontal/vertical spacing) around each `TabViewItem`, ensuring that adjacent tabs render as distinct, floating capsules.
- **FR-003**: System MUST completely remove the bottom border and dividing stroke underneath the `TabView` header strip (`BorderThickness="0"`, `TabViewBorderThickness="0"`, `TabViewBorderBrush="Transparent"`).
- **FR-004**: System MUST ensure that `TabViewItem` visual states (Normal, PointerOver, Selected, Pressed) display rounded capsule backgrounds that harmoniously blend with Mica, Acrylic, and Solid window backdrops.
- **FR-005**: System MUST maintain the tab close button (`x:Bind IsClosable`), tab title (`x:Bind Title`), and tab icon glyph (`x:Bind IconGlyph`) within the pill container with proper vertical alignment and padding.
- **FR-006**: System MUST preserve all TabView behaviors: tab selection (`SelectionChanged`), reordering (`CanReorderTabs="True"`), tab drag-and-drop, and titlebar custom drag regions.
- **FR-007**: System MUST use WinUI 3 ThemeResource references for all pill tab brushes, ensuring zero hardcoded color codes and immediate Dark/Light theme synchronization.
- **FR-008**: System MUST comply with Principle VII (zero hardcoded user-facing strings) and Principle V (100% technical English documentation).

### Key Entities *(include if feature involves data)*

- **`TabItemModel`**: Existing observable domain model representing an open tab (Title, IconGlyph, IsClosable, Content).
- **`PillTabViewItemStyle`**: XAML Style targeting `TabViewItem` applying capsule geometry, rounded corner radii, and state brushes.
- **`ShellTabView`**: The top-level `TabView` control in `ShellWindow.xaml`, hosting the pill tab strip and titlebar drag regions.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of open tabs display with pill/capsule rounded corners (`CornerRadius >= 14px`) and isolated margins visible on real desktop rendering.
- **SC-002**: Pixel inspection confirms 0px border thickness (zero divider stroke) between the TabView header strip and the content viewport.
- **SC-003**: Tab switching and reordering interactions maintain fluid 60 FPS responsiveness (<16ms per frame).
- **SC-004**: Switching between Light and Dark themes immediately updates pill background brushes and text foregrounds without artifacts or visual clipping.
- **SC-005**: All modified XAML markup and C# code compile cleanly with 0 warnings and 0 errors.

## Assumptions

- Target environment is Windows App SDK (WinUI 3) on .NET 10 desktop.
- `TabView` remains decoupled from the content viewport row in accordance with Principle VII XAML layout mandate.
- Pill capsule style can be defined in `ShellWindow.xaml.Resources` or application-wide `App.xaml` resources.
