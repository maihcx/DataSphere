# Quickstart Validation Guide: Anchored Connection Tab & In-Page Tab Reordering

**Feature**: `014-database-tabstrip-header`
**Spec**: [spec.md](./spec.md)
**Plan**: [plan.md](./plan.md)

---

## 1. Prerequisites & Compilation

Ensure the codebase builds with 0 errors and 0 warnings:

```powershell
dotnet build DataSphere\DataSphere.csproj -c Debug
```

---

## 2. Interactive Validation Scenarios

### Scenario 1: Verify Anchored Connection Tab with Connect Glyph (`\uE703`)
1. Launch DataSphere on desktop (`WinSta0\default`).
2. On `HomePage`, click the **Databases** card to navigate to `DatabasePage`.
3. **Verify**:
   - The Connection tab ("Kết nối" / "Connections") is stationed at the leftmost position inside `InnerTabView.TabStripHeader`.
   - The icon glyph is `\uE703` (Segoe Fluent Icon for Connect), replacing `\uE774`.
   - The Connection tab has NO close button ('X').
   - The main viewport renders the connection catalog explorer (`ConnectViewControl`).

### Scenario 2: Open Dynamic Database Tabs & In-Page Reordering
1. On the connection explorer, double-click or open two connections (e.g., Connection A and Connection B).
2. **Verify**:
   - Both connections open as dynamic tabs to the right of the anchored Connection tab in `InnerTabView`.
   - Connection A and B display database cylinder icon `\uE8B7` and have close buttons ('X').
   - The Connection tab in `TabStripHeader` is visually unselected.
3. Click and drag Connection B horizontally to the left of Connection A.
4. **Verify**:
   - Tabs reorder smoothly: Connection B is now at index 0 of dynamic tabs, Connection A is at index 1.
   - The Connection tab in `TabStripHeader` remains permanently anchored on the left and is not displaced.
5. Attempt to drag Connection A outside `InnerTabView` onto the desktop.
6. **Verify**:
   - Tab is NOT torn off; 0 new OS windows are spawned.

### Scenario 3: Mutual Exclusion & Fallback to Connection Tab
1. Click the anchored Connection tab in `TabStripHeader`.
2. **Verify**:
   - The viewport immediately switches to `ConnectViewControl`.
   - The Connection tab is visually selected; dynamic tabs are unselected.
3. Click Connection B in `InnerTabView`.
4. **Verify**:
   - Viewport switches to Connection B's `DatabaseViewControl`.
   - Connection B is selected; Connection tab is unselected.
5. Close Connection B by clicking its 'X' button.
6. **Verify**:
   - Connection A becomes active; viewport displays Connection A.
7. Close Connection A by clicking its 'X' button.
8. **Verify**:
   - No dynamic tabs remain (`InnerTabs.Count == 0`).
   - The viewport automatically falls back to `ConnectViewControl`.
   - The Connection tab in `TabStripHeader` is visually selected.
   - No blank frames, crash, or visual artifacts occur.

### Scenario 4: Live Internationalization Toggle
1. Navigate to Settings page.
2. Toggle language between English and Vietnamese.
3. Return to `DatabasePage`.
4. **Verify**:
   - The Connection tab title updates immediately between "Connections" and "Kết nối" without restarting the application.
