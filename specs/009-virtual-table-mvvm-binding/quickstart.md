# Quickstart: Declarative MVVM VirtualTable Usage

This guide demonstrates how to consume `VirtualTable` in any WinUI 3 XAML view using pure MVVM binding with zero code-behind.

---

## 1. Implement `IVirtualTableDataProvider`

Create a data provider (or wrap an existing collection):

```csharp
public class MyCustomDataProvider : IVirtualTableDataProvider
{
    private readonly List<VirtualTableColumn> _columns;
    private readonly List<string[]> _data;

    public int RowCount => _data.Count;
    public IReadOnlyList<VirtualTableColumn> Columns => _columns;

    public string GetCellText(int r, int c) => _data[r][c];
    public void SetCellText(int r, int c, string val) => _data[r][c] = val;
    public bool IsCellEditable(int r, int c) => true;
}
```

---

## 2. Declare Properties & Commands in ViewModel

```csharp
public partial class MyPageViewModel : ObservableObject
{
    [ObservableProperty]
    private IVirtualTableDataProvider? _tableProvider;

    [RelayCommand]
    private void Sort(VirtualTableSortEventArgs e)
    {
        // Handle sorting directly in ViewModel
    }

    [RelayCommand]
    private void CellEdited(VirtualTableCellEditEventArgs e)
    {
        // Handle cell edits directly in ViewModel
    }
}
```

---

## 3. Declare `VirtualTable` in XAML

```xml
<UserControl
    x:Class="MyApp.MyPageView"
    xmlns:vt="using:DataSphere.Controls.VirtualTable">

    <vt:VirtualTable
        RowHeight="34"
        DataProvider="{x:Bind ViewModel.TableProvider, Mode=OneWay}"
        SortCommand="{x:Bind ViewModel.SortCommand, Mode=OneWay}"
        CellEditedCommand="{x:Bind ViewModel.CellEditedCommand, Mode=OneWay}" />
</UserControl>
```

---

## 4. Code-Behind (`MyPageView.xaml.cs`)

Pure view lifecycle — zero event handlers:

```csharp
public sealed partial class MyPageView : UserControl
{
    public MyPageViewModel ViewModel { get; }

    public MyPageView()
    {
        ViewModel = new MyPageViewModel();
        InitializeComponent();
    }
}
```
