# Contract: `ITabService`

**Namespace**: `DataSphere.Services.Contracts`

`ITabService` manages tab creation, selection, close requests, and state transitions within a `WindowSession`.

---

## Interface Definition

```csharp
namespace DataSphere.Services.Contracts
{
    /// <summary>
    /// Service responsible for managing tabbed navigation and tab lifecycle inside a window shell.
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
        /// Opens a new tab of the specified page type or switches to an existing tab.
        /// </summary>
        /// <param name="pageType">The concrete Type of the page to host.</param>
        /// <param name="title">Display title for the tab.</param>
        /// <param name="iconGlyph">Fluent icon glyph for the tab.</param>
        /// <param name="parameter">Optional navigation parameter passed to the ViewModel.</param>
        /// <returns>The opened or focused TabItemModel instance.</returns>
        TabItemModel OpenTab(Type pageType, string title, string iconGlyph, object? parameter = null);

        /// <summary>
        /// Requests closing of the specified tab.
        /// </summary>
        /// <param name="tab">The tab to close.</param>
        /// <returns>True if the tab was closed successfully; false if closure was cancelled or forbidden.</returns>
        bool CloseTab(TabItemModel tab);

        /// <summary>
        /// Selects the tab at the specified index.
        /// </summary>
        /// <param name="index">Zero-based tab index.</param>
        void SelectTab(int index);
    }
}
```

---

## Contract Guarantees

1. `OpenTab` will never duplicate the `Home` tab. If `pageType == typeof(HomePage)`, it will always activate index 0.
2. `CloseTab` will return `false` and take no action if `tab.IsClosable == false` (e.g. `Home` tab).
3. If an open tab is closed, focus automatically transitions to the immediate preceding tab index.
