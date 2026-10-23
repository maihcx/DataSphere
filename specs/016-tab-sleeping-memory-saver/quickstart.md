# Quickstart: Tab Sleeping & Memory Saver Validation Guide

- **Feature**: `016-tab-sleeping-memory-saver`
- **Date**: 2026-10-23
- **Status**: Completed

## 1. Prerequisites

- Windows 10/11 x64 interactive desktop station (`WinSta0\default`).
- .NET 10 SDK installed.
- Local MySQL database connection available (e.g. `localhost`).

---

## 2. Validation Scenarios

### Scenario A: Instant Tab Switching (<16ms, Zero Delay)

1. Launch DataSphere: `dotnet run --project DataSphere\DataSphere.csproj`.
2. Connect to `localhost`, open table `banggiada_backup` (loads records into `VirtualTable`).
3. Click "Trang chủ" (Home) or "Cài đặt" (Settings).
4. Click back to "Cơ sở dữ liệu" tab immediately.
5. **Expected Outcome**:
   - Tab switch is instantaneous (0ms perceived latency).
   - Records display immediately without any blank flashes or loading spinners.
   - Selected row and cell remain highlighted; scroll offset is 100% preserved.

---

### Scenario B: Settings Configuration & Persistence

1. Navigate to the "Cài đặt" (Settings) page.
2. Scroll to the new **Hiệu năng & Bộ nhớ (Performance & Memory)** section.
3. Toggle "Tiết kiệm bộ nhớ cho tab nền" on and off; verify the timeout ComboBox enables/disables accordingly.
4. Select "30 phút" (30 minutes) and restart the application.
5. **Expected Outcome**:
   - On relaunch, the toggle state and 30-minute timeout remain selected.
   - Text is properly translated when switching between English and Vietnamese.

---

### Scenario C: Automated Tab Sleeping & Wakeup

1. Configure timeout to "5 phút" (or run automated harness with accelerated timer).
2. Open table in Database tab, then switch to Home and wait for timeout.
3. Observe tab item header in title bar.
4. **Expected Outcome**:
   - Tab header displays sleep icon / muted opacity.
   - Process Private Working Set memory drops significantly.
   - Clicking on the sleeping tab clears the sleep icon and restores the table viewport within <500ms.

---

### Scenario D: Terminal Close Cleanup (Zero Leak)

1. Open 3 database tabs with large record sets.
2. Note baseline working set memory.
3. Close all 3 tabs by clicking their `X` buttons.
4. **Expected Outcome**:
   - All tabs close cleanly.
   - Visual row pools, ViewModels, and connection readers are completely disposed.
