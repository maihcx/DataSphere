# Architecture Research & Technical Decisions: Anchored Connection Tab in TabStripHeader & In-Page Tab Reordering

**Branch**: `014-database-tabstrip-header`
**Date**: 2026-10-22
**Spec**: [spec.md](./spec.md)

---

## 1. Research Questions & Design Choices

### Decision 1: Connection Tab Anchoring in `InnerTabView.TabStripHeader`
- **Context**: In `DatabasePage`, `InnerTabView` previously held the Connection explorer ("Kết nối") as index 0 of `InnerTabs`. To anchor it permanently on the left and make it immune to tab reordering, we need to relocate it to `InnerTabView.TabStripHeader`.
- **Evaluation**:
  1. *Approach A: Standalone `TabViewItem` inside `TabStripHeader`*: Placing a `TabViewItem` styled with `PillTabViewItemStyle` directly inside `<TabView.TabStripHeader>`. Because items in `TabStripHeader` are outside `TabItemsSource`, WinUI 3 does not include them in the reorderable tab strip.
  2. *Approach B: Dedicated Custom Button / ToggleButton*: Creating a custom button with capsule geometry matching `PillTabViewItemStyle`.
- **Decision**: **Approach A (Standalone `TabViewItem` with `PillTabViewItemStyle`)**.
- **Rationale**:
  - Reuses the battle-tested design established in Feature 013 (`ShellWindow` Home tab).
  - Provides 100% visual parity, identical font size, icon alignment, hover/pressed state brushes, and rounded pill geometry.
  - Completely isolates the Connection tab from `InnerTabs`, making it impossible to drag, displacement-reorder, or close.

---

### Decision 2: In-Page Tab Reordering without OS Window Tear-Off
- **Context**: The user explicitly requested: "hỗ trợ khả năng kéo tab để sắp xếp (không mở cửa sổ mới)" (support dragging tabs to reorder, without opening new windows).
- **Evaluation**:
  1. *WinUI 3 Built-in Tab Reorder*: WinUI 3 `TabView` provides two distinct properties:
     - `CanReorderTabs="True"`: Enables internal horizontal drag-and-drop reordering within the `TabListView`.
     - `CanDragTabs`: Enables OLE drag-and-drop payload generation for dragging tabs outside the control.
  2. *Approach*: Setting `CanReorderTabs="True"` and `CanDragTabs="False"` on `InnerTabView`.
- **Decision**: Enable `CanReorderTabs="True"` and keep `CanDragTabs="False"` on `InnerTabView`. Do not wire `TabDroppedOutside` or `TabDragStarting`.
- **Rationale**:
  - Satisfies the exact requirement: users can drag database tabs past each other to reorder them within the inner workspace.
  - Because `CanDragTabs="False"` and no external drag handlers exist, dragging a tab outside the inner tab strip never initiates an OLE tear-off, and 0 new OS windows are spawned.

---

### Decision 3: ViewModel State Coordination & Mutual Exclusion Viewport
- **Context**: `DatabasePage` has a main viewport (`ContentControl` in Row 1) that needs to display either the connection explorer (`ConnectViewControl`) when the Connection tab is active, or the active database session view (`DatabaseViewControl`) when a dynamic tab is active.
- **Evaluation**:
  1. *Single combined `InnerTabs` collection with index 0 tricks*: Fragile, requires offsetting indices, breaks when reordering occurs, and risks dragging the connection tab.
  2. *Decoupled State Machine (Matching `ShellViewModel`)*:
     - `ConnectionTab` (`InnerTabItemModel`): Dedicated model for the Connection tab (`IsClosable = false`, `IconGlyph = "\uE703"`).
     - `InnerTabs` (`ObservableCollection<InnerTabItemModel>`): Strictly contains dynamic database session tabs.
     - `IsConnectionSelected` (bool): `true` when the Connection tab is selected; `false` when a dynamic tab is active.
     - `SelectedInnerTab` (`InnerTabItemModel?`): The active dynamic tab, or `null` if the Connection tab is selected.
     - `ActiveInnerContent` (object?): Resolves to `ConnectionTab.Content` if `IsConnectionSelected` is `true`, otherwise `SelectedInnerTab.Content`.
- **Decision**: **Approach 2 (Decoupled State Machine)**.
- **Rationale**:
  - Follows Clean MVVM and the exact proven architecture of Feature 013 (`ShellViewModel.IsHomeSelected` + `ShellViewModel.SelectedTab`).
  - Guarantees mutual exclusion: selecting Connection tab deselects dynamic tabs, and selecting a dynamic tab deselects Connection tab.
  - When the last dynamic tab is closed, `IsConnectionSelected` is automatically set to `true`, instantly returning to `ConnectViewControl` without an empty viewport.

---

### Decision 4: Semantic Icon Glyph Selection for Connection Tab
- **Context**: The user requested: "đổi icon khác cho tab kết nối để phù hợp hơn" (change to a different icon for the connection tab to make it more suitable). Currently, the Connection tab uses `\uE774` (Globe), which is also used for databases.
- **Evaluation**:
  1. `\uE774` (Globe): Generic web/globe icon; lacks database connectivity semantics.
  2. `\uE703` (Connect): Official Microsoft Segoe Fluent Icon glyph for "Connect" (two connecting directional nodes).
  3. `\uE839` (Plug): Hardware plug icon.
  4. `\uE8B7` (Database): Cylinder disk; ideal for active database sessions, but "Connections" is the catalog of server connections.
- **Decision**: Use **`\uE703` (Connect)** for the Connection tab in `TabStripHeader`, and **`\uE8B7` (Database)** for dynamic database session tabs.
- **Rationale**:
  - `\uE703` is universally recognized in Fluent Design as the standard "Connect" action/entity glyph.
  - Creates immediate, intuitive visual differentiation between the connection catalog (`\uE703`) and open database sessions (`\uE8B7`).

---

## 2. Technical Dependencies & Constraints Summary

| Item | Choice | Justification |
|---|---|---|
| **Framework** | Windows App SDK (WinUI 3) + .NET 10 | Target platform (`net10.0-windows10.0.26100.0`). |
| **MVVM Library** | `CommunityToolkit.Mvvm` v8.4 | Source generators (`[ObservableProperty]`, `[RelayCommand]`). |
| **Tab Reordering** | `CanReorderTabs="True"`, `CanDragTabs="False"` | Fluent in-page horizontal tab reordering without OS window tear-off. |
| **Connection Icon** | `\uE703` (Connect) | Official Segoe Fluent Icon for "Connect". |
| **Database Session Icon** | `\uE8B7` (Database / Server) | Clear distinction from connection catalog. |
| **Styling** | `Themes/TabStyles.xaml` (`PillTabViewItemStyle`) | Consistent Fluent Design 2 pill capsule styling. |
| **Localization** | `TranslationSource` (`tab_connections_header`) | Zero hardcoded strings per Principle VII. |
| **UI Verification** | `WinSta0\default` + DirectComposition `PW_RENDERFULLCONTENT` | Live desktop testing per Principle VIII. |
