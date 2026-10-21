# Contract: In-Place Table Editor & Viewport Toolbar Contract

**Feature**: `007-table-editor-and-query-pipeline`  
**Date**: 2026-10-21  

---

## 1. ViewModel Contract (`DataControlViewModel`)

```csharp
namespace DataSphere.ViewModels.Pages.DatabaseGroup
{
    public partial class DataControlViewModel : ObservableObject, IDisposable
    {
        // ... Existing pagination properties ...

        /// <summary>
        /// Gets a value indicating whether there are staged modifications that can be committed.
        /// </summary>
        public bool CanCommit => !IsLoading && HasPrimaryKeys && (DataPage?.HasDirtyRows ?? false);

        /// <summary>
        /// Gets a value indicating whether there are staged modifications that can be discarded.
        /// </summary>
        public bool CanDiscard => !IsLoading && (DataPage?.HasDirtyRows ?? false);

        /// <summary>
        /// Gets a value indicating whether the target table has at least one primary key required for in-place editing.
        /// </summary>
        public bool HasPrimaryKeys => _table.PrimaryKeys.Count > 0;

        /// <summary>
        /// Command to commit all staged row modifications to the database engine via parameterized UPDATE statements.
        /// </summary>
        [RelayCommand(CanExecute = nameof(CanCommit))]
        public Task CommitChangesAsync();

        /// <summary>
        /// Command to discard all staged modifications in the current view and restore original cell values.
        /// </summary>
        [RelayCommand(CanExecute = nameof(CanDiscard))]
        public void DiscardChanges();

        /// <summary>
        /// Asynchronously executes a server-side SQL query with the specified column sort descriptor.
        /// </summary>
        public Task SortByServerColumnAsync(int columnIndex, ColumnSortDirection direction, string columnName, string dataType);

        /// <summary>
        /// Cancels any active in-flight database query immediately.
        /// </summary>
        public void CancelActiveQuery();
    }
}
```

---

## 2. Viewport Toolbar Contract (`DataViewControl.xaml`)

```xml
<!-- Viewport Toolbar -->
<Border Grid.Row="0" Padding="16,10" BorderBrush="{ThemeResource CardStrokeColorDefaultBrush}" BorderThickness="0,0,0,1">
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*" />
            <ColumnDefinition Width="Auto" />
        </Grid.ColumnDefinitions>

        <StackPanel Grid.Column="0" Orientation="Horizontal" Spacing="12" VerticalAlignment="Center">
            <FontIcon Glyph="&#xF0E2;" FontSize="18" Foreground="{ThemeResource AccentTextFillColorPrimaryBrush}" />
            <ProgressRing
                Width="16" Height="16"
                IsActive="{x:Bind ViewModel.IsLoading, Mode=OneWay}"
                Visibility="{x:Bind ViewModel.IsLoading, Mode=OneWay}" />
            <TextBlock
                Text="{x:Bind ViewModel.EditingNoticeText, Mode=OneWay}"
                Foreground="{ThemeResource TextFillColorSecondaryBrush}"
                Style="{StaticResource CaptionTextBlockStyle}"
                VerticalAlignment="Center" />
        </StackPanel>

        <StackPanel Grid.Column="1" Orientation="Horizontal" Spacing="8">
            <!-- Commit / Save Button -->
            <Button
                Command="{x:Bind ViewModel.CommitChangesCommand}"
                IsEnabled="{x:Bind ViewModel.CanCommit, Mode=OneWay}">
                <StackPanel Orientation="Horizontal" Spacing="6">
                    <FontIcon Glyph="&#xE74E;" FontSize="14" />
                    <TextBlock Text="{Binding [btn_commit_changes], Source={StaticResource Localization}, Mode=OneWay}" />
                </StackPanel>
            </Button>

            <!-- Discard / Revert Button -->
            <Button
                Command="{x:Bind ViewModel.DiscardChangesCommand}"
                IsEnabled="{x:Bind ViewModel.CanDiscard, Mode=OneWay}">
                <StackPanel Orientation="Horizontal" Spacing="6">
                    <FontIcon Glyph="&#xE711;" FontSize="14" />
                    <TextBlock Text="{Binding [btn_discard_changes], Source={StaticResource Localization}, Mode=OneWay}" />
                </StackPanel>
            </Button>

            <!-- Refresh Button -->
            <Button Command="{x:Bind ViewModel.RefreshCommand}">
                <StackPanel Orientation="Horizontal" Spacing="6">
                    <FontIcon Glyph="&#xE72C;" FontSize="14" />
                    <TextBlock Text="{Binding [btn_refresh_table], Source={StaticResource Localization}, Mode=OneWay}" />
                </StackPanel>
            </Button>
        </StackPanel>
    </Grid>
</Border>
```

---

## 3. DataGrid Interaction Contract

- `CanUserSortColumns="True"`
- `CanUserResizeColumns="True"`
- `IsReadOnly="False"` (dynamically enabled when `HasPrimaryKeys == true`)
- `Sorting="OnDataGridSorting"`: Intercepts column header clicks, toggles `SortDirection`, and dispatches `ViewModel.SortByServerColumnAsync`.
- `CellEditEnding="OnDataGridCellEditEnding"`: Captures user input value changes, compares against `OriginalCells`, marks `TableRowData` as dirty, and triggers `ViewModel.NotifyDirtyStateChanged()`.
