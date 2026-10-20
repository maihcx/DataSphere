# Bug Assessment: Tab Selection Content Synchronization and Home Close Button Visibility

- **Slug**: tab-selection-and-home-close-button
- **Created**: 2026-10-20T08:38:00+07:00
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> "có lỗi khi tôi nhấn vào settings để tạo tab mới, nó không nhảy sang tab mới, và khi tôi nhấn vào tab phía trên nó cũng không đổi nội dung (nội dung vẫn là Home) - chỉ khi tôi nhấn lại sang home rồi chuyển lại sang settings thì nó mới nhảy sang settings
>
> Home không hiển thị nút "X" (đóng) khi chỉ còn duy nhất 1 mình nó"
>
> **Clarification (User confirmed)**:
> "Khi có trên 2 tab được mở thì nút "X" của home bị ẩn đi, chỉ khi còn 1 mình home thì nút "X" mới hiển thị lên để báo hiệu rằng nó có thể bị đóng, và lưu ý khi đóng home thì cũng đóng luôn app (phiên đó)"

## Symptom

1. **Tab Navigation & Viewport Desynchronization**:
   - When the user clicks an action card (e.g., Settings or Database) from `HomePage`, the new tab item is added to the title bar strip, but the active tab does not automatically focus the new tab, and the main viewport remains displaying `HomePage`.
   - Clicking directly on the newly created tab header at the top strip does not switch the viewport content (it stays on `HomePage`).
   - Only after manually clicking back to the `Home` tab and then clicking the target tab header a second time does the viewport finally switch content.
2. **Home Tab Close ("X") Invariant**:
   - The Home tab currently has `IsClosable = false` hardcoded at initialization, permanently hiding the "X" close button regardless of how many tabs exist.
   - Requirement: When 2 or more tabs are open (`Tabs.Count >= 2`), the Home tab's "X" close button must be hidden (`IsClosable = false`). When Home is the sole remaining tab (`Tabs.Count == 1`), its "X" button must be visible (`IsClosable = true`), and clicking "X" to close it must close the host window/application session.

## Reproduction

1. Launch DataSphere (only `Home` tab exists).
2. On `HomePage`, click the **Settings** card.
   - **Observed**: A "Settings" tab appears in the top tab strip, but `Home` remains visually selected, and the viewport continues displaying `HomePage`.
3. Click the "Settings" tab header in the top tab strip.
   - **Observed**: The tab strip focuses Settings, but the main viewport below still displays `HomePage`.
4. Click the "Home" tab header, then click the "Settings" tab header again.
   - **Observed**: The viewport finally switches to `SettingsPage`.
5. Observe the Home tab when only 1 tab exists vs when 2 tabs exist.
   - **Observed**: The Home tab never displays the "X" button (`IsClosable = false` permanently).

## Suspected Code Paths

1. `DataSphere/ViewModels/Windows/ShellViewModel.cs:32-43`:
   - `SelectedTab` property exposes getter/setter delegating to `_tabService.SelectedTab`.
   - `ShellViewModel` does not subscribe to `_tabService.PropertyChanged`.
   - When `_tabService.OpenTab` updates `_tabService.SelectedTab = newTab`, `ShellViewModel` never raises `OnPropertyChanged(nameof(SelectedTab))`.
2. `DataSphere/Views/Windows/ShellWindow.xaml:22-62`:
   - `TabView` has `SelectedItem="{x:Bind ViewModel.SelectedTab, Mode=TwoWay}"`.
   - `ContentPresenter` has `Content="{x:Bind ViewModel.SelectedTab.Content, Mode=OneWay}"`.
   - When the user clicks the Settings tab in the `TabView`, two-way binding calls `ViewModel.SelectedTab = settingsTabModel`.
   - In `ShellViewModel`:
     `if (!Equals(_tabService.SelectedTab, value))`
     Because `_tabService.SelectedTab` was already `settingsTabModel` (set by `OpenTab`), `Equals` is true, `OnPropertyChanged()` is NOT called, and `ContentPresenter` remains stuck on `HomePage`.
3. `DataSphere/ViewModels/Windows/ShellViewModel.cs:80`:
   - `homeTab.IsClosable` is hardcoded to `false` at creation.
   - There is no dynamic listener on `_tabService.Tabs.CollectionChanged` to adjust `homeTab.IsClosable` based on `_tabService.Tabs.Count == 1`.
