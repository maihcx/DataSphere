# Feature Specification: Tab Sleeping & Memory Saver

**Feature Branch**: `016-tab-sleeping-memory-saver`

**Created**: 2026-10-23

**Status**: Draft

**Input**: User description: "Tab Sleeping & Memory Saver"

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Instant Responsive Tab Switching (Priority: P1)

As a database administrator working with multiple query and schema tabs,  
I want tab switching to be instantaneous and fluid without reallocating or freezing the view,  
So that I can quickly reference connection details or settings and return to my database tables with zero latency and zero visual disruption.

**Why this priority**: Core productivity depends on seamless multi-tab multitasking. Under normal rapid switching, tabs must stay alive in memory to eliminate delays, stutters, or loss of selection and scroll state.

**Independent Test**: Can be tested independently by opening a database table, switching to the Home or Settings tab, immediately returning to the database tab, and verifying that all records, selection states, and scroll positions are intact with zero reload delay (<16ms frame time).

**Acceptance Scenarios**:

1. **Given** an open database tab with 1,000+ records loaded and scrolled to a specific row,  
   **When** the user clicks the "Trang chủ" (Home) or "Cài đặt" (Settings) tab,  
   **Then** the active viewport switches immediately, and the inactive database tab remains in memory without being permanently disposed or wiped out.
2. **Given** an inactive database tab that was previously left in active memory,  
   **When** the user clicks back to the database tab within the active idle timeout window,  
   **Then** the table viewport displays immediately with no loading spinners, the existing scroll offset is preserved, and cells respond instantly to clicks.

---

### User Story 2 - User-Configurable Memory Saver Settings (Priority: P2)

As a user running DataSphere on hardware with varying memory constraints,  
I want to toggle background tab sleeping and configure the idle timeout in Settings,  
So that I can balance system memory savings against instant tab reactivation according to my machine's capabilities.

**Why this priority**: Users must have full sovereignty over performance trade-offs; users with high RAM can keep all tabs hot indefinitely, while users on limited RAM can aggressively sleep idle tabs.

**Independent Test**: Can be tested independently by navigating to the Settings page, toggling the "Tab Memory Saver" switch on/off, choosing an idle timeout (e.g. 5 minutes, 15 minutes, 30 minutes, 1 hour), restarting the application, and verifying that the user's preferences persist accurately.

**Acceptance Scenarios**:

1. **Given** the user is on the Settings page,  
   **When** the user toggles "Tiết kiệm bộ nhớ cho tab nền" (Enable Background Tab Memory Saver) to On,  
   **Then** the idle timeout dropdown becomes interactive, allowing selection between 5 minutes, 15 minutes, 30 minutes, and 1 hour.
2. **Given** the user changes the idle timeout to 30 minutes and closes the app,  
   **When** the app is reopened,  
   **Then** the Settings page reflects the saved toggle state and 30-minute selection.
3. **Given** the user toggles "Tab Memory Saver" to Off,  
   **When** background tabs remain inactive for any duration,  
   **Then** no tab is ever put to sleep regardless of elapsed time.

---

### User Story 3 - Automated Background Tab Sleeping & Wakeup (Priority: P3)

As a user who keeps multiple heavy database tabs open throughout the day,  
I want tabs that haven't been viewed for a long time to enter a low-power sleeping state,  
So that DataSphere frees up memory and CPU/GPU resources for other active system applications.

**Why this priority**: Prevents background resource accumulation and memory footprint bloat across long-running desktop sessions with many dormant tabs.

**Independent Test**: Can be tested independently by opening a database tab, configuring a short idle timeout, switching away from the tab until the timeout expires, verifying the tab enters sleeping state (visual elements trimmed and indicator displayed), and clicking the tab to verify smooth wakeup.

**Acceptance Scenarios**:

1. **Given** Tab Memory Saver is enabled with an idle timeout of N minutes,  
   **When** a background tab has not been focused or interacted with for longer than N minutes,  
   **Then** the system marks the tab as Sleeping, trims its visual allocation and cached buffers, and displays a sleeping indicator on the tab header.
2. **Given** a tab currently in Sleeping state,  
   **When** the user clicks on the sleeping tab to focus it,  
   **Then** the tab automatically wakes up, re-establishes the viewport, refreshes table records, and clears the sleeping indicator.

---

### User Story 4 - Clean Terminal Disposal on Tab Closure (Priority: P4)

As a user closing database tabs I no longer need,  
I want all underlying memory, connections, and visual resources to be thoroughly destroyed upon closing the tab,  
So that no lingering connections, event handlers, or memory leaks remain.

**Why this priority**: Enforces clean architectural hygiene and eliminates true memory leaks.

**Independent Test**: Can be tested independently by opening 5 database connection tabs, measuring baseline process memory, closing all 5 tabs via the `X` button, and verifying that working set memory decreases and connection sockets are closed.

