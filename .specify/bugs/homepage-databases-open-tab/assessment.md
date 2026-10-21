# Bug Assessment: HomePage Databases Button Reuses Existing Tab Instead of Creating New Tab

- **Slug**: homepage-databases-open-tab
- **Created**: 2026-10-21T16:51:00+07:00
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

> "có vấn đề 1 chút ở hành vi của nút cơ sở dữ liệu (Databases) ủa HomePage khi tôi nhấn lần đầu nó mở cửa sổ mới nhưng từ lần nhấn tiếp theo nó chỉ mở đến cửa sổ mà tôi làm việc, giúp tôi thay đổi hành vi của nó sang mỗi lần nhấn thì đều tạo tab mới"

## Symptom

When the user clicks the "Cơ sở dữ liệu" (Databases) card button on `HomePage`, the first click successfully opens a new Database workspace tab. However, clicking the button again on subsequent visits only switches focus to the existing Database tab instead of spawning a new independent tab workspace. The expected behavior is that every click on the Databases button creates a new, independent Database tab.

## Diagnostic Reproduction (Principle VIII)

- **Test Script**: `scripts/reproduce-database-tab-creation.ps1` executed on real desktop session `WinSta0\default`.
- **Observed Behavior**:
  1. Initial state: 1 tab (`Trang chủ`).
  2. 1st click on Databases card: Top-level tabs count becomes 2 (`Trang chủ`, `Cơ sở dữ liệu`).
  3. Switch back to `Trang chủ`.
  4. 2nd click on Databases card: Top-level tabs count remains 2 (`Trang chủ`, `Cơ sở dữ liệu`). No new tab is instantiated; focus simply transfers to the existing tab.
- **Diagnostic Visual Evidence**:
  - DirectComposition capture: `winui_pill_tabview_verified.png` and `diagnose_database_tab_reuse.png`

![Tái hiện lỗi: Tab Cơ sở dữ liệu bị tái sử dụng thay vì tạo tab mới](/C:/Users/huynh/.gemini/antigravity/brain/2d13470a-f666-47af-ac01-be17bda1e363/diagnose_database_tab_reuse.png)

## Suspected Code Paths

1. **`DataSphere/Services/TabService.cs:51-65`**:
   ```csharp
   // Check if a tab of this type is already open (e.g. Home or Settings)
   var existingTab = Tabs.FirstOrDefault(t => t.PageType == pageType);
   if (existingTab != null && (existingTab.PageType?.Name == "HomePage" || !existingTab.IsClosable))
   {
       SelectedTab = existingTab;
       existingTab.State = TabLifecycleState.Active;
       return existingTab;
   }

   // If it's a singleton-style settings page, focus existing if found
   if (existingTab != null && (existingTab.TitleKey == titleKey || existingTab.Title == LanguageBase.GetLangValue(titleKey)))
   {
       SelectedTab = existingTab;
       existingTab.State = TabLifecycleState.Active;
       return existingTab;
   }
   ```
   `TabService.OpenTab` matches *any* tab with the same `pageType` and `titleKey`. Because `DatabasePage` has `titleKey = "page_db_title"`, line 60 unconditionally matches the first opened `DatabasePage` tab and returns it, preventing subsequent tabs from ever being created.

2. **`DataSphere/Services/Contracts/ITabService.cs:30`**:
   `ITabService.OpenTab` signature currently does not offer a `forceNewTab` parameter or explicit distinction between singleton pages (e.g., `HomePage`, `SettingsPage`) and multi-instance workspace pages (e.g., `DatabasePage`).

3. **`DataSphere/ViewModels/Pages/HomeViewModel.cs:81-85`**:
   ```csharp
   [RelayCommand]
   public void OpenDatabase()
   {
       _tabService.OpenTab(typeof(DatabasePage), "page_db_title", "\uE774");
   }
   ```
   `OpenDatabase` delegates directly to `_tabService.OpenTab` without signaling that a new workspace instance must be created on each invocation.

## Root Cause Hypothesis

`TabService.OpenTab` was originally implemented with broad singleton matching logic: if any tab in the active `Tabs` collection shares the same `pageType` and matching `titleKey` or `Title`, `TabService` activates the existing tab instead of instantiating a new one. While this behavior is appropriate for singleton settings or home dashboards, `DatabasePage` represents an interactive database session workspace where users need multiple independent tabs concurrently. Because `OpenTab` lacked a `forceNewTab` parameter and did not restrict singleton reuse to explicitly marked singleton pages (`HomePage`, `SettingsPage`), subsequent clicks on `OpenDatabase` were intercepted by the singleton check and suppressed.

- **Confidence**: High (100% verified via code inspection and live UI automation reproduction).

## Proposed Remediation

### Preferred Solution:
1. **Extend `ITabService.OpenTab`** with an optional parameter `bool forceNewTab = false`:
   ```csharp
   TabItemModel OpenTab(Type pageType, string titleKey, string iconGlyph, object? parameter = null, bool forceNewTab = false);
   ```
2. **Refactor Singleton Matching in `TabService.OpenTab`**:
   - Only reuse tabs if `!forceNewTab`.
   - Restrict automatic tab reuse to singleton page types (`HomePage`, `SettingsPage`).
   - For multi-instance pages (like `DatabasePage`), compute an incremental index title when multiple instances exist (e.g., `Cơ sở dữ liệu`, `Cơ sở dữ liệu (2)`, etc.) so that tabs are clearly distinguishable.
3. **Update `HomeViewModel.OpenDatabase`**:
   - Pass `forceNewTab: true` to `_tabService.OpenTab(typeof(DatabasePage), "page_db_title", "\uE774", forceNewTab: true)`.

### Alternative Solution:
- Expose a dedicated `CreateNewTab` method on `ITabService` alongside `OpenTab`.
  *Trade-off*: Adds method redundancy when an optional `forceNewTab` parameter on `OpenTab` is backward-compatible with existing callers.

## Files likely to change:
- `DataSphere/Services/Contracts/ITabService.cs`
- `DataSphere/Services/TabService.cs`
- `DataSphere/ViewModels/Pages/HomeViewModel.cs`

## Tests to add or update:
- Live UI Automation verification script (`scripts/verify-database-tab-creation.ps1`):
  1. Click Databases card button -> 1st Database tab created.
  2. Switch to Home tab.
  3. Click Databases card button -> 2nd Database tab created.
  4. Switch to Home tab.
  5. Click Databases card button -> 3rd Database tab created.
  6. Confirm total top-level tabs count = 4 (`Trang chủ` + 3 `Cơ sở dữ liệu` tabs).
  7. Confirm closing one tab leaves others unaffected.
  8. Capture DirectComposition screenshot evidence.

## Risks & Considerations
- **Memory & Resource Stewardship**: Each `DatabasePage` hosts a `ConnectControlViewModel` / treeview. Ensure closing each tab properly calls `IDisposable` clean-up (already handled in `TabService.CloseTab`).
- **Tab Title Formatting**: Ensure localized tab title updates when switching languages seamlessly format with the optional instance number suffix without breaking `TranslationSource`.

## Open Questions
- None. Requirements and expected behavior are fully specified by the user and verified in code.