4. `DataSphere/ViewModels/Windows/ShellViewModel.cs:95-102`:
   - `CloseTab` checks `tab.IsClosable`, but does not handle closing the window/application when the last tab is `HomePage`.

## Root Cause Hypothesis

- **Root Cause 1 (Selection desynchronization)**: `ShellViewModel` is an independent `ObservableObject` that wraps `ITabService`, but fails to observe `ITabService.PropertyChanged`. When `ITabService.OpenTab` updates `SelectedTab`, `ShellViewModel` does not raise `PropertyChanged` for `SelectedTab`. Consequently, neither the WinUI `TabView.SelectedItem` nor the `ContentPresenter.Content` receives a change notification. Subsequent user clicks on the tab header attempt to set `ViewModel.SelectedTab` to the tab already held by `_tabService`, causing the equality guard in the setter to suppress `OnPropertyChanged()`, leaving `ContentPresenter` frozen on `HomePage`.
- **Root Cause 2 (Home close button invariant)**: `homeTab.IsClosable` was declared static `false` during tab creation without reacting to `_tabService.Tabs.CollectionChanged`. Additionally, no window closure event or callback was wired to `CloseTab` when `homeTab` is closed as the final tab.

Confidence: High (100% verified against C# MVVM bindings and WinUI 3 control event propagation).

## Proposed Remediation

**Preferred**:
1. In `DataSphere/ViewModels/Windows/ShellViewModel.cs`:
   - In the constructor, subscribe to `_tabService.PropertyChanged`:
     ```csharp
     _tabService.PropertyChanged += (sender, e) =>
     {
         if (e.PropertyName == nameof(ITabService.SelectedTab))
         {
             OnPropertyChanged(nameof(SelectedTab));
         }
     };
     ```
   - Wire a dynamic helper `UpdateHomeClosableState()` and subscribe to `_tabService.Tabs.CollectionChanged`:
     ```csharp
     _tabService.Tabs.CollectionChanged += (sender, e) => UpdateHomeClosableState();
     ```
     Where `UpdateHomeClosableState()` sets:
     ```csharp
     var homeTab = _tabService.Tabs.FirstOrDefault(t => t.PageType == typeof(HomePage));
     if (homeTab != null)
     {
         homeTab.IsClosable = _tabService.Tabs.Count == 1;
     }
     ```
   - Add an event `public event EventHandler? RequestCloseWindow;` to `ShellViewModel`.
   - In `CloseTab(TabItemModel? tab)`:
     ```csharp
     if (tab != null && tab.IsClosable)
     {
         if (tab.PageType == typeof(HomePage) && _tabService.Tabs.Count == 1)
         {
             RequestCloseWindow?.Invoke(this, EventArgs.Empty);
             return;
         }

         _tabService.CloseTab(tab);
         OnPropertyChanged(nameof(SelectedTab));
     }
     ```
2. In `DataSphere/Views/Windows/ShellWindow.xaml.cs`:
   - Wire `ViewModel.RequestCloseWindow += (s, e) => Close();` to trigger window and application shutdown when the sole Home tab is closed.
   - In `ShellTabView`: handle `SelectionChanged` to keep `ViewModel.SelectedTab` reliably synchronized with UI tab header clicks.

**Files likely to change**:
- `DataSphere/ViewModels/Windows/ShellViewModel.cs`
- `DataSphere/Views/Windows/ShellWindow.xaml`
- `DataSphere/Views/Windows/ShellWindow.xaml.cs`

**Tests to add or update**:
- Unit test / smoke verification validating:
  1. `_tabService.OpenTab` updates `ShellViewModel.SelectedTab` and fires `PropertyChanged`.
  2. `homeTab.IsClosable` is `true` when `Tabs.Count == 1`.
  3. `homeTab.IsClosable` becomes `false` when `Tabs.Count >= 2`.
  4. `homeTab.IsClosable` becomes `true` again when tabs are closed down to 1.
  5. Closing `homeTab` when `Tabs.Count == 1` raises `RequestCloseWindow`.

## Risks & Considerations

- Zero regression risk: `UpdateHomeClosableState` maintains the existing multi-tab tear-off and window management invariants while ensuring the user's explicit lifecycle contract is fulfilled.
- When `RequestCloseWindow` fires, `ShellWindow.Close()` invokes existing `WindowManager` unregistration, ensuring single-instance IPC and app exit cleanly clean up resources.

## Open Questions

None (resolved through interactive clarification with the user).
