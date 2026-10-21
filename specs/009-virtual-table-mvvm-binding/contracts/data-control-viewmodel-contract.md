# Contract: DataControlViewModel & DataViewControl Binding Specification

- **ViewModel**: `DataSphere.ViewModels.Pages.DatabaseGroup.DataControlViewModel`
- **View**: `DataSphere.Views.Pages.DatabaseGroup.DataViewControl`

---

## 1. ViewModel Observable Properties

```csharp
/// <summary>
/// Gets the active virtual table data provider adapter.
/// Notifies on load, page change, or sort change.
/// </summary>
[ObservableProperty]
private IVirtualTableDataProvider? _tableDataProvider;
```

---

## 2. ViewModel Commands

```csharp
/// <summary>
/// Command executed when user triggers a column sort on the virtual table.
/// </summary>
[RelayCommand]
private async Task SortAsync(VirtualTableSortEventArgs? e);

/// <summary>
/// Command executed when user completes a cell modification in the virtual table.
/// </summary>
[RelayCommand]
private void CellEdited(VirtualTableCellEditEventArgs? e);
```

---

## 3. XAML Declarative Binding Specification

In `DataViewControl.xaml`:

```xml
<vt:VirtualTable
    Grid.Row="1"
    RowHeight="34"
    DataProvider="{x:Bind ViewModel.TableDataProvider, Mode=OneWay}"
    SortCommand="{x:Bind ViewModel.SortCommand, Mode=OneWay}"
    CellEditedCommand="{x:Bind ViewModel.CellEditedCommand, Mode=OneWay}" />
```

---

## 4. Code-Behind Contract (`DataViewControl.xaml.cs`)

Must contain **strictly zero**:
- Private event handlers (`OnVirtualTableSorting`, `OnVirtualTableCellEdited`).
- Property change subscriptions (`OnViewModelPropertyChanged`).
- UI thread enqueuing (`DispatcherQueue.TryEnqueue`).
- Nested adapter declarations (`TableDataPageAdapter`).

Only permitted members:
- `ViewModel` property getter.
- Constructor initializing `ViewModel` and calling `InitializeComponent()`.
- `Dispose()` method disposing `ViewModel`.
