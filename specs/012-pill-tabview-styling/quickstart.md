# Quickstart: Pill-Shaped TabViewItem Styling and Borderless TabStrip

**Feature Branch**: `012-pill-tabview-styling`
**Date**: 2026-10-21
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

This quickstart guide outlines the concrete validation steps to verify the pill-shaped tab headers and the removal of the bottom border divider line.

---

## 1. Compilation Verification

Verify that all XAML changes in `ShellWindow.xaml` and any resource definitions compile cleanly without errors:

```powershell
dotnet build DataSphere\DataSphere.csproj -c Debug
```

Expected result:
```text
Build succeeded.
    0 Warning(s)
    0 Error(s)
```

---

## 2. Visual & Pixel Verification on Real Desktop (`WinSta0\default`)

Run UI automation script to launch DataSphere on the interactive desktop, inspect the TabView geometry, and capture DirectComposition screenshots:

1. Launch DataSphere.
2. Verify tab headers:
   - Each tab header has rounded pill corners (`CornerRadius="16"`).
   - Margins between tabs keep them visually detached as floating capsules.
3. Verify borderless tab strip:
   - Inspect pixels along the horizontal seam between `Grid.Row="0"` (TabView) and `Grid.Row="1"` (ContentPresenter).
   - Confirm there is NO 1px gray border or dividing stroke.
4. Save DirectComposition screenshot to session artifacts directory:
   - `winui_pill_tabview_verified.png`
