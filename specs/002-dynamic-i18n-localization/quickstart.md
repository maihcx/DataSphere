# Quickstart Validation Guide: Dynamic i18n & Zero Hardcoded Strings

**Feature**: `002-dynamic-i18n-localization` | **Date**: 2026-10-19

This guide outlines runnable verification scenarios to validate that all hardcoded strings have been eradicated and that dynamic internationalization works end-to-end across DataSphere.

---

## 1. Prerequisites

1. Windows 10 (Build 19041+) or Windows 11.
2. .NET 10 SDK installed.
3. Clean build of the DataSphere project:
   ```powershell
   dotnet build DataSphere\DataSphere.csproj -c Debug
   ```

---

## 2. Validation Scenarios

### Scenario 1: Initial Launch Localization (Vietnamese Default)
1. **Action**: Launch DataSphere.
2. **Expectation**:
   - The first tab is displayed as **"Trang chủ"** (not hardcoded "Home" unless language is English).
   - The Home page displays the section title **"Các Phân Hệ Chính"** and cards for **"Cơ sở dữ liệu"** and **"Cài đặt"**.
   - Action descriptions match Vietnamese locale resources.

### Scenario 2: Dynamic Live Language Switching
1. **Action**: On the Home tab, click the **"Cơ sở dữ liệu"** card to open the Database tab.
2. **Action**: Click the **"Cài đặt"** card to open the Settings tab.
3. **Action**: On the Settings tab, select **"English"** from the language dropdown.
4. **Expectation**:
   - Tab 0 ("Trang chủ") immediately updates to **"Home"**.
   - Tab 1 ("Cơ sở dữ liệu") immediately updates to **"Databases"**.
   - Tab 2 ("Cài đặt") immediately updates to **"Settings"**.
   - The Settings page headers and options immediately switch to English without restarting the app.
   - Click the "Home" tab; verify section title is **"Main Modules"** and cards read **"Databases"** and **"Settings"**.

### Scenario 3: Language Switching Across Multiple Windows
1. **Action**: In Window 1, drag the "Databases" tab outside to tear off into Window 2.
2. **Action**: In Window 2, open Settings and switch language back to **"Tiếng Việt"**.
3. **Expectation**:
   - Window 2's tabs and settings page update to Vietnamese immediately.
   - Window 1's tabs and active page also update to Vietnamese synchronously via the shared `TranslationSource` singleton.

### Scenario 4: Codebase Zero-Hardcoded-String Audit
1. **Action**: Run code search for prohibited string patterns:
   - Search for `"Cơ sở dữ liệu"` in `*.cs` files outside resource files.
   - Search for `"Cài Đặt"` in `*.cs` files outside resource files.
2. **Expectation**:
   - Zero occurrences in `HomeViewModel.cs`, `DatabaseViewModel.cs`, `ShellViewModel.cs`, `HomePage.xaml`, or `TabService.cs`.
