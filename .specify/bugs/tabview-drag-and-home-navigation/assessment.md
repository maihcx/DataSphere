# Bug Assessment: TabView Title Bar Dragging and Home Dashboard Navigation Failure

- **Slug**: tabview-drag-and-home-navigation
- **Created**: 2026-10-19T17:00:00+07:00
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> "hiện tại thanh TabView ở trên app tôi không thể nhấn giữ chuột vào vùng trống để kéo thả thay đổi vị trí được nữa, hiện tại ở trang home khi tôi nhấn vào cũng không nhảy ra tab mới, nó hầu như không có phản ứng gì"

## Symptom

1. **Window Move / Drag Disabled**: Clicking and holding the mouse in the empty space of the `TabView` header strip does not move or reposition the application window.
2. **Home Navigation Buttons Non-Responsive**: Clicking "Cơ sở dữ liệu" or "Cài Đặt" action buttons on `HomePage` does not open or display new tabs.

## Reproduction

1. Launch DataSphere (`ShellWindow`).
2. Attempt to click and drag the window from the empty area to the right of the "Trang chủ" tab header. **Observed**: Window does not drag.
3. On the Home page, click on the "Cơ sở dữ liệu" card button. **Observed**: No new tab is opened in the window.

## Suspected Code Paths

1. `DataSphere/Views/Windows/ShellWindow.xaml.cs:44-47`: `ExtendsContentIntoTitleBar = true` is set, but `SetTitleBar(...)` is never called, and `TabView.TabStripFooter` does not define a custom drag region.
2. `DataSphere/Views/Windows/ShellWindow.xaml:22-47`: `TabView` lacks a `TabStripFooter` containing a hit-testable transparent `Grid` for window dragging.
3. `DataSphere/ViewModels/Windows/ShellViewModel.cs:66-86`: `InitializeHomeTab()` resolves `HomePage` via DI, which resolves `HomeViewModel(ITabService)`. Because `ITabService` is registered as `Transient` in DI, `HomeViewModel` receives a newly created, disconnected `TabService` instance rather than the host window's `ShellViewModel._tabService`.
4. `DataSphere/Services/WindowManager.cs:133`: `fe.DataContext is ViewModels.Windows.ShellViewModel` fails because `ShellWindow.DataContext` was not set, causing torn-off tabs to be added to `session.Tabs` instead of `sw.ViewModel.TabService.Tabs`.

## Root Cause Hypothesis

- **Root Cause 1 (Drag)**: WinUI 3 requires an explicit non-client drag element passed to `SetTitleBar(UIElement)` when `ExtendsContentIntoTitleBar = true`. Without `TabStripFooter` hosting a `CustomDragRegion` (`Grid` with `Background="Transparent"` and `MinWidth=188`), Windows receives no drag hit-tests from the tab strip. (Confidence: High)
- **Root Cause 2 (Home Navigation)**: `HomeViewModel` was injected with an orphaned `TabService` instance because `ITabService` is registered as `Transient` in DI, while `ShellViewModel` holds its own `TabService` instance. Clicking buttons on `HomePage` calls `_tabService.OpenTab(...)` on the orphan instance, leaving the active window's tab strip unchanged. (Confidence: High)

## Proposed Remediation

**Preferred**:
1. In `ShellWindow.xaml`: Add `<TabView.TabStripFooter><Grid x:Name="CustomDragRegion" Background="Transparent" MinWidth="188" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" /></TabView.TabStripFooter>`.
2. In `ShellWindow.xaml.cs`: Call `SetTitleBar(CustomDragRegion);` right after `ExtendsContentIntoTitleBar = true;`.
3. In `ShellViewModel.cs`: When creating the anchored `HomePage`, explicitly pass the window's `_tabService` into `new HomeViewModel(_tabService)` and `new HomePage(homeVm)`.
4. In `WindowManager.cs`: When tearing off tabs into `ShellWindow`, directly check `if (newWindow is ShellWindow sw)` and append to `sw.ViewModel.TabService.Tabs`.

**Files likely to change**:
- `DataSphere/Views/Windows/ShellWindow.xaml`
- `DataSphere/Views/Windows/ShellWindow.xaml.cs`
- `DataSphere/ViewModels/Windows/ShellViewModel.cs`
- `DataSphere/Services/WindowManager.cs`

**Tests to add or update**:
- Unit / build verification to ensure 0 compiler warnings/errors and clean execution.

## Risks & Considerations

- Ensure `CustomDragRegion` has `MinWidth = 188` to avoid encroaching upon the system Minimize/Maximize/Close caption button cluster.
- Ensure `HomeViewModel` preserves dynamic localization while using the window's `_tabService`.

## Open Questions

None.
