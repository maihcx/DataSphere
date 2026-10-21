# Research: VirtualTable MVVM Command & Data Binding Architecture

- **Feature**: `009-virtual-table-mvvm-binding`
- **Date**: 2026-10-21
- **Focus**: Decoupled MVVM Command Binding, Clean Code-Behind Elimination, and Reusable Control Architecture for WinUI 3.

---

## 1. Problem Space & Current Limitations

### 1.1 The Code-Behind Antipattern in `DataViewControl.xaml.cs`
In the current implementation:
- `DataViewControl.xaml.cs` spans 208 lines.
- It contains a private nested class `TableDataPageAdapter` (78 lines) implementing `IVirtualTableDataProvider`.
- It registers an event handler for `ViewModel.PropertyChanged` to manually trigger `UpdateTableDataSource()`, dispatching to `DispatcherQueue.TryEnqueue()`.
- It wires up UI event handlers `OnVirtualTableSorting` and `OnVirtualTableCellEdited`, extracting metadata and routing actions to `ViewModel.SortByServerColumnAsync` and `ViewModel.NotifyDirtyStateChanged()`.

### 1.2 Architectural Incompatibilities with Clean MVVM
According to **Constitution Principle I (Clean MVVM & Type Safety)**:
> *"Views (Views/Pages/, Views/Windows/, Dialogs/Views/): Khai báo giao diện thuần XAML, không chứa logic nghiệp vụ (No Code-Behind Business Logic)."*
> *"Zero Business Logic in Code-Behind: Views (*.xaml.cs) MUST NOT contain business, database, or domain orchestration logic. Code-behind is strictly restricted to view-only lifecycle plumbing."*

`DataViewControl.xaml.cs` violates this by:
1. Acting as an intermediary controller between the View and ViewModel.
2. Managing the lifecycle of data adapters (`TableDataPageAdapter`).
3. Performing metadata lookups on columns (`ViewModel.DataPage.Columns[i].Name == e.Column.Header`).

### 1.3 Control Reusability & Library Isolation
`VirtualTable` currently forces consumers to wire C# events (`Sorting`, `CellEdited`) in code-behind. Standard WinUI 3 controls (e.g. `Button.Command`, `ListView.ItemClickCommand`, `AutoSuggestBox.QuerySubmitted`) support `ICommand` binding so that ViewModels can handle actions directly in XAML via `{x:Bind}`.

---

## 2. Technical Solution Architecture

### 2.1 Exposing DependencyProperties on `VirtualTable`
Add standard `ICommand` DependencyProperties to `VirtualTable`:
```csharp
public static readonly DependencyProperty SortCommandProperty =
    DependencyProperty.Register(
        nameof(SortCommand),
        typeof(ICommand),
        typeof(VirtualTable),
        new PropertyMetadata(null));

public static readonly DependencyProperty SortCommandParameterProperty =
    DependencyProperty.Register(
        nameof(SortCommandParameter),
        typeof(object),
        typeof(VirtualTable),
        new PropertyMetadata(null));

public static readonly DependencyProperty CellEditedCommandProperty =
    DependencyProperty.Register(
        nameof(CellEditedCommand),
        typeof(ICommand),
        typeof(VirtualTable),
        new PropertyMetadata(null));

public static readonly DependencyProperty CellEditedCommandParameterProperty =
    DependencyProperty.Register(
        nameof(CellEditedCommandParameter),
        typeof(object),
        typeof(VirtualTable),
        new PropertyMetadata(null));
```

### 2.2 Dual Event & Command Dispatching Semantics
In `OnHeaderClicked(int colIndex)`:
```csharp
var args = new VirtualTableSortEventArgs(col, nextDir);
Sorting?.Invoke(this, args);

var param = SortCommandParameter ?? args;
if (SortCommand != null && SortCommand.CanExecute(param))
{
    SortCommand.Execute(param);
}
```

