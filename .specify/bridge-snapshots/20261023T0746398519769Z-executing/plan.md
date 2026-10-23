# Implementation Plan: Fluent Tab Selection Pill, Sliding Background & Directional Page Motion

**Branch**: `018-tab-motion-and-indicator` | **Date**: 2026-10-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/018-tab-motion-and-indicator/spec.md`

## Summary

Enhance and refine the tab switching motion experience across `ShellWindow` and `DatabasePage`:
1. **Windows 11 Accent-Adherent Compact Pill Indicator**: Modernize the tab indicator from a heavy, full-width rectangular line into a compact (20px × 3px), fully rounded pill (`CornerRadius = 1.5px`) that strictly resolves the active Windows 11 system accent color dynamically from OS/theme resources.
2. **Smooth Sliding Background Capsule**: Implement a hardware-accelerated sliding selection background capsule (`CornerRadius = 6.0px`) in `SlidingTabIndicatorBehavior` that translates and resizes seamlessly between tabs alongside the accent pill, eliminating visual snapping.
3. **Direction-Aware Horizontal Page Content Transition**: Upgrade `CachedContentControl` and `TabMotionConfiguration` to execute a 300ms horizontal slide (`±32px -> 0px`) and fade (`0.0 -> 1.0`) entrance animation using the Windows 11 Fluent Decelerate cubic-bezier curve `(0.1, 0.9, 0.2, 1.0)`, dynamically oriented based on the tab navigation order (left-to-right vs. right-to-left).
4. **Clean MVVM Invariant**: Strict compliance with Constitution v1.6.0 Principle I (zero code-behind visual tree or DOM manipulation in `ShellWindow.xaml.cs` or `DatabasePage.xaml.cs`; all transitions encapsulated cleanly within the presentation controls layer).

## Technical Context

**Language/Version**: C# (LangVersion `preview`), .NET 10 (`net10.0-windows10.0.26100.0`)  
**Primary Dependencies**: Windows App SDK (WinUI 3), `Microsoft.UI.Composition`, `Microsoft.UI.Xaml.Hosting.ElementCompositionPreview`, `CommunityToolkit.Mvvm`  
**Storage**: N/A  
**Testing**: Static architecture compliance review, `dotnet build` 0-error gate, Win32 Interactive Desktop UI verification (`scripts/test-real-desktop.ps1`)  
**Target Platform**: Windows 10/11 x64 Desktop (`win-x64`)  
**Project Type**: Desktop GUI Application (WinUI 3 / Windows App SDK)  
**Performance Goals**: Fluid 60 FPS rendering (<16ms per frame) during transitions, zero UI thread blocking, instant response (<1ms layout overhead)  
**Constraints**: Zero code-behind UI manipulation in views; 100% US English XML doc comments; automatic bypass when Windows OS animations are disabled (`UISettings.AnimationsEnabled == false`)  
**Scale/Scope**: Refines `TabMotionConfiguration.cs`, `SlidingTabIndicatorBehavior.cs`, `CachedContentControl.cs`, `TabStyles.xaml`, `ShellWindow.xaml`, and `DatabasePage.xaml`  

## Constitution Check

*GATE: Evaluated against Constitution v1.6.0.*

- **Principle I: Clean MVVM & Type Safety** — **PASS**: All animation logic is cleanly encapsulated inside `CachedContentControl` and `SlidingTabIndicatorBehavior`. `DatabasePage.xaml.cs` and `ShellWindow.xaml.cs` contain exactly 0 lines of visual tree / DOM manipulation. ViewModels remain 100% UI-agnostic.
- **Principle II: Modern Fluent UI / UX Standards** — **PASS**: Adheres to Windows 11 Fluent Design motion guidelines (300ms directional slide, 250ms indicator slide, decelerate curve `(0.1, 0.9, 0.2, 1.0)`, and dynamic system accent color).
- **Principle III: Secure Database Connection & Credential Protection** — **PASS**: No credential handling touched.
- **Principle IV: High Performance & Thread Stewardship** — **PASS**: Animations run on the DirectComposition render thread off the UI thread; no visual tree tear-down or allocation churn.
- **Principle V: English Technical Documentation Standard** — **PASS**: 100% public and internal members will have full US English XML doc comments.
- **Principle VI: Spec-Driven Development & Superpowers Discipline** — **PASS**: Follows spec -> plan -> tasks workflow.
- **Principle VII: Zero Hardcoded User-Facing Strings & Dynamic i18n** — **PASS**: No new hardcoded text strings introduced.
- **Principle VIII: Visual UI Reproduction & Verification Gate** — **PASS**: Real desktop UI verification blueprint integrated.

## Project Structure

### Documentation (this feature)

```text
specs/018-tab-motion-and-indicator/
├── spec.md              # Feature specification & user stories
├── plan.md              # Architectural implementation plan (this file)
├── research.md          # Phase 0: WinUI 3 Compositor research, pill geometry & accent color
├── data-model.md        # Phase 1: Control entities & motion configuration
├── quickstart.md        # Phase 1: Verification guidelines
├── contracts/           # Phase 1: Component & XAML contracts
│   └── control-contracts.md
├── checklists/          # Quality verification checklists
│   └── requirements.md
└── tasks.md             # Phase 2: Actionable task list (generated via /speckit-tasks)
```

### Source Code (repository root)

```text
DataSphere/
├── Controls/
│   ├── TabMotionConfiguration.cs       # Refined: 300ms duration, ±32px EntranceOffsetX, pill & capsule geometry constants
│   ├── SlidingTabIndicatorBehavior.cs  # Refined: ShapeVisual rounded pill (20px × 3px), sliding background capsule, dynamic Windows 11 accent color
│   └── CachedContentControl.cs         # Refined: Direction-aware horizontal translation (+32px vs -32px) based on tab navigation order
├── Themes/
│   └── TabStyles.xaml                  # Refined: Transparent selection background to accommodate smooth sliding capsule
└── Views/
    ├── Windows/
    │   └── ShellWindow.xaml            # Refined: Bind SelectedIndex to CachedContentControl for directional slide
    └── Pages/DatabaseGroup/
        └── DatabasePage.xaml           # Refined: Bind SelectedIndex to CachedContentControl for directional slide
