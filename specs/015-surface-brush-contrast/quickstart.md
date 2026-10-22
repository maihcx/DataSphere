# Quickstart Validation Guide: Surface & Tab Selected Theme Brush Contrast Enhancement

**Feature**: `015-surface-brush-contrast`
**Spec**: [spec.md](./spec.md)
**Plan**: [plan.md](./plan.md)

---

## 1. Prerequisites & Compilation

Ensure the solution builds with 0 errors and 0 warnings:

```powershell
dotnet build DataSphere\DataSphere.csproj -c Debug
```

---

## 2. Interactive Validation Scenarios

### Scenario 1: Verify Selected Tab Pill Contrast in Dark Mode
1. Ensure the application is operating in Dark Theme (set in Settings if necessary).
2. Launch DataSphere.
3. Observe the Home tab in `ShellWindow`.
4. **Verify**:
   - The selected tab pill background is solid elevated dark card (`CardBackgroundFillColorDefaultBrush`), noticeably brighter and sharper than the dark Mica window frame.
   - The border is outlined with `CardStrokeColorDefaultBrush`.
   - The tab title and icon are crisp white (`TextFillColorPrimaryBrush`).

### Scenario 2: Verify Database Workspace & Inner Tab Pill Contrast
1. Click the **Databases** card on `HomePage`.
2. On `DatabasePage`, observe the anchored Connection tab in `TabStripHeader` and the `ConnectViewControl` surface.
3. **Verify**:
   - The anchored Connection tab pill has the solid elevated card fill (`CardBackgroundFillColorDefaultBrush`).
   - The entire workspace canvas (`ConnectViewControl`) is rendered with the elevated card surface matching the cards on `HomePage`.
   - Double-click or open a database connection (e.g. `localhost`).
   - The newly opened database tab pill is highlighted with `CardBackgroundFillColorDefaultBrush`.
   - The schema tree and `DatabaseViewControl` / `VirtualTable` background render smoothly with consistent card fill.

### Scenario 3: Verify Dynamic Theme Toggle without Restart
1. Navigate to the Settings page.
2. Toggle theme from Dark to Light.
3. Return to `DatabasePage`.
4. **Verify**:
   - All surfaces and selected tab pills immediately switch to clean, crisp white card fills without restarting.
   - Text and icons remain completely legible.
   - Toggle back to Dark theme and verify instant restoration of elevated dark card contrast.
