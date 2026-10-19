# Quickstart Validation Guide: WinUI 3 Modern Tabbed Shell

**Feature**: `001-winui3-chrome-tabs` | **Date**: 2026-10-19

This guide outlines runnable end-to-end verification scenarios to validate that the WinUI 3 modern tabbed shell, browser-style Chrome tabs, and multi-window drag-and-drop tear-off meet all requirements.

---

## Prerequisites

1. Windows 10 (Build 19041+) or Windows 11.
2. .NET 10 SDK installed.
3. Windows App SDK Runtime 1.6+ installed.
4. Repository built cleanly:
   ```powershell
   dotnet build DataSphere\DataSphere.csproj -c Debug
   ```

---

## Validation Scenarios

### Scenario 1: Shell Verification (Tab Strip & Sidebar Absence)
1. **Action**: Launch DataSphere executable.
2. **Expectation**:
   - The window displays a modern Mica backdrop.
   - The top header contains a horizontal Chrome-style tab strip.
   - The vertical left navigation panel (`NavigationView`) is completely absent.
   - The first tab is "Home", selected by default, displaying the referral card and dashboard navigation cards.
   - The "Home" tab does not possess an `X` (close) button. Hovering over it or right-clicking shows no close option.

### Scenario 2: Dynamic Tab Creation from Dashboard Cards
1. **Action**: On the Home tab, click the "Cài Đặt" (Settings) card.
2. **Expectation**:
   - A new tab titled "Cài Đặt" appears immediately on the tab strip to the right of Home.
   - The active view switches to SettingsPage.
   - The "Cài Đặt" tab displays an `X` close icon.
3. **Action**: On the Home tab, click the "Cơ sở dữ liệu" (Database) card.
4. **Expectation**:
   - A new tab titled "Cơ sở dữ liệu" opens and takes active focus.
5. **Action**: Click the `X` button on the "Cài Đặt" tab.
6. **Expectation**:
   - The "Cài Đặt" tab closes cleanly. Active focus returns to the "Cơ sở dữ liệu" tab.

### Scenario 3: Tab Tear-Off to Create a New Window
1. **Action**: In Window 1 (containing "Home" and "Cơ sở dữ liệu"), click and drag the "Cơ sở dữ liệu" tab header out of the window onto an empty desktop area.
2. **Expectation**:
   - A new independent window (Window 2) is created at the drop coordinates.
   - Window 2 hosts the "Cơ sở dữ liệu" tab along with its anchored "Home" tab.
   - Window 1 (which previously had only 2 tabs: Home + Cơ sở dữ liệu) is left with no remaining content tabs and automatically closes per the donor auto-close rule.

### Scenario 4: Cross-Window Tab Docking
1. **Action**: Open Window 1 with Home, Database A, and Settings. Open Window 2 with Home and Database B.
2. **Action**: Drag the "Database B" tab from Window 2 and release it onto Window 1's tab strip.
3. **Expectation**:
   - "Database B" is docked into Window 1 between Database A and Settings.
   - Window 2 (which had only 2 tabs: Home + Database B) automatically closes cleanly.
   - Window 1 now contains Home, Database A, Database B, and Settings.

### Scenario 5: Multi-Instance Process Concurrency
1. **Action**: Launch DataSphere from Terminal 1: `dotnet run --project DataSphere\DataSphere.csproj`.
2. **Action**: Launch DataSphere from Terminal 2: `dotnet run --project DataSphere\DataSphere.csproj`.
3. **Expectation**:
   - Both processes launch concurrently without single-instance mutex rejection.
   - Two completely independent instances operate side-by-side.
