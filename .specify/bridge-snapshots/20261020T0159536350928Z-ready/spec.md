# Feature Specification: User Preferences & State Persistence (UserDataStore Integration)

**Feature Branch**: `003-user-data-store-persistence`

**Created**: 2026-10-20

**Status**: Draft

**Input**: User description: "triển khai UserDataStore cho các vùng sử dụng nó trước đây (hãy xem nhánh main để hiểu hoặc tìm trong ngữ cảnh nếu ngữ cảnh còn đầy đủ)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Application Theme & Visual Personalization Persistence (Priority: P1) 🎯 MVP

As a database administrator working in various ambient lighting conditions, I want my chosen application theme (Light, Dark, or System Default) to be remembered and automatically applied whenever I launch the application, so that I don't have to re-select my visual theme every time I open DataSphere.

**Why this priority**: Visual comfort and theme preference are immediately perceptible to the user upon every application launch. Losing theme settings on restart degrades the user experience and violates modern desktop platform expectations.

**Independent Test**: Launch DataSphere. Go to Settings, change Theme to "Dark" (or "Light"). Close the application completely. Reopen DataSphere; confirm that the window, controls, and pages immediately render with the chosen theme without any visual flashing or resetting to default.

**Acceptance Scenarios**:

1. **Given** the application is set to "Dark" theme, **When** the user closes and relaunches DataSphere, **Then** all top-level windows and page contents immediately render in Dark theme.
2. **Given** the user selects "Light" theme in Settings, **When** the selection changes, **Then** the visual theme updates immediately in real-time across all open windows and is saved for subsequent launches.
3. **Given** the user selects "Default" (System Auto) theme, **When** the Windows system theme changes (e.g. from Dark to Light), **Then** DataSphere dynamically synchronizes with the system theme.

---

### User Story 2 - Display Language Preference Persistence & Startup Restoration (Priority: P1) 🎯 MVP

As a multi-lingual user who prefers Vietnamese (or English), I want my selected language preference to be saved and automatically loaded on startup, so that all interface text, tab headers, dashboard cards, and settings appear in my preferred language immediately upon launching the app.

**Why this priority**: Internationalization (i18n) is a core constitutional principle. While runtime language switching is implemented, failing to restore the saved language on startup forces users to manually re-configure their language on every session.

**Independent Test**: Switch language to "Tiếng Việt" in Settings. Verify that all tabs and cards display in Vietnamese. Terminate the app. Launch the app again; confirm that the Home tab title, dashboard cards, and settings are rendered in Vietnamese from the very first frame.

**Acceptance Scenarios**:

1. **Given** a user configured the display language to "Tiếng Việt" in a previous session, **When** the application launches, **Then** the initial UI, tab headers, and dashboard cards render in Vietnamese without requiring manual intervention.
2. **Given** no prior language preference exists in user storage, **When** the application launches for the first time, **Then** the application defaults to the current system UI language (or English fallback) and persists this baseline.
3. **Given** a user changes language to English in Settings, **When** the user relaunches the app, **Then** the English display language remains active.

---

### User Story 3 - Window Placement, Dimensions & Maximized State Persistence (Priority: P1)

As a database professional using multi-monitor setups or custom workspace arrangements, I want the application to remember its window dimensions, screen position, and maximized state, so that when I reopen DataSphere, it returns to the exact location and size I configured.

**Why this priority**: Window positioning is standard desktop functionality. Reverting to default centered bounds on every launch forces users to repeatedly resize and reposition the window, disrupting workflow efficiency.

**Independent Test**: Resize the DataSphere window to a custom width and height (e.g., 1400x900) and drag it to a specific screen position (or maximize it). Close the window. Relaunch the application; verify that the window restores to the exact position, dimensions, and window state (normal vs maximized).

**Acceptance Scenarios**:

1. **Given** the user configured the window to custom dimensions and position, **When** the window closes and reopens, **Then** it restores its previous position and dimensions on screen.
2. **Given** the user maximized the window before closing, **When** the application launches, **Then** the window restores in the maximized state.
3. **Given** stored window coordinates fall outside the visible boundaries of all connected monitors (e.g. after disconnecting an external display), **When** the application launches, **Then** the window detects this and safely repositions itself onto the primary visible display area.

---

### User Story 4 - Robust Preferences Storage & Fault Tolerance (Priority: P2)

