# Quickstart: Tab Switching Transition Animations

**Feature**: Tab Switching Transition Animations (ShellWindow & DatabasePage)  
**Branch**: `017-tab-transition-animations`  
**Date**: 2026-10-23  

---

## 1. Overview

This feature delivers hardware-accelerated WinUI 3 Compositor transition animations during tab switching:
1. **Viewport Content Transition**: In `CachedContentControl`, newly activated views enter with a 167ms fade-in (`Opacity` 0 → 1) and micro-translation along the Y-axis (+12px → 0px) using the Windows 11 Decelerate easing curve.
2. **Tab Header Sliding Indicator**: In `TabView`, the active selection pill animates continuously between tabs using `SlidingTabIndicatorBehavior` via Compositor `Offset` animations.
3. **Clean MVVM Invariant**: 100% of transitions are driven declaratively in XAML. Code-behind files (`ShellWindow.xaml.cs` and `DatabasePage.xaml.cs`) remain completely free of visual tree DOM manipulation.

---

## 2. Verification Commands

### 1. Build Verification
```powershell
dotnet build DataSphere\DataSphere.csproj -c Debug
```
*(Expected: 0 Warnings, 0 Errors)*

### 2. Manual Verification Checklist
1. Launch `DataSphere`.
2. Open multiple tabs in `ShellWindow` (e.g. Home, Settings, Database connection).
3. Click between tabs:
   - Observe smooth horizontal slide of selection indicator in title bar.
   - Observe 167ms fluid fade-in and subtle upward entrance of viewport content.
4. Inside a database connection, open multiple table tabs.
5. Click between table tabs:
   - Observe instant responsiveness with fluid 167ms entrance motion.
   - Verify that table scroll position and loaded row data remain intact.
6. In Windows Settings > Accessibility > Visual Effects, turn "Animation effects" OFF:
   - Click between tabs: transitions execute instantaneously with 0ms delay.
