# Data Model & State Architecture: Anchored Connection Tab in TabStripHeader & In-Page Tab Reordering

**Feature**: `014-database-tabstrip-header`
**Spec**: [spec.md](./spec.md)
**Research**: [research.md](./research.md)

---

## 1. Entity Models & ViewModels

### 1.1 `DatabaseViewModel` (State Machine)

The `DatabaseViewModel` coordinates the lifecycle, selection mutual exclusion, and tab collections inside `DatabasePage`:

```csharp
public partial class DatabaseViewModel : ObservableObject
{
    /// <summary>
    /// Gets the dedicated anchored tab item model for the Connection Catalog Explorer.
    /// Rendered inside InnerTabView.TabStripHeader.
    /// </summary>
    public InnerTabItemModel ConnectionTab { get; }

    /// <summary>
    /// Gets the observable collection of open dynamic workspace tabs (database sessions).
    /// Bound to InnerTabView.TabItemsSource with CanReorderTabs="True".
    /// </summary>
    public ObservableCollection<InnerTabItemModel> InnerTabs { get; } = new();

    /// <summary>
    /// Gets or sets a value indicating whether the anchored Connection tab in TabStripHeader is selected.
    /// Mutual exclusion: setting this to true deselects SelectedInnerTab.
    /// </summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(ActiveInnerContent))]
    private bool _isConnectionSelected = true;

    /// <summary>
    /// Gets or sets the currently selected dynamic database tab, or null if Connection is active.
    /// Mutual exclusion: setting this to a non-null tab sets IsConnectionSelected to false.
    /// </summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(ActiveInnerContent))]
    private InnerTabItemModel? _selectedInnerTab;

    /// <summary>
    /// Gets the active content for the viewport ContentControl.
    /// Resolves to ConnectionTab.Content when IsConnectionSelected is true,
    /// otherwise SelectedInnerTab.Content.
    /// </summary>
    public object? ActiveInnerContent => IsConnectionSelected ? ConnectionTab.Content : SelectedInnerTab?.Content;

    /// <summary>
    /// Command to explicitly activate the anchored Connection tab.
    /// </summary>
    [RelayCommand]
    public void SelectConnection();

    /// <summary>
    /// Opens or activates a database connection tab.
    /// </summary>
    public void OpenConnectionTab(ConnectionModel connection);

    /// <summary>
    /// Closes a dynamic tab and disposes its connection resources.
    /// </summary>
    public void CloseTab(InnerTabItemModel tab);
}
```

### 1.2 `InnerTabItemModel` (Tab Data Entity)

```csharp
public partial class InnerTabItemModel : ObservableObject
{
    [ObservableProperty]
    private string _header = string.Empty;

    [ObservableProperty]
    private string _iconGlyph = "\uE703"; // Default or assigned glyph

    public object? Content { get; init; }

    public bool IsClosable { get; init; } = true;

    public string? ConnectionKey { get; init; }

    public IDisposable? DisposableContext { get; init; }
}
```

---

## 2. Selection State Transitions

```mermaid
stateDiagram-v2
    [*] --> ConnectionActive: DatabasePage Initialized

    state ConnectionActive {
        [*] --> RenderConnectionView
        note right of ConnectionActive
            IsConnectionSelected = true
            SelectedInnerTab = null
            ActiveInnerContent = ConnectViewControl
            ConnectionTab visually Selected
        end note
    }

    state DynamicTabActive {
        [*] --> RenderDatabaseView
        note right of DynamicTabActive
            IsConnectionSelected = false
            SelectedInnerTab = activeTab
            ActiveInnerContent = DatabaseViewControl
            Dynamic Tab visually Selected
        end note
    }

    ConnectionActive --> DynamicTabActive: OpenConnectionTab() / Click Dynamic Tab
    DynamicTabActive --> ConnectionActive: Click Connection Tab in TabStripHeader
    DynamicTabActive --> DynamicTabActive: Click Another Dynamic Tab / Reorder Tabs
    DynamicTabActive --> ConnectionActive: Close Last Dynamic Tab (InnerTabs.Count == 0)
    DynamicTabActive --> DynamicTabActive: Close Tab (Other Dynamic Tabs Remain)
```

---

## 3. Mutual Exclusion & Lifecycle Rules

| Trigger | `IsConnectionSelected` | `SelectedInnerTab` | `ActiveInnerContent` | Viewport State |
|---|---|---|---|---|
| Page Launched (0 dynamic tabs) | `true` | `null` | `ConnectionTab.Content` | Connection catalog explorer (`ConnectViewControl`) |
| Open 1st Database Connection | `false` | `newTab` | `newTab.Content` | Database session view (`DatabaseViewControl`) |
| Click Connection in Header | `true` | `null` | `ConnectionTab.Content` | Connection catalog explorer (`ConnectViewControl`) |
| Click Dynamic Tab | `false` | `clickedTab` | `clickedTab.Content` | Selected database view |
| Reorder Dynamic Tabs | `false` | `selectedTab` | `selectedTab.Content` | Remains on active database view; tab order updated |
| Close Non-Active Dynamic Tab | Unchanged | Unchanged | Unchanged | Viewport unchanged; tab removed from strip |
| Close Active Tab (others remain) | `false` | Adjacent Tab | Adjacent Tab Content | Switches to adjacent database session |
| Close Active Tab (none remain) | `true` | `null` | `ConnectionTab.Content` | Automatically falls back to Connection catalog explorer |
