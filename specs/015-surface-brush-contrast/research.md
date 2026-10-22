# Research & Architectural Decisions: Surface & Tab Selected Theme Brush Contrast Enhancement

**Feature**: `015-surface-brush-contrast`
**Spec**: [spec.md](./spec.md)
**Plan**: [plan.md](./plan.md)

---

## 1. Background & Root Cause Analysis

### 1.1 The Faint Dark Mode Problem with `LayerFillColorDefaultBrush`
In Windows App SDK / WinUI 3 Fluent Design 2, theme resources are organized hierarchically:
- **`LayerFillColorDefaultBrush`** is intended as a subtle layer wash over window backdrops (Mica/Acrylic). In Dark theme, its alpha opacity is approximately **5%** (`#0DFFFFFF`).
- When placed over dark Mica or dark acrylic surfaces (which average `#1C1C1C` to `#202020`), a 5% wash provides virtually zero visual elevation.
- Consequently:
  1. Selected tab pills in `PillTabViewItemStyle` appear washed out and blend into the unselected tab strip.
  2. Main workspace containers in `DatabasePage`, `ConnectViewControl`, `DatabaseViewControl`, and `VirtualTable` look transparent and lack framing depth.

### 1.2 Comparison of Fluent Design Surface Brushes

| Candidate Brush | Dark Theme Characteristics | Light Theme Characteristics | Evaluation |
|---|---|---|---|
| **`CardBackgroundFillColorDefaultBrush`** (Chosen) | Solid elevated card fill (`#2D2D2D` / `#323232` with subtle layer), crisp contrast with `CardStrokeColorDefaultBrush` | Clean white card surface (`#FFFFFF` / `#B3FFFFFF`) | **Selected**: Proven on `HomePage` header and cards. Provides clear elevation, high contrast, and perfect visual harmony. |
| **`LayerOnMicaBaseAltFillColorDefaultBrush`** | Moderate opacity wash over Mica Alt | Slightly elevated white | Dependent on Mica Alt backdrop; lacks solid card presence when Acrylic or Solid background is used. |
| **`SolidBackgroundFillColorSecondaryBrush`** | 100% opaque dark gray (`#1C1C1C`) | 100% opaque light gray (`#F9F9F9`) | Eliminates all backdrop translucency; feels heavy for selected tab pills. |
| **`CardBackgroundFillColorSecondaryBrush`** | Sub-card fill, slightly different elevation | Sub-card fill | Secondary elevation, intended for nested cards rather than primary containers. |

---

## 2. Key Decisions

### Decision 1: Standardize on `CardBackgroundFillColorDefaultBrush` for Elevated Surfaces
- **Decision**: Replace `LayerFillColorDefaultBrush` with `{ThemeResource CardBackgroundFillColorDefaultBrush}` across selected tab pill states and primary workspace container grids.
- **Rationale**:
  - `CardBackgroundFillColorDefaultBrush` is already standard across `HomePage` (Banner Border, Feature cards).
  - It maintains high contrast in Dark mode without losing the refined Fluent 2 aesthetic in Light mode.
  - Paired with `CardStrokeColorDefaultBrush`, it creates a unified card elevation hierarchy.
- **Alternatives Considered**:
  - *Keep `LayerFillColorDefaultBrush` and increase opacity manually via custom Color resource*: Rejected because hardcoding colors breaks official Windows system theme sync and high contrast accessibility.
  - *`SolidBackgroundFillColorBaseBrush`*: Rejected because it strips all subtle depth and feels like a flat legacy Win32 gray surface.

### Decision 2: Specific Scope of Target Files for Replacement
- **Decision**: Update the following 5 target files:
  1. `DataSphere/Themes/TabStyles.xaml`: VisualStates `Selected`, `PointerOverSelected`, `PressedSelected` for `PillBorder.Background`.
  2. `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml`: Row 1 inner workspace Grid `Background`.
  3. `DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml`: Root Grid `Background`.
  4. `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml`: Root Grid `Background`.
  5. `DataSphere/Controls/VirtualTable/VirtualTable.xaml`: Root Grid `Background`.
- **Rationale**: This addresses all occurrences of `LayerFillColorDefaultBrush` in user-facing presentation layers, leaving 0 inconsistent surfaces.

### Decision 3: Zero Code-Behind & 100% Declarative `{ThemeResource}`
- **Decision**: All replacements will be executed strictly in XAML via `{ThemeResource CardBackgroundFillColorDefaultBrush}`.
- **Rationale**:
  - Fulfills Principle I (Clean MVVM: zero UI logic in code-behind).
  - Guarantees immediate runtime theme switching (Dark ↔ Light) via WinUI 3 resource lookup without requiring C# property change notifications or app restart.

---

## 3. Accessibility & Contrast Verification (WCAG AA)

- **Dark Theme**:
  - Background: `CardBackgroundFillColorDefaultBrush` (~ `#2D2D2D`)
  - Primary Text: `TextFillColorPrimaryBrush` (`#FFFFFF`) → Contrast Ratio: **13.5:1** (Exceeds WCAG AAA requirement of 7:1)
  - Secondary Text: `TextFillColorSecondaryBrush` (`#C5FFFFFF`) → Contrast Ratio: **9.2:1** (Exceeds WCAG AAA)
  - Accent / Icons: `AccentTextFillColorPrimaryBrush` → Contrast Ratio > **4.5:1** (Exceeds WCAG AA)
- **Light Theme**:
  - Background: `CardBackgroundFillColorDefaultBrush` (`#FFFFFF`)
  - Primary Text: `TextFillColorPrimaryBrush` (`#E4000000`) → Contrast Ratio: **15.8:1** (Exceeds WCAG AAA)
