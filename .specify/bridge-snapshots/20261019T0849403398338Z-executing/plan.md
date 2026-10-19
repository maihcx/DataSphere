# Implementation Plan: WinUI 3 Modern Tabbed Shell & Multi-Window Navigation

**Branch**: `001-winui3-chrome-tabs` | **Date**: 2026-10-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from [`specs/001-winui3-chrome-tabs/spec.md`](spec.md)

---

## Summary

Migrate the DataSphere presentation layer from WPF (`Wpf.Ui`) to **Windows App SDK (WinUI 3)** on .NET 10, completely eliminating the legacy vertical sidebar navigation in favor of a modern, browser-style Chrome tab strip integrated into the window titlebar. The shell features an anchored, uncloseable "Home" tab hosting the existing dashboard cards, dynamic tab launching for "Cơ sở dữ liệu" and "Cài Đặt", full tab tear-off into new windows, cross-window tab docking, an automatic donor window closure rule for 2-tab windows, and multi-instance process concurrency.

---

## Technical Context

**Language/Version**: C# (LangVersion `preview`), .NET 10 (`net10.0-windows10.0.19041.0` unpackaged desktop)

**Primary Dependencies**:
- `Microsoft.WindowsAppSDK` (v1.6+) — Native Windows UI framework, `AppWindow`, `TabView` control.
- `CommunityToolkit.Mvvm` (v8.4.2) — Clean MVVM source generators (`[ObservableProperty]`, `[RelayCommand]`, `WeakReferenceMessenger`).
- `Microsoft.Extensions.Hosting` (v10.0.0) — Dependency injection and hosted lifecycle.
- `MySqlConnector` (v2.4.0) — High-performance async database connectivity.

**Storage**: Local encrypted connection profiles via `PasswordEncryptor` (DPAPI/AES-GCM).

**Testing**: MSTest / xUnit with UI Automation (`winapp ui`) and ViewModel unit tests.

**Target Platform**: Windows 10 (Version 2004 / Build 19041+) and Windows 11 (x64 / ARM64).

**Project Type**: Desktop GUI Client (Multi-Window / Multi-Tab).

**Performance Goals**:
- Shell startup to interactive Home tab: < 1.5 seconds.
- Tab switching and card-to-tab creation: < 100 milliseconds.
- Tab drag-and-drop tear-off visual feedback: consistent 60 FPS (<16ms frame time).

**Constraints**:
- Clean MVVM adherence: Zero visual WPF/WinUI types inside ViewModels.
- 100% English XML documentation comments on all classes, methods, and properties.
- Donor window auto-closure rule MUST be strictly enforced when the content tab is moved away from a 2-tab window.

**Scale/Scope**:
- 1 top-level shell window with `TabView`.
- 3 primary views migrated: `HomePage` (formerly Dashboard), `DatabasePage`, `SettingsPage`.
- 2 service contracts: `ITabService`, `IWindowManager`.

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Compliance Status | Assessment / Proof |
|---|---|---|
| **I. Clean MVVM & Type Safety** | **PASS** | ViewModels use `[ObservableProperty]`, `[RelayCommand]`. Communication between Dashboard and TabView uses `WeakReferenceMessenger` and `ITabService`. ViewModels are 100% UI-agnostic. |
| **II. Modern Fluent UI / UX** | **PASS** | Native WinUI 3 `TabView` and `AppWindow` titlebar extension provide Fluent Design 2 with native Mica backdrop and Dark/Light theme sync. |
| **III. Secure Database Connections** | **PASS** | Credential management via `PasswordEncryptor` remains untouched; no plain-text secrets in tab headers or logs. |
| **IV. High Performance & Threads** | **PASS** | WinUI 3 native composition engine eliminates WPF software blitting; tab dragging and tear-off run on optimized native window threads. |
| **V. English Technical Docs** | **PASS** | All new classes (`TabItemModel`, `WindowSession`, `ITabService`, `IWindowManager`) require 100% US English XML doc comments. |
| **VI. Spec-Driven & Superpowers** | **PASS** | Spec established in `spec.md`, design in `plan.md`, `research.md`, `data-model.md`, `contracts/`, and `quickstart.md`. |

---

## Project Structure

### Documentation (this feature)

