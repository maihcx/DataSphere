# Quickstart: Dedicated ComboBox Models and Dynamic i18n Theme Architecture

**Feature Branch**: `011-combobox-models-theme-i18n`
**Date**: 2026-10-21
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

This quickstart guide details the validation workflow to prove that dedicated ComboBox models, domain enums, and in-place dynamic i18n localization operate correctly without regressions.

---

## 1. Compilation Verification

Verify that all newly created models, updated services, and modified viewmodels compile with 0 warnings and 0 errors:

```powershell
dotnet build DataSphere\DataSphere.csproj -c Debug
```

Expected output:
```text
Build succeeded.
    0 Warning(s)
    0 Error(s)
```

---

## 2. In-Place i18n Dynamic Localization Test

Verify that switching languages does NOT recreate `ObservableCollection` items, but updates `DisplayName` and `Description` in-place:

1. Launch DataSphere.
2. Navigate to Settings page.
3. Observe `ThemeList` contains 3 items: "Sáng", "Tối", "Mặc định hệ thống" (in Vietnamese).
4. Select "Tối" (`AppThemeMode.Dark`).
5. Change language ComboBox to "English".
6. Observe:
   - Theme options immediately change to "Light", "Dark", "Windows Default".
   - The selected theme remains "Dark" without becoming unselected or resetting to index 0.
   - Backdrop options update their `DisplayName` and `Summary` in-place.
7. Change language back to "Tiếng Việt".
   - Options update back immediately.

---

## 3. UI Automation & Visual Inspection Gate (Principle VIII)

Run the automated UI test script on the real desktop station (`WinSta0\default`):

```powershell
pwsh -ExecutionPolicy Bypass -File scripts/verify-fluent-settings-and-backdrops.ps1
```

Verification assertions:
- WinUI 3 window launches on `WinSta0\default`.
- Navigates to Settings page.
- ComboBox items for Theme and Backdrop match domain enums.
- Screen capture via DirectComposition (`PW_RENDERFULLCONTENT`) confirms clean typography, no Mojibake, and high-contrast rendering.