**Acceptance Scenarios**:

1. **Given** an open database tab with active table queries and pooled controls,  
   **When** the user clicks the close (`X`) button on the tab item,  
   **Then** the tab is removed from the tab strip, and its ViewModels, visual controls, and database connections are deterministically disposed.

---

### Edge Cases

- **Active Query or Mutation During Sleep Candidate**: If a tab is currently running a long query, exporting data, or has uncommitted cell edits (`HasUnsavedChanges = true`), the system MUST NOT sleep the tab; it must remain active until the operation completes and changes are resolved.
- **Immediate Rapid Switching Across Multiple Tabs**: Rapidly cycling through tabs (e.g. keyboard shortcuts or fast clicks) must reset each tab's idle activity timer without triggering spurious sleeping or waking cycles.
- **Home Tab Exemption**: The default "Trang chủ" (Home) dashboard tab MUST NEVER be put to sleep, ensuring immediate access to the launcher.
- **System Theme or Display Setting Changes While Sleeping**: If the user toggles Dark/Light theme while a tab is asleep, the sleeping tab must wake up in the correct theme without graphical glitches.
- **Network Disconnect During Sleep**: If a database server disconnects while a sleeping tab is inactive, waking up the tab must gracefully notify the user and prompt reconnection rather than crashing.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST maintain inactive open tabs in active memory by default, ensuring instant tab switching (<16ms frame time) without recreation of visual trees or loss of scroll position.
- **FR-002**: System MUST provide a "Tab Memory Saver" (Tiết kiệm bộ nhớ cho tab) setting in the application Settings page, allowing users to enable or disable automatic sleeping of background tabs.
- **FR-003**: System MUST provide an idle timeout setting with options for 5 minutes, 15 minutes, 30 minutes, and 1 hour (defaulting to 15 minutes).
- **FR-004**: System MUST track the last active timestamp for each open tab and evaluate idle duration on a lightweight background schedule (e.g. every 60 seconds).
- **FR-005**: System MUST put inactive tabs into a "Sleeping" state when their idle duration exceeds the configured timeout and Tab Memory Saver is enabled.
- **FR-006**: When a tab enters Sleeping state, the system MUST release heavy visual element trees and large cached record sets, while retaining tab metadata, schema identity, and query context.
- **FR-007**: System MUST provide a clear visual indicator on sleeping tab headers (e.g. muted header opacity or sleep badge icon) so users can distinguish active tabs from sleeping tabs.
- **FR-008**: System MUST automatically wake up a sleeping tab when the user selects or focuses it, restoring the table viewport and data seamlessly.
- **FR-009**: System MUST exempt tabs with active queries, background data exports, or uncommitted cell modifications from being put to sleep.
- **FR-010**: System MUST persist Tab Memory Saver preferences across application restarts using the existing settings persistence infrastructure (`UserDataStoreService`).
- **FR-011**: System MUST perform full terminal disposal (`Dispose()`) of all tab resources, ViewModels, visual row pools, and database connection sessions when a tab is closed via the `X` button.
- **FR-012**: System MUST localize all user-facing strings (Settings labels, tooltips, sleep status hints) in English and Vietnamese through `TranslationSource` without hardcoded UI strings.

---

### Key Entities

- **TabItemModel**: Represents an open tab item in the shell tab strip, augmented with lifecycle state (`IsSleeping`, `LastActiveTime`, `CanSleep`).
- **TabMemorySaverPolicy**: Encapsulates the configuration settings (`IsEnabled`, `IdleTimeoutMinutes`), persistence, and idle evaluation logic.
- **TabSleepState**: Enumeration representing tab lifecycle: `Active`, `BackgroundKeepAlive`, `Sleeping`, `WakingUp`.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Rapid tab switching between active tabs takes less than 16 milliseconds (maintaining a fluid 60-144 FPS) with zero visual stutter or reload latency.
- **SC-002**: Long-running idle background tabs put to sleep reduce per-tab private working set memory by at least 60% compared to active running tabs.
- **SC-003**: Waking up a sleeping tab upon user click completes within 500 milliseconds on standard local database connections.
- **SC-004**: Closing tabs releases 100% of the associated table visual elements and connection instances with zero memory leak over 50 consecutive tab open/close cycles.
- **SC-005**: 100% of user-facing settings and notifications are dynamically localized in English and Vietnamese with zero hardcoded strings.

---

## Assumptions

- Standard desktop workloads typically open 3 to 10 simultaneous database tabs; keeping active tabs in memory during normal use incurs negligible memory overhead (<30MB total) on modern 8GB+ Windows workstations.
- An idle timeout of 15 minutes provides the optimal default balance between responsiveness and background memory preservation.
- The Home tab is lightweight and serves as the primary navigation anchor, so it is permanently excluded from tab sleeping.
