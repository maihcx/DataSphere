# Tasks: Pill-Shaped TabViewItem Styling and Borderless TabStrip

**Input**: Design documents from `specs/012-pill-tabview-styling/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/tabview-styling-contract.md`, `quickstart.md`

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (XAML Resources Preparation)

**Purpose**: Resource preparation for shell window tab strip styling

- [x] T001 Review and prepare `ShellWindow.xaml` resources section for custom `TabViewItem` styles and borderless overrides in `DataSphere/Views/Windows/ShellWindow.xaml`

---

## Phase 2: Foundational (Style Definition & Resource Overrides)

**Purpose**: Core XAML style and resource tokens that all user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T002 [P] Define `PillTabViewItemStyle` targeting `TabViewItem` in `DataSphere/Views/Windows/ShellWindow.xaml` with `CornerRadius="16"`, `Margin="3,4,3,4"`, `MinHeight="34"`, and `Padding="12,4,8,4"`
- [x] T003 [P] Declare borderless `TabView` resource token overrides (`TabViewBorderThickness="0"`, `TabViewBorderBrush="Transparent"`, `TabViewTabStripBorderThickness="0"`, `TabViewItemStroke="Transparent"`, `TabViewItemSeparator="Transparent"`) in `ShellTabView.Resources` in `DataSphere/Views/Windows/ShellWindow.xaml`

**Checkpoint**: Core pill style and borderless resources ready — user story implementation can begin

---

## Phase 3: User Story 1 - Pill-Shaped TabViewItem Visual Styling (Priority: P1) 🎯 MVP

**Goal**: Deliver floating pill-shaped (capsule) tab headers with fully rounded corners and distinct visual states for selected, unselected, and hover.

**Independent Test**: Open DataSphere with multiple tabs, verify each tab displays as an isolated capsule with rounded corners (`CornerRadius="16"`), balanced margins, and correct theme foreground/background.

### Implementation for User Story 1

- [x] T004 [US1] Apply `Style="{StaticResource PillTabViewItemStyle}"` to `<TabViewItem>` inside `<TabView.TabItemTemplate>` in `DataSphere/Views/Windows/ShellWindow.xaml`
- [x] T005 [US1] Configure visual state background and border brushes on pill tabs for Unselected, PointerOver, and Selected states using theme resources in `DataSphere/Views/Windows/ShellWindow.xaml`

**Checkpoint**: User Story 1 fully functional and testable independently as the MVP

---

## Phase 4: User Story 2 - Borderless Seamless Separation between TabView and Page Content (Priority: P2)

**Goal**: Remove the horizontal divider line beneath the `TabView` header strip, achieving a borderless transition into the page content below.

**Independent Test**: Launch DataSphere, observe the seam between the TabView header strip and the content viewport, and confirm 0px border thickness (no divider line).

### Implementation for User Story 2

- [x] T006 [US2] Set `BorderThickness="0"` and `BorderBrush="Transparent"` directly on `<TabView x:Name="ShellTabView">` in `DataSphere/Views/Windows/ShellWindow.xaml`
- [x] T007 [US2] Verify seamless alignment between the floating tab strip and the decoupled content presenter in `Grid.Row="1"` across Mica, Acrylic, and Solid backdrops in `DataSphere/Views/Windows/ShellWindow.xaml`

**Checkpoint**: User Stories 1 and 2 both work seamlessly with floating pill tabs and no bottom divider line

---

## Phase 5: User Story 3 - Full Interaction & Chrome Lifecycle Preservation (Priority: P3)

**Goal**: Preserve 100% of TabView capabilities including tab selection, closing tabs via close button, reordering tabs via drag, and window titlebar dragging.

**Independent Test**: Drag tabs to reorder them, click the close button on closable tabs, and drag the window by titlebar custom drag regions.

### Implementation for User Story 3

- [x] T008 [US3] Verify tab close button (`IsClosable`), icon glyph (`IconGlyph`), and title binding inside the pill container in `DataSphere/Views/Windows/ShellWindow.xaml`
- [x] T009 [US3] Verify tab drag-and-drop reordering (`CanReorderTabs="True"`) and window titlebar drag region integration in `DataSphere/Views/Windows/ShellWindow.xaml`

**Checkpoint**: All tab interactions and titlebar drag operations remain fully operational

---

## Phase 6: Polish & Verification Gate

**Purpose**: Quality gate verification, zero-error compilation, and live desktop UI testing

- [x] T010 Verify clean project compilation with `dotnet build DataSphere\DataSphere.csproj -c Debug` (0 warnings, 0 errors)
- [x] T011 [P] Verify 100% US English documentation and clean XAML markup without `AutomationId`
- [x] T012 Execute live UI automation verification test on `WinSta0\default` with DirectComposition capture per Principle VIII using `scripts/verify-pill-tabview.ps1`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 completion — BLOCKS all user stories.
- **User Story 1 (Phase 3)**: Depends on Phase 2 completion — MVP slice.
- **User Story 2 (Phase 4)**: Depends on Phase 2 & Phase 3 completion.
- **User Story 3 (Phase 5)**: Depends on Phase 2 & Phase 3 completion.
- **Polish & Verification (Phase 6)**: Depends on all user stories being complete.

### Parallel Opportunities

- In Phase 2: T002 and T003 can be defined in parallel.
- In Phase 6: T011 can run in parallel with compilation and testing.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational (`PillTabViewItemStyle` and borderless resource tokens).
3. Complete Phase 3: User Story 1 (Apply style to tab template).
4. **VALIDATE**: Build and test pill tabs independently.

### Incremental Delivery

1. Complete Setup + Foundational → Pill style and borderless tokens ready.
2. Deliver User Story 1 → Floating pill tabs with rounded capsule geometry (MVP).
3. Deliver User Story 2 → Borderless transition between tab strip and content.
4. Deliver User Story 3 → Interaction and titlebar drag preservation.
5. Execute Verification Gate (Build 0 errors, live UI automation, DirectComposition screenshot).
