# API Contract: VirtualTable Declarative Binding Interface

- **Namespace**: `DataSphere.Controls.VirtualTable`
- **Class**: `VirtualTable`

---

## 1. Public Dependency Properties

```csharp
public static readonly DependencyProperty DataProviderProperty;
public static readonly DependencyProperty RowHeightProperty;
public static readonly DependencyProperty SortCommandProperty;
public static readonly DependencyProperty SortCommandParameterProperty;
public static readonly DependencyProperty CellEditedCommandProperty;
public static readonly DependencyProperty CellEditedCommandParameterProperty;

public IVirtualTableDataProvider? DataProvider { get; set; }
public double RowHeight { get; set; }
public ICommand? SortCommand { get; set; }
public object? SortCommandParameter { get; set; }
public ICommand? CellEditedCommand { get; set; }
public object? CellEditedCommandParameter { get; set; }
```

---

## 2. Public Events (Backward Compatibility)

```csharp
public event EventHandler<VirtualTableSortEventArgs>? Sorting;
public event EventHandler<VirtualTableCellEditEventArgs>? CellEdited;
```

---

## 3. Command Execution Contract

### 3.1 Sorting Trigger Contract
1. When user clicks header $i$:
   - Check `Columns[i].CanSort`. If false, abort.
   - Cycle direction: `None -> Ascending -> Descending -> None`.
   - Instantiate `var args = new VirtualTableSortEventArgs(col, nextDir);`.
   - Invoke `Sorting?.Invoke(this, args);`.
   - Resolve parameter: `var p = SortCommandParameter ?? args;`.
   - If `SortCommand != null && SortCommand.CanExecute(p)`, invoke `SortCommand.Execute(p)`.

### 3.2 Cell Editing Trigger Contract
1. When user commits in-place edit at $(r, c)$ with modified value:
   - Instantiate `var args = new VirtualTableCellEditEventArgs(r, c, original, updated);`.
   - Update `DataProvider.SetCellText(r, c, updated);`.
   - Invoke `CellEdited?.Invoke(this, args);`.
   - Resolve parameter: `var p = CellEditedCommandParameter ?? args;`.
   - If `CellEditedCommand != null && CellEditedCommand.CanExecute(p)`, invoke `CellEditedCommand.Execute(p)`.
