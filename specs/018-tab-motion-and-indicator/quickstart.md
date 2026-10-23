# Quickstart Validation Guide: Fluent Tab Selection Pill, Sliding Background & Directional Page Motion

**Feature Branch**: `018-tab-motion-and-indicator`  
**Date**: 2026-10-23  
**Status**: Ready for Execution  

---

## 1. Prerequisites & Build Verification

Ensure the application compiles cleanly without warnings or errors:

```powershell
dotnet build DataSphere\DataSphere.csproj -c Debug
```
*(Required result: 0 Errors, 0 Warnings)*

---

## 2. Test Scenarios & Visual Verification Blueprint

All UI validation must be performed against the interactive Windows desktop (`WinSta0\default`) using the standardized automated script blueprint (`scripts/test-real-desktop.ps1`).

### Scenario 1: Windows 11 Accent Color & Compact Pill Geometry
1. Launch `DataSphere.exe` on `WinSta0\default`.
2. Inspect the active tab indicator visual under the first tab (e.g., Home or Connection tab).
3. **Verify**:
   - The indicator width is compact (20px) rather than spanning the full tab width.
   - The indicator corners are fully rounded (1.5px corner radius).
   - The indicator color matches the active Windows 11 system accent color.

### Scenario 2: Sliding Background Capsule & Moving Pill
1. Open a second tab (e.g. double-click a connection like `localhost`).
2. Click between Tab 1 and Tab 2.
3. **Verify**:
   - The rounded background capsule smoothly translates from Tab 1 to Tab 2.
   - The accent pill smoothly glides across the horizontal axis in tandem with the background.
   - Tab background does not snap or flash abruptly.

### Scenario 3: Direction-Aware Horizontal Page Sliding (300ms)
1. Switch from Tab 1 to Tab 2 (navigating right).
   - **Verify**: Tab 2 content enters with a smooth 300ms slide from right to left (`+32px -> 0px`).
2. Switch from Tab 2 to Tab 1 (navigating left).
   - **Verify**: Tab 1 content enters with a smooth 300ms slide from left to right (`-32px -> 0px`).
3. Frame rate remains at 60 FPS without stutter or visual tearing.

### Scenario 4: Accessibility Motion Suppression (Reduced Motion)
1. Simulate or set `AnimationsEnabled = false` in Windows settings.
2. Click between tabs.
3. **Verify**: Both tab header indicator/background and viewport page content switch instantaneously (<1ms) with zero transition animation.

---

## 3. Evidence Collection

DirectComposition screenshots captured via Win32 `PrintWindow` with `PW_RENDERFULLCONTENT` (`flag = 2`) must be saved to the session artifact directory:
- `tab_pill_accent_verified.png`
- `tab_sliding_background_verified.png`
- `page_horizontal_slide_verified.png`