```

**Structure Decision**: Refinements reside strictly in the presentation control layer (`DataSphere/Controls/`) and shared tab styles (`Themes/TabStyles.xaml`). Existing views consume them declaratively.

## Architecture & Implementation Details

### Phase 0: Research (Completed in `research.md`)
- Mapped WinUI 3 `CompositionRoundedRectangleGeometry` within `ShapeVisual` for 100% hardware-accelerated rounded corners on both the accent pill (radius 1.5px) and background capsule (radius 6.0px).
- Defined dynamic accent color resolution chain: `AccentFillColorDefaultBrush` -> `SystemAccentColor` -> `UISettings.GetColorValue(UIColorType.Accent)`.
- Established direction-aware translation mechanics: comparing `targetIndex` with `previousIndex` in `CachedContentControl` to dispatch `+32px` vs `-32px` translation along the X-axis.

### Phase 1: Design & Contracts (Completed in `contracts/control-contracts.md` and `data-model.md`)
- `TabMotionConfiguration`: Static motion metrics (`ContentTransitionDuration = 300ms`, `TabIndicatorDuration = 250ms`, `EntranceOffsetX = 32.0f`, `IndicatorWidth = 20.0f`, `IndicatorHeight = 3.0f`, `IndicatorCornerRadius = 1.5f`, `BackgroundCornerRadius = 6.0f`).
- `SlidingTabIndicatorBehavior`: Multi-layer composition hosting both `BackgroundCapsuleVisual` (bottom) and `AccentPillVisual` (top) with synchronized decelerate animations.
- `CachedContentControl`: Added `SelectedIndex` dependency property and direction-aware X-axis entrance transition.
- `TabStyles.xaml`: Ensured `TabViewItem` selection visual state maintains transparent background so the sliding capsule is seamlessly visible.

### Phase 2: Execution Roadmap (to be broken down in `tasks.md`)
1. Refactor `TabMotionConfiguration.cs` with updated timing and geometry metrics.
2. Refactor `SlidingTabIndicatorBehavior.cs` with `ShapeVisual` rounded pill, sliding background capsule, and dynamic Windows 11 accent color lookup.
3. Update `TabStyles.xaml` to support transparent selected item backgrounds for the sliding capsule.
4. Refactor `CachedContentControl.cs` to implement direction-aware horizontal slide transitions (`±32px`).
5. Update `ShellWindow.xaml` and `DatabasePage.xaml` with `SelectedIndex` bindings on `CachedContentControl`.
6. Compile with `dotnet build` (0 warnings, 0 errors) and execute automated UI verification on `WinSta0\default`.

## Complexity Tracking

> **Zero violations**. No complex architectural patterns or MVVM compromises required.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| None | N/A | N/A |
