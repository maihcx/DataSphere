# Quickstart: Validating Fluent Settings & System Backdrops

**Feature**: `010-fluent-settings-and-system-backdrops`
**Date**: 2026-10-21T14:13:55+07:00

---

## 1. Prerequisites

- Windows 11 (Build 22000+) or Windows 10 (1809+) for Desktop Acrylic.
- .NET 10 SDK preview installed.
- Target executable: `DataSphere/bin/Debug/net10.0-windows10.0.26100.0/win-x64/DataSphere.exe`.

---

## 2. Validation Scenarios

### Scenario 1: Settings Page Layout & Untruncated Controls
1. Launch `DataSphere.exe`.
2. Click the "Cài đặt" (Settings) tab.
3. Observe the layout:
   - Setting cards are centered with `MaxWidth="900"`.
   - All text in ComboBoxes ("Mặc định hệ thống", "Tiếng Việt", "Tabbed (Mica Alt)") is completely visible without ellipsis (`...`).
   - The titlebar area has zero black or transparent cutouts.

### Scenario 2: System Backdrop Switching in Real Time
1. In Settings -> "Cá nhân hóa" -> "Hiệu ứng nền" (Backdrop Material):
2. Click the Backdrop ComboBox and select:
   - **Mica (Tiêu chuẩn)**: The window background applies subtle wallpaper tinting.
   - **Acrylic (Kính mờ)**: The window background applies frosted glass blur.
   - **Mặc định (Đơn sắc)**: The window background transitions cleanly to solid system background color.
   - **Tabbed (Mica Alt)**: The window background returns to high-contrast Tabbed Mica.
3. Verify that the transition takes effect immediately without window flicker or restart.

### Scenario 3: Theme and Language Dynamic Synchronization
1. Switch Theme between "Sáng" (Light) and "Tối" (Dark).
   - Verify all cards, icons, and text adapt their ThemeResource colors synchronously with the backdrop.
2. Switch Language between "Tiếng Việt" and "English".
   - Verify all backdrop names and setting cards translate immediately without resetting user selections.

### Scenario 4: Backdrop Persistence Across Restarts
1. Select "Acrylic" in Settings.
2. Close `DataSphere.exe`.
3. Relaunch `DataSphere.exe`.
4. Verify the window immediately opens with the Acrylic backdrop active.

---

## 3. Automated Desktop UI Verification

Run the automated test on `WinSta0\default`:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify-fluent-settings-and-backdrops.ps1
```
Expected output:
- `ALL FLUENT SETTINGS AND SYSTEM BACKDROP TESTS PASSED!`
- DirectComposition screenshots saved to artifact directory:
  - `winui_settings_fluent_layout.png`
  - `winui_backdrop_tabbed.png`
  - `winui_backdrop_acrylic.png`
  - `winui_backdrop_solid.png`
