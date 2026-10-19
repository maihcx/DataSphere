# Service Contract: ITabService (Localized Tab Navigation)

**Feature**: `002-dynamic-i18n-localization` | **Date**: 2026-10-19

This document defines the interface contract for tab creation, dynamic title management, and language synchronization.

---

## 1. Interface Definition: `ITabService`

```csharp
namespace DataSphere.Services.Contracts
{
    /// <summary>
    /// Service responsible for managing tabbed navigation, dynamic localization, and tab lifecycle inside a window shell.
    /// </summary>
    public interface ITabService
    {
        /// <summary>
        /// Gets the observable collection of tabs active in the current window.
        /// </summary>
        ObservableCollection<TabItemModel> Tabs { get; }

        /// <summary>
        /// Gets or sets the currently selected and active tab.
        /// </summary>
        TabItemModel? SelectedTab { get; set; }

        /// <summary>
        /// Opens a new tab or switches to an existing tab of the specified page type, resolving title dynamically via a localization key.
        /// </summary>
        /// <param name="pageType">The concrete Type of the page to host.</param>
        /// <param name="titleKey">The localization resource key (e.g. "page_db_title", "page_settings_title").</param>
        /// <param name="iconGlyph">Fluent icon glyph code for the tab header.</param>
        /// <param name="parameter">Optional navigation parameter passed to the ViewModel.</param>
        /// <returns>The opened or focused TabItemModel instance.</returns>
        TabItemModel OpenTab(Type pageType, string titleKey, string iconGlyph, object? parameter = null);

        /// <summary>
        /// Requests closing of the specified tab.
        /// </summary>
        /// <param name="tab">The tab to close.</param>
        /// <returns><c>true</c> if the tab was closed successfully; otherwise <c>false</c> if closure was cancelled or forbidden.</returns>
        bool CloseTab(TabItemModel tab);

        /// <summary>
        /// Selects the tab at the specified zero-based index.
        /// </summary>
        /// <param name="index">Zero-based tab index.</param>
        void SelectTab(int index);
    }
}
```

---

## 2. Invariants & Guarantees

1. **TitleKey Persistence**: When `OpenTab` is invoked with `titleKey`, the returned `TabItemModel` MUST retain `TitleKey = titleKey`.
2. **Initial Localization**: The initial `Title` MUST be populated via `LanguageBase.GetLangValue(titleKey)`.
3. **Dynamic Re-localization**: Whenever `TranslationSource.Instance.PropertyChanged` fires, `TabItemModel` MUST re-evaluate `Title` using `LanguageBase.GetLangValue(TitleKey)` without requiring explicit caller intervention.
4. **Uncloseable Home Tab Guarantee**: When the Home tab is initialized in `ShellViewModel`, it MUST use `titleKey = "page_home_title"`, ensuring the Home tab header dynamically translates to "Trang chủ" in Vietnamese and "Home" in English.
