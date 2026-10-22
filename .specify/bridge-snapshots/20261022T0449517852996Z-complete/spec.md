# Feature Specification: Surface & Tab Selected Theme Brush Contrast Enhancement

**Feature Branch**: `015-surface-brush-contrast`

**Created**: 2026-10-22

**Status**: Draft

**Input**: User description: "LayerFillColorDefaultBrush quá nhạt khi ở nền tối, có màu nào tốt như CardBackgroundFillColorDefaultBrush không?"

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Elevated Contrast for Selected Tab Pills (Priority: P1) 🎯 MVP

As a database administrator working in dark mode, I want selected tab pills to have a well-defined, elevated card background so that I can instantly identify which tab or database session is currently active without visual strain.

**Why this priority**: The active tab indicator is a primary visual landmark in the interface. When `LayerFillColorDefaultBrush` is used in dark mode, the 5% alpha wash makes selected tabs blend into the window backdrop, causing disorientation.

**Independent Test**: Run the application in Dark mode, open a tab in `ShellWindow` or `DatabasePage`, and verify that the selected tab pill displays a solid, elevated card surface with crisp border stroke, visibly popping out against unselected tabs and the dark Mica backdrop.

**Acceptance Scenarios**:

1. **Given** the application is running in Dark theme, **When** a user views or selects a tab (Home, Database, or database session), **Then** the selected tab pill renders with `CardBackgroundFillColorDefaultBrush`, providing high contrast and visual elevation.
2. **Given** a selected tab in Dark or Light theme, **When** the user hovers or presses the tab (`PointerOverSelected`, `PressedSelected`), **Then** the background maintains elevated card contrast without flickering or fading out.

---

### User Story 2 - Elevated Contrast for Workspace & Data Grid Surfaces (Priority: P2)

As a user exploring schemas and tables in dark mode, I want the workspace containers (`DatabasePage`, `ConnectViewControl`, `DatabaseViewControl`, and `VirtualTable`) to have a rich, elevated card surface rather than a faint, transparent wash so that data grids and tree views are framed with clear depth.

**Why this priority**: Content areas must have consistent visual presence. Replacing the washed-out layer fill with the standard card fill provides unified visual harmony with the cards on `HomePage`.

**Independent Test**: Navigate to `DatabasePage` in dark theme, observe `ConnectViewControl` and `DatabaseViewControl`, and verify that the workspace surface matches the card background quality of `HomePage` header cards.

**Acceptance Scenarios**:

1. **Given** the user is on `DatabasePage` in Dark theme, **When** viewing the connection explorer or an open database view, **Then** the surface background renders with `CardBackgroundFillColorDefaultBrush`.
2. **Given** `VirtualTable` displaying tabular data, **When** rendered within `DatabaseViewControl`, **Then** its canvas background cleanly unifies with the surrounding workspace card fill.

---

### User Story 3 - Instant Theme Switching & High Contrast Parity (Priority: P3)

As a user toggling between Light and Dark themes in Settings, I want all updated surfaces to transition instantly and retain ideal contrast in both modes without needing an application restart.

**Why this priority**: Theme switching is a core Fluent Design capability and must never produce visual regression or mismatched color palettes.

**Independent Test**: Toggle between Light and Dark themes in Settings, navigate across all workspaces, and verify consistent, beautiful contrast across both themes.

**Acceptance Scenarios**:

1. **Given** the application is running in Light theme, **When** the user switches to Dark theme, **Then** tab pills and workspace backgrounds immediately adopt the elevated dark card fill.
2. **Given** the application is in Dark theme, **When** the user switches to Light theme, **Then** all surfaces immediately transition to clean, crisp Fluent white card fills.

---

### Edge Cases

- **Mica / Acrylic Backdrop Variation**: When system backdrop changes between Mica, Mica Alt, and Acrylic in Settings, `CardBackgroundFillColorDefaultBrush` must retain its opacity and contrast without becoming overly transparent.
- **Nested Controls in Workspace**: Buttons, ComboBoxes, and TextBoxes placed inside `ConnectViewControl` and `DatabaseViewControl` must maintain clear foreground contrast against `CardBackgroundFillColorDefaultBrush`.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST use `{ThemeResource CardBackgroundFillColorDefaultBrush}` for `PillBorder.Background` in `Selected`, `PointerOverSelected`, and `PressedSelected` visual states in `DataSphere/Themes/TabStyles.xaml`.
- **FR-002**: System MUST update the inner workspace background in `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml` from `LayerFillColorDefaultBrush` to `{ThemeResource CardBackgroundFillColorDefaultBrush}`.
- **FR-003**: System MUST update `ConnectViewControl.xaml` and `DatabaseViewControl.xaml` root grid backgrounds to `{ThemeResource CardBackgroundFillColorDefaultBrush}`.
- **FR-004**: System MUST update `VirtualTable.xaml` background to `{ThemeResource CardBackgroundFillColorDefaultBrush}` to prevent color seam mismatches.
- **FR-005**: All updated brush references MUST strictly utilize `{ThemeResource}` markup extensions, preserving dynamic runtime theme switching without application restarts.
- **FR-006**: Text and icon foreground bindings MUST maintain WCAG AA readability (> 4.5:1 contrast ratio) against the card background across all theme modes.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Selected tab pills achieve immediate visual distinction from unselected tabs in Dark mode, eliminating the faint 5% alpha wash effect.
- **SC-002**: Workspace backgrounds across `DatabasePage`, `ConnectViewControl`, and `DatabaseViewControl` have 100% visual consistency with `HomePage` card surfaces.
- **SC-003**: Theme changes between Light and Dark modes reflect in under 100 milliseconds without visual glitches, seams, or application restart.
- **SC-004**: 0 visual regressions on text legibility, icon contrast, or data grid borders across all tested views.

---

## Assumptions

- `CardBackgroundFillColorDefaultBrush` is a native, standard Fluent Design 2 theme brush provided by the Windows App SDK theme resource dictionary.
- Using `CardBackgroundFillColorDefaultBrush` adheres 100% to Principle II (Modern Fluent UI/UX Standards) and Principle VIII of the Project Constitution.
- No code-behind or ViewModel modifications are required; all updates are declarative XAML ThemeResource references.
