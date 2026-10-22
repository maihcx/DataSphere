# Tasks: Anchored Connection Tab in TabStripHeader & In-Page Tab Reordering for DatabasePage

**Input**: Design documents from `/specs/014-database-tabstrip-header/`
**Prerequisites**: [plan.md](./plan.md) (required), [spec.md](./spec.md) (required for user stories), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/database-tabstrip-contract.md](./contracts/database-tabstrip-contract.md), [quickstart.md](./quickstart.md)

## Organization: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `- [ ] [TaskID] [P?] [Story?] Description with file path`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., [US1], [US2], [US3], [US4])
- Strict checklist format with exact file paths in descriptions

---

## Phase 1: Setup & Foundational

**Purpose**: Core model enhancements required across all user stories

- [x] T001 Update default icon glyph to `\uE703` ("Connect") in `DataSphere/Models/InnerTabItemModel.cs`

---

## Phase 2: User Story 1 - Anchored Connection Tab in TabStripHeader (Priority: P1) 🎯 MVP

**Goal**: Anchor the permanent Connection catalog tab inside `InnerTabView.TabStripHeader` at the leftmost position with dedicated Connect glyph (`\uE703`), non-closable, and immune to tab displacement.

**Independent Test**: Navigate to `DatabasePage` and verify that the Connection tab is rendered inside `TabStripHeader` at index 0, displays icon `\uE703`, and has no close button ('X').

### Implementation for User Story 1

- [x] T002 [US1] Implement dedicated `ConnectionTab` model with `IconGlyph = "\uE703"` and `IsClosable = false` in `DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseViewModel.cs`
- [x] T003 [US1] Add `<TabView.TabStripHeader>` with `ConnectionTabItem` using `PillTabViewItemStyle` in `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml`
- [x] T004 [US1] Wire `OnConnectionTabTapped` handler and selection synchronization in `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml.cs`

**Checkpoint**: Connection tab is permanently anchored in `TabStripHeader` at the leftmost position and cannot be dragged or closed.

---

## Phase 3: User Story 2 - In-Page Dynamic Tab Reordering (Priority: P2)

**Goal**: Enable horizontal tab reordering for open database sessions within `DatabasePage` while strictly bounding drag interactions inside the page (0 external windows spawned).

**Independent Test**: Open two database connection tabs in `DatabasePage`, drag tab 2 to the left of tab 1, and verify tabs reorder smoothly without tearing off into new OS windows.

### Implementation for User Story 2

- [x] T005 [US2] Enable `CanReorderTabs="True"` and set `CanDragTabs="False"` on `InnerTabView` in `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml`
- [x] T006 [US2] Assign database cylinder icon `\uE8B7` to dynamic database session tabs in `OpenConnectionTab` in `DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseViewModel.cs`

**Checkpoint**: Dynamic database tabs can be freely dragged and reordered horizontally; the Connection tab remains fixed at index 0; dragging outside never creates new OS windows.

---

## Phase 4: User Story 3 - Unified Viewport & Mutual Exclusion Selection (Priority: P3)

**Goal**: Manage selection state with mutual exclusion between the anchored Connection tab and dynamic database tabs, ensuring seamless viewport switching and automatic fallback to Connection when all dynamic tabs are closed.

**Independent Test**: Open a database connection, switch between Connection and the database tab, close the database tab, and verify viewport automatically switches back to `ConnectViewControl`.

### Implementation for User Story 3

- [x] T007 [US3] Implement `IsConnectionSelected`, `SelectedInnerTab`, `ActiveInnerContent`, `SelectConnectionCommand`, and mutual exclusion in `DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseViewModel.cs`
- [x] T008 [US3] Bind viewport `ContentControl` to `ViewModel.ActiveInnerContent` in `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml`
- [x] T009 [US3] Update `CloseTab` in `DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseViewModel.cs` to trigger `SelectConnection()` when the last dynamic tab is closed

**Checkpoint**: Mutual exclusion selection is active; closing the last dynamic tab cleanly falls back to the Connection catalog.

---

## Phase 5: User Story 4 - Visual Consistency & Dynamic Localization (Priority: P4)

**Goal**: Ensure pixel-perfect pill styling parity with `ShellWindow` and instant runtime language updates on the Connection tab header.

**Independent Test**: Toggle between English and Vietnamese in Settings, navigate to `DatabasePage`, and verify the Connection tab header updates dynamically without restarting.

### Implementation for User Story 4

- [x] T010 [US4] Bind `ConnectionTab.Header` dynamically to `TranslationSource` (`tab_connections_header`) in `DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseViewModel.cs`
- [x] T011 [US4] Configure layout margins and alignment for `ConnectionTabItem` inside `InnerTabView.TabStripHeader` in `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml`

**Checkpoint**: Visual styling and dynamic localization are 100% verified.

---

## Phase 6: Polish & Verification

**Purpose**: Build validation, live desktop UI automation, and constitutional compliance verification

- [x] T012 Verify zero-error compilation with `dotnet build DataSphere/DataSphere.csproj -c Debug`
- [x] T013 Create and run live UI automation script `scripts/verify-database-tabstrip.ps1` on `WinSta0\default` to verify tab reordering, connection tab immobility, and capture DirectComposition screenshots into artifacts directory
- [x] T014 Execute quickstart validation scenarios defined in `specs/014-database-tabstrip-header/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup & Foundational (Phase 1)**: Can start immediately.
- **User Story 1 (Phase 2 - P1 MVP)**: Depends on Phase 1 completion. Anchors Connection tab.
- **User Story 2 (Phase 3 - P2)**: Depends on Phase 2 completion. Enables in-page reorder.
- **User Story 3 (Phase 4 - P3)**: Depends on Phase 2 and Phase 3. Coordinates selection mutual exclusion.
- **User Story 4 (Phase 5 - P4)**: Depends on Phase 2, 3, and 4. Finalizes localization and pill margins.
- **Polish & Verification (Phase 6)**: Depends on all user story phases being complete.

### Parallel Opportunities

- Within Phase 2: `T002` (ViewModel) and `T003` (XAML) can be developed in tandem once models are defined.
- Within Phase 4: `T007` (ViewModel state machine) and `T008` (XAML viewport binding) map cleanly to respective layers.
- `T013` (Automation test runner) can be authored while implementation tasks are underway.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: `T001` (Model glyph default).
2. Complete Phase 2: `T002`, `T003`, `T004` (Connection tab anchored in `TabStripHeader`).
3. **STOP and VALIDATE**: Confirm Connection tab is rendered at leftmost position and is non-closable.

### Incremental Delivery

1. Phase 1 + 2: Anchored Connection tab ready (MVP).
2. Phase 3: Add `CanReorderTabs="True"` and database session glyph `\uE8B7`.
3. Phase 4: Add mutual exclusion and fallback viewport switching.
4. Phase 5: Finalize localization and styling tokens.
5. Phase 6: Full verification and DirectComposition artifact captures.
