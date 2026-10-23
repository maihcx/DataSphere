# Implementation Plan: Tab Switching Transition Animations (ShellWindow & DatabasePage)

**Branch**: `017-tab-transition-animations` | **Date**: 2026-10-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/017-tab-transition-animations/spec.md`

## Summary

Implement hardware-accelerated WinUI 3 Compositor transition animations for tab switching across `ShellWindow` and `DatabasePage`:
1. **Viewport Transition**: `CachedContentControl` executes a 167ms entrance animation (Opacity 0.0 → 1.0 combined with Y-axis translation +12px → 0px) using `Microsoft.UI.Composition` and the Windows 11 Fluent Decelerate cubic-bezier curve `(0.1, 0.9, 0.2, 1.0)`.
2. **Tab Header Sliding Indicator**: Introduce a reusable `SlidingTabIndicatorBehavior` attached to `TabView` that continuously animates the selection pill/indicator horizontally between tabs using Compositor `Offset` animations.
3. **Clean MVVM Invariant**: Strict compliance with Constitution v1.6.0 Principle I (zero code-behind DOM manipulation; pure declarative XAML consumption).

## Technical Context

**Language/Version**: C# (LangVersion `preview`), .NET 10 (`net10.0-windows10.0.26100.0`)  
**Primary Dependencies**: Windows App SDK (WinUI 3), `Microsoft.UI.Composition`, `Microsoft.UI.Xaml.Hosting.ElementCompositionPreview`, `CommunityToolkit.Mvvm`  
**Storage**: N/A  
**Testing**: Static architecture compliance review, `dotnet build` gate, Win32 Interactive Desktop UI verification (`scripts/test-real-desktop.ps1`)  
**Target Platform**: Windows 10/11 x64 Desktop (`win-x64`)  
**Project Type**: Desktop GUI Application (WinUI 3 / Windows App SDK)  
**Performance Goals**: 60 FPS fluid rendering (<16ms per frame) during tab transitions, zero UI thread blocking, instant tab responsiveness (<1ms layout overhead)  
**Constraints**: Zero code-behind UI manipulation in views; 100% US English XML doc comments; automatic bypass when Windows OS animations are disabled (`UISettings.AnimationsEnabled == false`)  
**Scale/Scope**: Affects `CachedContentControl`, `ShellWindow.xaml`, `DatabasePage.xaml`, and introduces `SlidingTabIndicatorBehavior` in `DataSphere/Controls/`  

## Constitution Check

*GATE: Evaluated against Constitution v1.6.0.*

- **Principle I: Clean MVVM & Type Safety** — **PASS**: All animation logic is cleanly encapsulated inside `CachedContentControl` and `SlidingTabIndicatorBehavior`. `DatabasePage.xaml.cs` and `ShellWindow.xaml.cs` contain exactly 0 lines of visual tree / DOM manipulation. ViewModels remain 100% UI-agnostic.
- **Principle II: Modern Fluent UI / UX Standards** — **PASS**: Adheres to Windows 11 Fluent Design motion guidelines (167ms entrance, decelerate curve `(0.1, 0.9, 0.2, 1.0)`).
- **Principle III: Secure Database Connection & Credential Protection** — **PASS**: No credential handling touched.
- **Principle IV: High Performance & Thread Stewardship** — **PASS**: Animations run on the DirectComposition render thread off the UI thread; no visual tree tear-down or allocation churn.
- **Principle V: English Technical Documentation Standard** — **PASS**: 100% public and internal members will have full US English XML doc comments.
- **Principle VI: Spec-Driven Development & Superpowers Discipline** — **PASS**: Follows spec -> plan -> tasks workflow.
- **Principle VII: Zero Hardcoded User-Facing Strings & Dynamic i18n** — **PASS**: No new hardcoded text strings introduced.
- **Principle VIII: Visual UI Reproduction & Verification Gate** — **PASS**: Real desktop UI verification blueprint integrated.

## Project Structure

### Documentation (this feature)

```text
specs/017-tab-transition-animations/
├── spec.md              # Feature specification & user stories
├── plan.md              # Architectural implementation plan (this file)
├── research.md          # Phase 0: WinUI 3 Compositor research & motion curves
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
│   ├── CachedContentControl.cs         # Updated: Add WinUI 3 Compositor entrance animation
│   ├── SlidingTabIndicatorBehavior.cs  # Added: Attached behavior for sliding tab indicator
│   └── TabMotionConfiguration.cs       # Added: Centralized Fluent Design motion constants
├── Views/
│   ├── Windows/
│   │   └── ShellWindow.xaml            # Updated: Declarative SlidingTabIndicatorBehavior & CachedContentControl
│   └── Pages/DatabaseGroup/
│       └── DatabasePage.xaml           # Updated: Declarative SlidingTabIndicatorBehavior & CachedContentControl
```

**Structure Decision**: Enhancements reside strictly in the presentation control layer (`DataSphere/Controls/`). Existing XAML views consume them declaratively.

## Architecture & Implementation Details

### Phase 0: Research (Completed in `research.md`)
- Identified `Microsoft.UI.Composition` as the gold standard for 60 FPS transitions without UI thread blocking.
- Mapped entrance parameters: Opacity (0.0 → 1.0) and Y-translation (+12px → 0px) over 167ms with Decelerate curve `(0.1f, 0.9f, 0.2f, 1.0f)`.
- Verified `UISettings.AnimationsEnabled` for automatic accessibility fallback.

### Phase 1: Design & Contracts (Completed in `contracts/control-contracts.md` and `data-model.md`)
- `TabMotionConfiguration`: Static motion constants.
- `CachedContentControl`: Enhanced `UpdateActiveContent` method dispatches compositor entrance animations to the active child visual.
- `SlidingTabIndicatorBehavior`: Attached behavior calculating selected tab geometry and translating selection visual horizontally.

### Phase 2: Execution Roadmap (to be broken down in `tasks.md`)
1. Implement `TabMotionConfiguration.cs` with motion timing and easing curves.
2. Implement compositor entrance animation in `CachedContentControl.cs`.
3. Implement `SlidingTabIndicatorBehavior.cs` for `TabView`.
4. Update `ShellWindow.xaml` and `DatabasePage.xaml` declaratively.
5. Compile and verify with `dotnet build` and real desktop UI verification.

## Complexity Tracking

> **Zero violations**. No complex architectural patterns or MVVM compromises required.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| None | N/A | N/A |