As an enterprise user whose local environment may encounter abrupt power loss, crashes, or file permission restrictions, I want my user settings store to handle missing, corrupt, or locked files gracefully, so that the application never crashes during startup due to settings file anomalies.

**Why this priority**: Fault tolerance prevents unhandled I/O exceptions and data corruption from blocking application startup.

**Independent Test**: Delete or corrupt the user settings file. Launch DataSphere; verify that the application recovers silently, recreates default preferences, and boots successfully with 0 crashes.

**Acceptance Scenarios**:

1. **Given** the user data store file is missing on startup, **When** the application reads a preference, **Then** it returns the default fallback value and recreates the storage directory and file automatically.
2. **Given** concurrent access or rapid preference updates (e.g., rapid slider movements or resizing), **When** settings are saved, **Then** file writes are safely synchronized to prevent file locking contention and data corruption.
3. **Given** encrypted sensitive data (such as cached passwords or tokens) stored in the user data store, **When** accessed, **Then** values are transparently encrypted before writing to disk and decrypted upon retrieval.

---

### Edge Cases

- **Corrupted Settings File**: If the stored settings file contains invalid JSON or truncated bytes, the system MUST catch the deserialization error, initialize a clean default dictionary, and proceed with startup without throwing an unhandled exception.
- **Disconnected Multi-Monitor**: If the window was previously positioned on a secondary monitor that is no longer connected, the system MUST clamp or reposition the window so that it is fully visible on the active display.
- **Minimum Window Constraints**: If saved window dimensions are smaller than the application's `MinWidth` or `MinHeight`, the restored window MUST respect the minimum boundary constraints (at least 800x500).
- **Rapid Preference Changes**: If multiple settings are adjusted in rapid succession (e.g., changing theme, language, and window size within milliseconds), storage operations MUST safely debounce or synchronize writes to eliminate file access collisions.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST persist the user's selected application theme ("Light", "Dark", "Default") in the user preferences store whenever changed in Settings.
- **FR-002**: The system MUST restore and apply the persisted theme preference during application startup before the primary window is presented.
- **FR-003**: The system MUST persist the selected UI display language code (e.g., "en", "vi") whenever the user changes language.
- **FR-004**: The system MUST read the persisted language preference during startup initialization and configure the active translation culture accordingly.
- **FR-005**: The system MUST persist normal window dimensions (Width, Height) and coordinates (Left, Top) upon window closing.
- **FR-006**: The system MUST persist the window's maximized state upon closing.
- **FR-007**: The system MUST restore saved window dimensions, position, and maximized state during window initialization on startup.
- **FR-008**: The system MUST sanitize restored window coordinates against current virtual screen boundaries, repositioning onto a visible monitor if saved coordinates are off-screen.
- **FR-009**: The user data storage system MUST automatically create the storage directory (`%LOCALAPPDATA%\DataSphere`) if it does not exist.
- **FR-010**: The user data storage system MUST transparently encrypt sensitive credential values using standard application cryptography before writing to disk.
- **FR-011**: The user data storage system MUST maintain thread-safe in-memory caching and synchronized disk writes to avoid file I/O contention.

### Key Entities

- **User Preference Record**: Represents a key-value mapping of a persisted user setting (e.g., theme type, active language code, window dimensions, maximized state).
- **Window Geometry State**: Represents the physical layout of the primary window, including horizontal position, vertical position, width, height, and window presentation state (normal vs maximized).
- **Theme Configuration**: Represents the visual theme mode (Light, Dark, or System Sync) and associated backdrop presentation parameters.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of persisted user preferences (Theme, Language, Window Position/Size, Maximized State) are successfully restored upon application relaunch.
- **SC-002**: Reading persisted preferences on startup adds less than 15 milliseconds to overall application launch time.
- **SC-003**: 0 unhandled exceptions or application crashes occur when the preferences file is missing, empty, or corrupted.
- **SC-004**: Window restoration accurately places the window at the saved coordinates within 2 pixels of its previous screen position (subject to monitor DPI scaling).
- **SC-005**: Zero plain-text sensitive credentials or passwords exist in the user preferences JSON file on disk.

## Assumptions

- User preferences are stored per-user in the standard local application data directory (`%LOCALAPPDATA%\DataSphere\userdata.json`).
- If no saved preferences exist, default values are: System Default Theme, System UI Language (falling back to English), and default centered 1280x800 window.
- In multi-window scenarios, window geometry persistence applies to the primary application window shell.
- Dynamic theme application uses modern platform theme mechanisms without requiring process restarts.
