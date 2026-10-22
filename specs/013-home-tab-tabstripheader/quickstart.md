# Quickstart Validation Guide: Home Tab in TabStripHeader and Unified Tab Styling

**Branch**: `013-home-tab-tabstripheader`
**Date**: 2026-10-22
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

---

## 1. Prerequisites & Build Verification

Ensure all code compiles cleanly with 0 errors and 0 warnings:

```powershell
dotnet build DataSphere\DataSphere.csproj -c Debug
```

Expected Output: `Build succeeded. 0 Warning(s), 0 Error(s)`.

---

## 2. Validation Scenarios

### Scenario 1: Initial Launch (Home Alone in TabStripHeader)
1. **Action**: Launch `DataSphere.exe` via UI automation on real desktop (`WinSta0\default`).
2. **Observations**:
   - The Home tab is rendered inside the `TabStripHeader` region at the far left.
   - The Home tab displays with pill-shaped rounded capsule geometry, icon `\uE80F`, and title "Home".
   - The close button ('X') on the Home tab is **VISIBLE** (`IsClosable = true`) because no dynamic tabs are open.
   - The central viewport displays the Home page.
3. **Evidence**: Capture screenshot via DirectComposition (`PrintWindow` with `PW_RENDERFULLCONTENT`).

---

### Scenario 2: Dynamic Tab Creation & Close Button Concealment
1. **Action**: Click a connection card on the Home page to open a `DatabasePage` tab (e.g. `127.0.0.1:3306`).
2. **Observations**:
   - Dynamic tab appears in the scrollable tab list to the right of `TabStripHeader`.
   - The dynamic tab becomes active/selected, and the viewport switches to `DatabasePage`.
   - The Home tab in `TabStripHeader` transitions to the **unselected** visual state.
   - The close button ('X') on the Home tab **IMMEDIATELY DISAPPEARS** (hidden/collapsed, `IsClosable = false`).
3. **Expected State**: Total tabs = 2 (1 Home + 1 Dynamic). Home cannot be closed.

---

### Scenario 3: Immovability Invariant
1. **Action**: Using UI automation or physical mouse drag, attempt to click and drag the Home tab in `TabStripHeader` to the right or outside the window.
2. **Observations**:
   - The Home tab does not move.
   - No drag operation is initiated.
   - No tab tear-off occurs.
   - The dynamic tab can still be dragged and reordered freely.

---

### Scenario 4: Switching Between Home & Dynamic Tabs
1. **Action**: Click the Home tab in `TabStripHeader`.
2. **Observations**:
   - The Home tab becomes selected.
   - The dynamic tab in `ShellTabView` is unselected.
   - The central viewport displays `HomePage`.
   - The close button on Home remains hidden because the dynamic tab is still open.
3. **Action**: Click the dynamic tab in `ShellTabView`.
   - The dynamic tab becomes selected.
   - The Home tab transitions back to unselected.
   - The central viewport displays `DatabasePage`.

---

### Scenario 5: Closing Dynamic Tabs and Fallback to Home
1. **Action**: Click the close button ('X') on the dynamic tab.
2. **Observations**:
   - The dynamic tab closes and is removed.
   - Active selection automatically returns to the Home tab in `TabStripHeader`.
   - The viewport displays `HomePage`.
   - The close button ('X') on the Home tab **REAPPEARS** (`IsClosable = true`) because dynamic tab count is now 0.

---

### Scenario 6: Clean Application Termination from Home
1. **Action**: With only Home open (close button visible), click the 'X' button on the Home tab.
2. **Observations**:
   - `RequestCloseWindow` event fires.
   - The shell window closes cleanly.
   - The application process terminates with code 0.

---

### Scenario 7: DatabasePage Inner Tab Styling & Uniform Background
1. **Action**: Navigate to `DatabasePage` and open a table tab (e.g. `users`).
2. **Observations**:
   - The inner tab in `InnerTabView` renders with `PillTabViewItemStyle` (capsule rounded corners, padding, fluent brushes).
   - The background from `InnerTabView` down through the table content area displays a unified background (`LayerFillColorDefaultBrush`), distinct from the transparent titlebar backdrop of `ShellWindow`.
   - The visual seam between the tab bar and table content is fluid and borderless.
