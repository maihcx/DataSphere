# Research & Architecture Decisions: WinUI 3 Modern Tabbed Shell

**Feature**: `001-winui3-chrome-tabs` | **Date**: 2026-10-19

This document records the architectural investigations, technology evaluations, and design decisions for migrating DataSphere to a WinUI 3 multi-window tabbed shell with browser-style Chrome tabs.

---

## 1. UI Framework: Windows App SDK (WinUI 3) vs WPF

### Decision
Migrate the presentation shell from WPF (`Wpf.Ui`) to **Windows App SDK (WinUI 3)** targeting .NET 10 (`net10.0-windows10.0.19041.0` unpackaged).

### Rationale
- WinUI 3 provides first-class support for native modern Windows desktop controls, Mica/Acrylic material backdrops, and advanced windowing APIs (`AppWindow`, `OverlappedPresenter`).
- WinUI 3 features a battle-tested, high-performance native `TabView` control specifically engineered for browser-style tabs (as seen in Windows Terminal, Microsoft Edge, and Dev Home).
- Full compatibility with `CommunityToolkit.Mvvm` and standard dependency injection without requiring heavy legacy WPF shims.

### Alternatives Considered
- *Retaining WPF with custom tab tear-off controls*: WPF lacks built-in fluid drag-and-drop tear-off controls. Implementing tear-off in WPF requires low-level Win32 hook hacking (`WM_NCHITTEST`, `SetWindowLongPtr`, `BitBlt` window cloning) which is brittle and prone to visual stuttering and high-DPI scaling artifacts.
- *MAUI for Windows*: MAUI adds unnecessary cross-platform abstraction overhead, lacks fine-grained multi-window tab strip controls, and does not fit high-performance desktop database management tools.

---

## 2. Browser-Style Chrome Tab Strip & Custom TitleBar

### Decision
Implement the window header using WinUI 3's native `Microsoft.UI.Xaml.Controls.TabView` with `ExtendsContentIntoTitleBar = true` and `AppWindow.TitleBar`.

### Rationale
- Setting `ExtendsContentIntoTitleBar = true` allows the `TabView` tab strip to sit directly within the window caption area, creating the exact modern browser/Chrome aesthetic requested.
- Standard Windows caption controls (Minimize, Maximize/Restore, Close) are automatically rendered on the top right by `AppWindow`, preserving native snap layouts and window manager integrations.
- `TabView.TabStripHeader` and `TabView.TabStripFooter` allow seamless placement of app branding, search bars, and global action buttons beside the tabs.

### Alternatives Considered
- *Custom Win32 borderless window with manual caption buttons*: Re-inventing caption buttons leads to poor accessibility, broken Windows 11 snap flyouts, and inconsistent theme rendering. Using WinUI 3's built-in titlebar extension is the recommended Windows standard.

---

## 3. Tab Tear-Off & Cross-Window Re-Docking

### Decision
Leverage `TabView.CanDragTabs = true`, `TabDragStarting`, `TabDroppedOutside`, and `TabStripDrop` events, coordinated via an in-memory `IWindowManager` service.

### Rationale
- WinUI 3's `TabView` natively manages interactive horizontal reordering and tab drag visual feedback.
- When a user drags a tab outside the window boundary, the `TabDroppedOutside` event fires with screen coordinates (`args.DropPosition`). The `IWindowManager` catches this event, spawns a new `ShellWindow`, adds the dragged tab model to the new window's tab collection, and calls `newWindow.Activate()`.
- When a tab is dragged over another window's tab strip, `TabStripDragOver` and `TabStripDrop` handle docking the tab into the destination collection at the hover index.

### Alternatives Considered
- *Cross-Process Shared Memory / IPC for Drag-and-Drop*: Creating full independent operating system processes for each torn-off tab complicates state synchronization, database connection sharing, and memory overhead. Using a multi-window single-process model for torn-off windows within the same user session provides instant 60 FPS transitions while still allowing multiple independent processes to be launched when desired.

---

## 4. Multi-Instance Concurrency vs Single-Instance Mutex

### Decision
Remove the blocking single-instance mutex check in `Bootstrap.cs` to allow both:
1. Multiple top-level windows within the same application process (via tab tear-off and New Window shortcuts).
2. Multiple independent operating system processes (multi-instance) launched from the taskbar, Start Menu, or terminal.

### Rationale
- The user explicitly requested: *"cho phép có nhiều phiên DataSphere mở cùng lúc"* (allow multiple DataSphere sessions to be open simultaneously).
- Database developers frequently need to run parallel sessions connected to different environments (e.g. Production vs Staging vs Localhost) without cross-contamination.

### Alternatives Considered
- *Strict single-instance with IPC window activation*: Forces all user activity into a single process. While this simplifies IPC, it prevents developers from running separate isolated profiles or elevated instances. Removing the hard lock satisfies the user requirement completely.

---

## 5. Permanent Home Tab & Dynamic Navigation

### Decision
- The "Home" tab is initialized with `IsClosable = false` and pinned at index 0 in every window.
- When the user clicks "Cơ sở dữ liệu" or "Cài Đặt" from the Home dashboard, an `OpenTabMessage` is published via `CommunityToolkit.Mvvm.Messaging.WeakReferenceMessenger`, prompting the parent window's `ShellViewModel` to add and select the requested content tab.

### Rationale
- `TabViewItem.IsClosable = false` completely hides the close button (`X`) and suppresses close gestures for the Home tab.
- Decoupling navigation cards from window instances via `WeakReferenceMessenger` or `ITabService` preserves Clean MVVM and ensures ViewModels remain UI-agnostic per Principle I of the Constitution.

### Alternatives Considered
- *Direct method calls from DashboardViewModel to Window*: Violates Clean MVVM by creating tight coupling between child pages and their parent window container.

---

## 6. Donor Window Auto-Closure Invariant

### Decision
Implement the auto-closure rule in `IWindowManager.OnTabTransferred`:
- Before transfer, check the donor window's tabs.
- If the donor window contains exactly 2 tabs (`Home` + `ContentTab`), and `ContentTab` is dragged out and docked into another window, the donor window is left with only the idle Home tab. The donor window immediately invokes `Close()` and is removed from the active window registry.

### Rationale
- Exactly implements the user requirement: *"trong trường hợp chỉ có 2 tab duy nhất (1 home và 1 settings hoặc 1 trang cơ sở dữ liệu) thì sẽ đóng luôn cửa sổ được kéo sang cửa sổ khác"*.
- Prevents desktop clutter from leftover empty shell windows after a user reorganizes tabs.

---

## 7. Migration Mapping: WPF to WinUI 3

| Existing WPF / Wpf.Ui Component | WinUI 3 Target Component | Notes |
|---|---|---|
| `ui:FluentWindow` | `Microsoft.UI.Xaml.Window` + `AppWindow` | Extends content into titlebar |
| `ui:NavigationView` | `Microsoft.UI.Xaml.Controls.TabView` | Replaced completely by tab strip |
| `ui:TitleBar` | `TabView` embedded in titlebar | Titlebar integrated with tabs |
| `System.Windows.Controls.Page` | `Microsoft.UI.Xaml.Controls.Page` | Direct namespace migration |
| `System.Windows.Threading.Dispatcher` | `Microsoft.UI.Dispatching.DispatcherQueue` | UI thread dispatching |
| `Wpf.Ui.Controls.CardAction` | `CommunityToolkit.WinUI.Controls.SettingsCard` or custom card | Preserves Dashboard card style |
| `System.Windows.Data.IValueConverter` | `Microsoft.UI.Xaml.Data.IValueConverter` | Standard XAML binding converter |
