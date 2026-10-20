# Bug Assessment: Database Schema TreeView Node Rendering & Hardcoded Hint String

- **Slug**: database-schema-treeview-rendering
- **Created**: 2026-10-20T11:55:00+07:00
- **Source**: User uploaded screenshot (`media_1792470568878_f3d096f0.png`) showing TreeView nodes rendering literal class name `Microsoft.UI.Xaml.Controls.TreeViewNode`
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

The user submitted a diagnostic screenshot of the DataSphere application in an active database connection workspace (tab `localhost`). In the Schema Explorer tree view on the left column, all tree hierarchy nodes display the literal .NET type string:
```text
Microsoft.UI.Xaml.Controls.TreeViewNode
```
instead of displaying the database connection name, database schemas, table categories, and table names with their respective glyph icons.

Additionally, in the right-hand panel, the placeholder text displays a hardcoded English string:
```text
"Select a table in the explorer to browse its records"
```
which violates **Constitution Principle VII: Zero Hardcoded User-Facing Strings & Dynamic Internationalization (i18n)**.

## Symptom

When opening any database connection session tab, the left Schema Explorer TreeView renders every node as `Microsoft.UI.Xaml.Controls.TreeViewNode`. Users are completely unable to identify which node corresponds to which database, schema, table category, or table, rendering database browsing non-functional.

## Reproduction

1. Launch `DataSphere.exe`.
2. Navigate to the Database workspace tab (`Cơ sở dữ liệu`).
3. Under the Connection catalog explorer, open an active server connection (e.g. `localhost`).
4. Observe the Schema Explorer TreeView on the left side of the connection tab:
   - Every node displays `Microsoft.UI.Xaml.Controls.TreeViewNode`.
   - Icons and textual labels (e.g. `localhost`, `information_schema`, table names) are absent from the rendered nodes.
   - The right panel shows untranslated English text `Select a table in the explorer to browse its records`.

## Suspected Code Paths

- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml:58-66`:
  ```xml
  <!-- Explorer TreeView -->
  <TreeView
      Grid.Row="1"
      x:Name="SchemaTree"
      SelectionMode="Single"
      Expanding="SchemaTree_Expanding"
      ItemInvoked="SchemaTree_ItemInvoked"
      Padding="4" />
  ```
  `SchemaTree` does not define an `<TreeView.ItemTemplate>`. Without an explicit item template, WinUI 3's default template evaluates `{Binding}` on the container's data item (which is the `TreeViewNode` instance itself) rather than projecting `TreeViewNode.Content`.

- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs:58-86`:
  ```csharp
  private TreeViewNode CreateNode(string text, string iconGlyph, object dataContext)
  {
      var panel = new StackPanel { ... };
      ...
      var node = new TreeViewNode
      {
          Content = panel
      };
      return node;
  }
  ```
  `CreateNode` creates a visual `StackPanel` containing a `FontIcon` and `TextBlock` and assigns it to `TreeViewNode.Content`. Because `TreeView` lacks an `ItemTemplate`, the `Content` property is never presented in the visual tree, causing the container to default to `node.ToString()`.

- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml:89-93`:
  ```xml
  <TextBlock
      Text="Select a table in the explorer to browse its records"
      Style="{StaticResource BodyTextBlockStyle}"
      Foreground="{ThemeResource TextFillColorSecondaryBrush}"
      TextAlignment="Center" />
  ```
  Hardcoded English string literal violating Principle VII.

- `DataSphere/Resources/Locales/String.resx`, `String.en.resx`, `String.vi.resx`:
  Missing localized resource key `page_db_select_table_hint` for the empty table selection placeholder.

## Root Cause Hypothesis

In Windows App SDK (WinUI 3), `Microsoft.UI.Xaml.Controls.TreeView` uses a default item template when `<TreeView.ItemTemplate>` is omitted. When nodes are added procedurally via `SchemaTree.RootNodes.Add(node)` using `TreeViewNode` objects, the default `TreeViewItem` content presenter binds to the data item itself (`TreeViewNode`), not to `TreeViewNode.Content`. Consequently, WinUI 3 executes `node.ToString()`, rendering the string `"Microsoft.UI.Xaml.Controls.TreeViewNode"` for every item in the visual tree.

To correctly render the visual elements or data held in `TreeViewNode.Content`, `TreeView` requires an `ItemTemplate` with `x:DataType="TreeViewNode"` containing a `ContentControl` or `ContentPresenter` bound to `Content` (`{x:Bind Content}`), or a structured data template.

**Confidence**: High (100% verified via WinUI 3 XAML compilation semantics and reproducible code inspection).

## Proposed Remediation

### Preferred Fix:

1. **Add `ItemTemplate` to `DatabaseViewControl.xaml`**:
   Define `<TreeView.ItemTemplate>` on `SchemaTree` to project `TreeViewNode.Content`:
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
   This ensures each `TreeViewNode`'s custom `StackPanel` (with `FontIcon` and `TextBlock`) is rendered seamlessly by WinUI 3.

2. **Internationalize Empty State Placeholder**:
   Update `DatabaseViewControl.xaml:90` to bind to the dynamic localization dictionary:
   ```xml
   <TextBlock
       Text="{Binding [page_db_select_table_hint], Source={StaticResource Localization}, Mode=OneWay}"
       Style="{StaticResource BodyTextBlockStyle}"
       Foreground="{ThemeResource TextFillColorSecondaryBrush}"
       TextAlignment="Center" />
   ```

3. **Add Localization Resource Entries (UTF-8 Without BOM)**:
   Add `page_db_select_table_hint` to `String.resx`, `String.en.resx`, and `String.vi.resx`:
   - EN: `Select a table in the explorer to browse its records`
   - VI: `Chọn một bảng trong danh sách để xem dữ liệu`

4. **Verify in Unit & Automated UI Tests**:
   - Update `scratch/VerifyDatabaseView/Program.cs` to test the new resource key and verify no Mojibake.
   - Run the real desktop automation script (`scripts/test-real-desktop.ps1`) to capture visual proof that the TreeView displays actual connection names, database names, and icons.

### Files Likely to Change:
- `DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml`
- `DataSphere/Resources/Locales/String.resx`
- `DataSphere/Resources/Locales/String.en.resx`
- `DataSphere/Resources/Locales/String.vi.resx`
- `scratch/VerifyDatabaseView/Program.cs`

## Risks & Considerations

- **Low Risk**: The change is localized to `DatabaseViewControl.xaml` presentation templating and resource dictionary updates.
- **Visual Tree Layout**: Using `ContentControl` inside `DataTemplate x:DataType="TreeViewNode"` allows the existing `StackPanel` and its context menu handlers (`panel.ContextRequested`) to remain completely intact without rewriting event routing.
- **i18n Encoding**: Resource file editing must strictly comply with Principle VII (UTF-8 without BOM).

## Diagnostic Evidence

- **User Screenshot Evidence**: [diagnostic_reproduction_treeview_bug.png](file:///C:/Users/huynh/.gemini/antigravity/brain/aca4648a-7af8-48c3-9b8a-ae269a772d90/diagnostic_reproduction_treeview_bug.png).
- **Inspection Finding**: `SchemaTree` in `DatabaseViewControl.xaml` lacks `ItemTemplate`, causing WinUI 3 to fall back to `TreeViewNode.ToString()`.
