# Quickstart & Verification Guide: User Preferences & State Persistence

**Feature**: `003-user-data-store-persistence`
**Date**: 2026-10-20
**Status**: Ready for Verification

## 1. Prerequisites

- .NET 10 SDK (`net10.0-windows10.0.26100.0`)
- Windows 10/11 x64 environment
- Clean working directory with all prior features passing

---

## 2. Verification Scenarios

### Scenario 1: Theme Persistence Verification
1. Launch DataSphere:
   ```powershell
   dotnet run --project DataSphere\DataSphere.csproj
   ```
2. Navigate to **Cài Đặt / Settings** via the dashboard card or top tab.
3. Select **Dark** theme from the App Theme dropdown.
   - **Expected**: Window background and controls immediately switch to Dark mode in real-time.
4. Close the application.
5. Re-launch DataSphere:
   ```powershell
   dotnet run --project DataSphere\DataSphere.csproj
   ```
   - **Expected**: Window and Home dashboard launch directly in Dark theme without flashing or reverting to Light/Default.

### Scenario 2: Language Preference Startup Verification
1. Open **Settings**.
2. Switch display language to **Tiếng Việt**.
   - **Expected**: Tab header, action cards, and settings text immediately render in Vietnamese.
3. Close the application.
4. Inspect `%LOCALAPPDATA%\DataSphere\userdata.json`:
   - Verify `"Language": "vi"` is present.
5. Re-launch DataSphere:
   - **Expected**: Application immediately starts in Vietnamese, with the Home tab displaying "Trang chủ" from the first frame.

### Scenario 3: Window Placement & Maximized State Verification
1. Resize the DataSphere window to `1400x900` and position it near the center of the display.
2. Close the window.
3. Re-launch the app.
   - **Expected**: Window restores to `1400x900` at the same screen coordinates.
4. Maximize the window.
5. Close the window while maximized.
6. Re-launch the app.
   - **Expected**: Window opens directly in the maximized state.

### Scenario 4: Storage Fault Tolerance
1. Manually open `%LOCALAPPDATA%\DataSphere\userdata.json` and insert invalid syntax (e.g., `{ broken json...`).
2. Launch DataSphere.
   - **Expected**: Application boots gracefully with standard default bounds (1280x800) and default theme/language without throwing an unhandled exception.