```text
specs/001-winui3-chrome-tabs/
├── plan.md              # Implementation Plan
├── research.md          # Technology decisions & WinUI 3 TabView tear-off evaluation
├── data-model.md        # Entities, state machine, and behavioral invariants
├── quickstart.md        # Validation guide for end-to-end verification
├── contracts/           # Service interfaces (ITabService, IWindowManager)
│   ├── ITabService.md
│   └── IWindowManager.md
└── tasks.md             # Generated in next phase (/speckit-tasks)
```

### Source Code Layout

```text
DataSphere/
├── DataSphere.csproj                # Target net10.0-windows10.0.19041.0, WinUI 3 SDK
├── App.xaml / App.xaml.cs           # WinUI 3 Application entry point, multi-window host
├── Models/
│   ├── TabItemModel.cs              # Tab entity with IsClosable, Content, Title
│   ├── WindowSession.cs             # Window session registry model
│   └── TabDragPayload.cs            # Drag-and-drop transit entity
├── Services/
│   ├── Contracts/
│   │   ├── ITabService.cs           # Tab management service interface
│   │   └── IWindowManager.cs        # Multi-window coordination interface
│   ├── TabService.cs                # Per-window tab service implementation
│   └── WindowManager.cs             # Singleton multi-window orchestrator
├── ViewModels/
│   ├── Windows/
│   │   └── ShellViewModel.cs        # Main shell ViewModel driving TabView
│   └── Pages/
│       ├── HomeViewModel.cs         # Dashboard card actions triggering tab open
│       ├── DatabaseViewModel.cs     # Database Explorer
│       └── SettingsViewModel.cs     # Application settings
└── Views/
    ├── Windows/
    │   └── ShellWindow.xaml         # TabView in TitleBar, ContentPresenter
    └── Pages/
        ├── HomePage.xaml            # Referral card + Navigation cards
        ├── DatabasePage.xaml        # Database connections view
        └── SettingsPage.xaml        # Settings view
```

---

## Planned Implementation Phases

### Phase 0: Outline & Research *(Complete)*
- Evaluated Windows App SDK `TabView` capabilities and custom titlebar integration.
- Documented tab tear-out and cross-window docking mechanics in [`research.md`](research.md).
- Formulated the donor window auto-closure logic.

### Phase 1: Design & Contracts *(Complete)*
- Modeled data structures and state transitions in [`data-model.md`](data-model.md).
- Formulated service contracts in [`contracts/ITabService.md`](contracts/ITabService.md) and [`contracts/IWindowManager.md`](contracts/IWindowManager.md).
- Authored runnable test scenarios in [`quickstart.md`](quickstart.md).

### Phase 2: Project Setup & Package Conversion *(Pending Tasks)*
- Update `DataSphere.csproj` to enable WinUI 3 / Windows App SDK 1.6+ dependencies.
- Remove WPF-specific libraries (`Wpf.Ui`, `Wpf.Ui.Tray`) and legacy references.
- Configure unpackaged desktop executable manifest.

### Phase 3: Shell & Tab Infrastructure *(Pending Tasks)*
- Implement `TabItemModel`, `WindowSession`, and `TabDragPayload`.
- Implement `ITabService` and `IWindowManager`.
- Build `ShellWindow.xaml` with `TabView` embedded into the window titlebar.
- Anchor the uncloseable `Home` tab at index 0.

### Phase 4: Page Migration & Card Dispatching *(Pending Tasks)*
- Migrate `DashboardPage` to WinUI 3 `HomePage`.
- Wire dashboard card clicks ("Cơ sở dữ liệu", "Cài Đặt") to open dynamic closable tabs via `ITabService`.
- Migrate `DatabasePage` and `SettingsPage` XAML and controls.

### Phase 5: Multi-Window Drag-and-Drop & Auto-Closure *(Pending Tasks)*
- Hook `TabView.TabDroppedOutside` to spawn new `ShellWindow` instances via `IWindowManager`.
- Hook `TabView.TabStripDrop` to dock incoming tabs into destination windows.
- Enforce the 2-tab donor auto-closure rule.
- Remove single-instance mutex blocking in `Bootstrap.cs`.

---

## Constitution Re-Check (Post-Design)

- [x] All 6 Constitution principles remain satisfied with 0 violations.
- [x] ViewModels remain UI-agnostic with clean separation of concerns.
- [x] All artifacts are completely documented and cross-linked.