In `CommitCellEdit()`:
```csharp
var args = new VirtualTableCellEditEventArgs(r, c, original, updated);
CellEdited?.Invoke(this, args);

var param = CellEditedCommandParameter ?? args;
if (CellEditedCommand != null && CellEditedCommand.CanExecute(param))
{
    CellEditedCommand.Execute(param);
}
```
**Benefits**:
- 100% backward compatibility: existing event subscribers (`Sorting`, `CellEdited`) continue working without disruption.
- Declarative MVVM: modern views can bind `SortCommand="{x:Bind ViewModel.SortCommand}"` directly.

### 2.3 Refactoring `TableDataPageAdapter` to the ViewModel/Model Layer
Move `TableDataPageAdapter` from `DataViewControl.xaml.cs` to a public or internal class in `DataSphere.Models.Database` or `DataSphere.ViewModels.Pages.DatabaseGroup`:
- `DataControlViewModel` manages `TableDataProvider` as an `[ObservableProperty]`:
  ```csharp
  [ObservableProperty]
  private IVirtualTableDataProvider? _tableDataProvider;
  ```
- Whenever `DataPage` is loaded or `HasPrimaryKeys` changes in `DataControlViewModel`, it updates `TableDataProvider = new TableDataPageAdapter(DataPage, HasPrimaryKeys, ActiveSort)`.
- `DataViewControl.xaml` simply binds:
  ```xml
  <vt:VirtualTable
      RowHeight="34"
      DataProvider="{x:Bind ViewModel.TableDataProvider, Mode=OneWay}"
      SortCommand="{x:Bind ViewModel.SortCommand, Mode=OneWay}"
      CellEditedCommand="{x:Bind ViewModel.CellEditedCommand, Mode=OneWay}" />
  ```

### 2.4 Strongly Typed ViewModel Commands
In `DataControlViewModel.cs`:
```csharp
[RelayCommand]
private async Task SortAsync(VirtualTableSortEventArgs? e)
{
    if (e == null || DataPage?.Columns == null) return;
    int colIndex = -1;
    for (int i = 0; i < DataPage.Columns.Count; i++)
    {
        if (string.Equals(DataPage.Columns[i].Name, e.Column.Header, StringComparison.Ordinal))
        {
            colIndex = i;
            break;
        }
    }
    if (colIndex < 0) return;
    var colMetadata = DataPage.Columns[colIndex];
    await SortByServerColumnAsync(colIndex, e.Direction, colMetadata.Name, colMetadata.DataType);
}

[RelayCommand]
private void CellEdited(VirtualTableCellEditEventArgs? e)
{
    NotifyDirtyStateChanged();
}
```

### 2.5 Resulting Code-Behind in `DataViewControl.xaml.cs`
`DataViewControl.xaml.cs` is reduced to:
```csharp
namespace DataSphere.Views.Pages.DatabaseGroup
{
    /// <summary>
    /// UserControl presenting a modern, high-performance database table data viewport.
    /// </summary>
    public sealed partial class DataViewControl : UserControl, IDisposable
    {
        /// <summary>
        /// Gets the ViewModel driving the table data viewport.
        /// </summary>
        public DataControlViewModel ViewModel { get; }

        /// <summary>
        /// Initializes a new instance of the <see cref="DataViewControl"/> class.
        /// </summary>
        public DataViewControl(IDatabaseConnection connection, DatabaseInfo database, Table table)
        {
            ViewModel = new DataControlViewModel(connection, database, table);
            InitializeComponent();
        }

        /// <inheritdoc/>
        public void Dispose()
        {
            ViewModel.Dispose();
        }
    }
}
```
Footprint drops from **208 lines** to **~30 lines**!
Zero event handlers, zero `PropertyChanged` listeners, zero UI thread marshaling.

---

## 3. Risk & Impact Analysis

| Risk | Impact | Mitigation Strategy |
|------|--------|---------------------|
| Breaking existing event consumers | Low | Dual dispatching: invoke events FIRST, then check and execute `ICommand`. |
| Null parameters in command binding | Low | Default to event args instance if `CommandParameter` is null. |
| Threading during adapter instantiation | Low | ViewModel properties are created on background/UI threads and dispatched via `CommunityToolkit.Mvvm` observable properties. |
| Library extraction readiness | None | `VirtualTable` remains strictly in `DataSphere.Controls.VirtualTable` referencing only standard WinUI 3 and system assemblies. |
