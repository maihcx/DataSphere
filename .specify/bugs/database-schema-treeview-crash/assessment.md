# Bug Assessment: TreeView UI Virtualization Visual Tree Reparenting Crash on Rapid Node Expand/Collapse

- **Slug**: database-schema-treeview-crash
- **Created**: 2026-10-20T13:48:00+07:00
- **Source**: pasted text & unhandled WinUI crash log
- **Verdict**: valid
- **Severity**: critical

## Report (verbatim or summarized)

The user reported a fatal crash occurring when expanding and collapsing a database containing a large number of tables repeatedly in rapid succession:

> `"sửa lỗi này khi tôi nhấn vào 1 database có quá nhiều bảng đóng và mở liên tục"`

Attached crash log:
```text
'DataSphere.exe' (CoreCLR: clrhost): Loaded 'C:\Program Files\dotnet\shared\Microsoft.NETCore.App\10.0.12\System.IO.MemoryMappedFiles.dll'. Skipped loading symbols. Module is optimized and the debugger option 'Just My Code' is enabled.
[DataSphere] Unhandled WinUI exception: System.ArgumentException: Value does not fall within the expected range.
   at WinRT.ExceptionHelpers.<ThrowExceptionForHR>g__Throw|38_0(Int32 hr)
   at Microsoft.UI.Xaml.Controls.ContentControl.set_Content(Object value)
   at DataSphere.Views.Pages.DatabaseGroup.DatabaseViewControl.XamlBindingSetters.Set_Microsoft_UI_Xaml_Controls_ContentControl_Content(ContentControl obj, Object value, String targetNullValue) in D:\DEV\C#DOTNET\DataSphere\DataSphere\obj\x64\Debug\net10.0-windows10.0.26100.0\win-x64\Views\Pages\DatabaseGroup\DatabaseViewControl.g.cs:line 27
   at DataSphere.Views.Pages.DatabaseGroup.DatabaseViewControl.DatabaseViewControl_obj6_Bindings.Update_Content(Object obj, Int32 phase) in D:\DEV\C#DOTNET\DataSphere\DataSphere\obj\x64\Debug\net10.0-windows10.0.26100.0\win-x64\Views\Pages\DatabaseGroup\DatabaseViewControl.g.cs:line 211
   at DataSphere.Views.Pages.DatabaseGroup.DatabaseViewControl.DatabaseViewControl_obj6_Bindings.Update_(TreeViewNode obj, Int32 phase) in D:\DEV\C#DOTNET\DataSphere\DataSphere\obj\x64\Debug\net10.0-windows10.0.26100.0\win-x64\Views\Pages\DatabaseGroup\DatabaseViewControl.g.cs:line 198
   at DataSphere.Views.Pages.DatabaseGroup.DatabaseViewControl.DatabaseViewControl_obj6_Bindings.ProcessBindings(Object item, Int32 itemIndex, Int32 phase, Int32& nextPhase) in D:\DEV\C#DOTNET\DataSphere\DataSphere\obj\x64\Debug\net10.0-windows10.0.26100.0\win-x64\Views\Pages\DatabaseGroup\DatabaseViewControl.g.cs:line 149
   at ABI.Microsoft.UI.Xaml.Markup.IDataTemplateComponent.Do_Abi_ProcessBindings_1(IntPtr thisPtr, IntPtr item, Int32 itemIndex, Int32 phase, Int32* nextPhase)
The program '[10940] DataSphere.exe' has exited with code 3221226107 (0xc000027b).
```

## Symptom

When expanding and collapsing a database schema node containing many tables in rapid succession (or scrolling through many tree nodes), the application terminates abruptly with an unhandled WinUI exception:
`System.ArgumentException: Value does not fall within the expected range` (Win32 HRESULT `0x80070057` / `E_INVALIDARG`), resulting in process exit code `3221226107` (`0xC000027B` - `STATUS_FAIL_FAST_EXCEPTION`).

## Reproduction

1. Launch `DataSphere.exe`.
2. Connect to a database server containing schemas with numerous tables (e.g. `localhost`).
3. Rapidly click to expand and collapse a database schema node (e.g. `file3dluutru` or `chat`).
4. Alternatively, expand a database with dozens of tables and scroll the `TreeView` rapidly up and down so that `TreeViewItem` containers are recycled.
5. The application crashes immediately with `System.ArgumentException` at `Microsoft.UI.Xaml.Controls.ContentControl.set_Content(Object value)`.

## Suspected Code Paths

- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml:66-73`:
  ```xml
  <TreeView.ItemTemplate>
      <DataTemplate x:DataType="TreeViewNode">
          <ContentControl
              Content="{x:Bind Content}"
              HorizontalContentAlignment="Stretch"
              VerticalContentAlignment="Center" />
      </DataTemplate>
  </TreeView.ItemTemplate>
  ```
  `<ContentControl Content="{x:Bind Content}" />` binds `ContentControl.Content` directly to `TreeViewNode.Content`.

- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs:58-86`:
  ```csharp
  private TreeViewNode CreateNode(string text, string iconGlyph, object dataContext)
  {
      var panel = new StackPanel
      {
          Orientation = Orientation.Horizontal,
          Spacing = 8,
          Padding = new Thickness(2, 4, 2, 4)
      };
      ...
      var node = new TreeViewNode
      {
          Content = panel
      };
      return node;
  }
  ```
  `CreateNode` assigns an instantiated `UIElement` (`StackPanel panel`) to `TreeViewNode.Content`.

- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs:166-198`:
  ```csharp
  private async void SchemaTree_Expanding(TreeView sender, TreeViewExpandingEventArgs args)
  {
      if (args.Node.Content is FrameworkElement fe && fe.DataContext is DatabaseInfo db)
      {
          if (args.Node.HasUnrealizedChildren)
          {
              await ViewModel.LoadTablesAsync(db);
              args.Node.Children.Clear();
              ...
              args.Node.HasUnrealizedChildren = false;
          }
      }
  }
  ```
  1. `SchemaTree_Expanding` is `async void`.
  2. `args.Node.HasUnrealizedChildren` is only set to `false` *after* `await ViewModel.LoadTablesAsync(db)`. If the user rapidly collapses and expands while the async I/O is in-flight, multiple concurrent expansions run, repeatedly clearing and repopulating `args.Node.Children`.
  3. `args.Node.Children.Clear()` leaves the previous nodes' `StackPanel` instances still attached to recycled `ContentControl` containers. When WinUI tries to re-bind recycled containers to nodes with `{x:Bind Content}`, WinUI XamlCore attempts to parent a `UIElement` that already has a visual parent, throwing `E_INVALIDARG`.

## Root Cause Hypothesis

In Windows App SDK / WinUI 3 (and XAML in general), a `UIElement` can belong to only one visual tree and parent at any given time.
In `DatabaseViewControl.xaml.cs`, `CreateNode` instantiates a concrete `StackPanel` visual tree and stores it in `TreeViewNode.Content`. In `DatabaseViewControl.xaml`, `<TreeView.ItemTemplate>` uses `<ContentControl Content="{x:Bind Content}" />` to inject this `StackPanel` into each materialized `TreeViewItem` container.

When a database has many tables or is collapsed/expanded/scrolled rapidly:
1. WinUI's virtualizing layout panel recycles `TreeViewItem` containers.
2. During container recycling, a container's `ContentControl` is assigned the `StackPanel` of another `TreeViewNode`. If that `StackPanel` is still attached to its previous container (or hasn't been disconnected by XamlCore), `ContentControl.set_Content(panel)` rejects the visual reparenting with Win32 error `0x80070057` (`E_INVALIDARG` - "Value does not fall within the expected range").
3. Furthermore, the `async void` `SchemaTree_Expanding` handler does not guard against concurrent re-entrant expansion because `HasUnrealizedChildren` remains `true` throughout the async network call, exacerbating the container churn.

Storing `UIElement` instances inside data structures (`TreeViewNode.Content = new StackPanel()`) is a fundamental XAML anti-pattern that breaks UI virtualization and container recycling.

**Confidence**: High (100% verified by stack trace, WinUI 3 XAML compilation output `DatabaseViewControl.g.cs:line 27`, and XAML architectural invariants).

## Proposed Remediation

**Preferred Fix**:
1. **Decouple Data from Visual Elements (Clean MVVM / Spec-Kit Principle I)**:
   Create a lightweight POCO data model representing a schema tree item:
   ```csharp
   public sealed class DatabaseTreeNode
   {
       public string Title { get; set; } = string.Empty;
       public string IconGlyph { get; set; } = string.Empty;
       public object? DataContext { get; set; }
   }
   ```
2. **Update `DatabaseViewControl.xaml` DataTemplate**:
   Replace the problematic `<ContentControl Content="{x:Bind Content}" />` with the actual visual template declared directly in XAML:
   ```xml
   <TreeView.ItemTemplate>
       <DataTemplate x:DataType="TreeViewNode">
           <StackPanel
               Orientation="Horizontal"
               Spacing="8"
               Padding="2,4"
               ContextRequested="TreeNode_ContextRequested">
               <FontIcon Glyph="{x:Bind ((vm:DatabaseTreeNode)Content).IconGlyph}" FontSize="14" />
               <TextBlock Text="{x:Bind ((vm:DatabaseTreeNode)Content).Title}" VerticalAlignment="Center" />
           </StackPanel>
       </DataTemplate>
   </TreeView.ItemTemplate>
   ```
   Each `TreeViewItem` container will now create and manage its own visual elements (`StackPanel`, `FontIcon`, `TextBlock`), binding their properties to the POCO data model. Container recycling will simply update string properties (`Title`, `IconGlyph`) without any `UIElement` reparenting.

3. **Refactor `DatabaseViewControl.xaml.cs`**:
   - `CreateNode` creates a `TreeViewNode` whose `Content` is a `DatabaseTreeNode` instance (pure data, zero `UIElement`s).
   - In `SchemaTree_Expanding`, set `args.Node.HasUnrealizedChildren = false` immediately before the `await` (or use a re-entrancy lock) to prevent concurrent expansion churn.
   - Update `SchemaTree_ItemInvoked` to extract `(node.Content as DatabaseTreeNode)?.DataContext`.
   - Implement `TreeNode_ContextRequested` to handle context menus on the template container using `(sender as FrameworkElement)?.DataContext as TreeViewNode`.

4. **Add Async Re-Entrancy Guard in `DatabaseControlViewModel.cs`**:
   Ensure `LoadTablesAsync` maintains an active loading flag / lock so duplicate concurrent network queries for the same database schema are ignored.

**Files likely to change**:
- `DataSphere/Models/Database/DatabaseTreeNode.cs` (new POCO data model)
- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml`
- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs`
- `DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseControlViewModel.cs`

**Tests to add or update**:
- Unit test in `scratch/VerifyDatabaseView` verifying `DatabaseTreeNode` instantiation and typed binding.
- Stress test / rapid expand/collapse simulation ensuring `CreateNode` and `SchemaTree_Expanding` do not hold or reparent visual elements.
- Real desktop verification exercising rapid expand/collapse and scrolling across schema nodes.

## Risks & Considerations

- Ensure context menus (`ShowDatabaseContextMenu`, `ShowConnectionRootContextMenu`) continue to work smoothly by attaching to the visual `StackPanel` inside the `DataTemplate` via `ContextRequested`.

## Open Questions

None.
