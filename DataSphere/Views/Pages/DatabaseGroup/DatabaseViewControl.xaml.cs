using System.Collections.Specialized;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using DataSphere.Models.Database;
using DataSphere.Utils;
using DataSphere.ViewModels.Pages.DatabaseGroup;

namespace DataSphere.Views.Pages.DatabaseGroup
{
    /// <summary>
    /// UserControl presenting the active database session schema explorer tree and right-hand tabular view.
    /// </summary>
    public sealed partial class DatabaseViewControl : UserControl, IDisposable
    {
        /// <summary>
        /// Gets the ViewModel governing the active database explorer session.
        /// </summary>
        public DatabaseControlViewModel ViewModel { get; }

        /// <summary>
        /// Initializes a new instance of the <see cref="DatabaseViewControl"/> class.
        /// </summary>
        /// <param name="viewModel">The viewmodel managing database session operations.</param>
        public DatabaseViewControl(DatabaseControlViewModel viewModel)
        {
            ViewModel = viewModel ?? throw new ArgumentNullException(nameof(viewModel));
            InitializeComponent();

            ViewModel.RootConnections.CollectionChanged += OnRootConnectionsChanged;
            RebuildTree();
        }

        private void OnRootConnectionsChanged(object? sender, NotifyCollectionChangedEventArgs e)
        {
            RebuildTree();
        }

        private void RebuildTree()
        {
            SchemaTree.RootNodes.Clear();

            foreach (var root in ViewModel.RootConnections)
            {
                var rootNode = CreateNode(root.DisplayName, "\uE774", root);
                rootNode.IsExpanded = true;

                foreach (var db in root.Databases)
                {
                    var dbNode = CreateNode(db.Name, "\uEDA2", db);
                    dbNode.HasUnrealizedChildren = true;
                    rootNode.Children.Add(dbNode);
                }

                SchemaTree.RootNodes.Add(rootNode);
            }
        }

        private TreeViewNode CreateNode(string text, string iconGlyph, object dataContext)
        {
            var nodeData = new DatabaseTreeNode
            {
                Title = text,
                IconGlyph = iconGlyph,
                DataContext = dataContext
            };

            return new TreeViewNode
            {
                Content = nodeData
            };
        }

        private void TreeNode_ContextRequested(UIElement sender, Microsoft.UI.Xaml.Input.ContextRequestedEventArgs args)
        {
            if (sender is FrameworkElement fe)
            {
                DatabaseTreeNode? dtn = null;
                if (fe.DataContext is TreeViewNode tvn)
                {
                    dtn = tvn.Content as DatabaseTreeNode;
                }
                else if (fe.DataContext is DatabaseTreeNode nodeData)
                {
                    dtn = nodeData;
                }

                if (dtn != null)
                {
                    if (dtn.DataContext is DatabaseInfo db)
                    {
                        ShowDatabaseContextMenu(fe, db, args);
                    }
                    else if (dtn.DataContext is ConnectionRoot cr)
                    {
                        ShowConnectionRootContextMenu(fe, cr, args);
                    }
                    else if (dtn.DataContext is TableCategoryContext tcc)
                    {
                        ShowTableCategoryContextMenu(fe, tcc.Database, args);
                    }
                }
            }
        }

        private void ShowDatabaseContextMenu(FrameworkElement anchor, DatabaseInfo db, Microsoft.UI.Xaml.Input.ContextRequestedEventArgs args)
        {
            var flyout = new MenuFlyout();

            var dropItem = new MenuFlyoutItem
            {
                Text = LanguageBase.GetLangValue("msgbox_delete_ques_title"),
                Icon = new FontIcon { Glyph = "\uE74D" }
            };
            dropItem.Click += (s, e) => _ = ViewModel.DropDatabaseAsync(db);
            flyout.Items.Add(dropItem);

            var refreshItem = new MenuFlyoutItem
            {
                Text = LanguageBase.GetLangValue("btn_refresh_table"),
                Icon = new FontIcon { Glyph = "\uE72C" }
            };
            refreshItem.Click += (s, e) => _ = ViewModel.RefreshDatabasesAsync();
            flyout.Items.Add(refreshItem);

            if (args.TryGetPosition(anchor, out var point))
            {
                flyout.ShowAt(anchor, point);
            }
            else
            {
                flyout.ShowAt(anchor);
            }
            args.Handled = true;
        }

        private void ShowConnectionRootContextMenu(FrameworkElement anchor, ConnectionRoot root, Microsoft.UI.Xaml.Input.ContextRequestedEventArgs args)
        {
            var flyout = new MenuFlyout();

            var newDbItem = new MenuFlyoutItem
            {
                Text = LanguageBase.GetLangValue("dbinf_database_title"),
                Icon = new FontIcon { Glyph = "\uE710" }
            };
            newDbItem.Click += (s, e) => _ = ViewModel.NewDatabaseAsync();
            flyout.Items.Add(newDbItem);

            var refreshItem = new MenuFlyoutItem
            {
                Text = LanguageBase.GetLangValue("btn_refresh_table"),
                Icon = new FontIcon { Glyph = "\uE72C" }
            };
            refreshItem.Click += (s, e) => _ = ViewModel.RefreshDatabasesAsync();
            flyout.Items.Add(refreshItem);

            if (args.TryGetPosition(anchor, out var point))
            {
                flyout.ShowAt(anchor, point);
            }
            else
            {
                flyout.ShowAt(anchor);
            }
            args.Handled = true;
        }

        private void ShowTableCategoryContextMenu(FrameworkElement anchor, DatabaseInfo db, Microsoft.UI.Xaml.Input.ContextRequestedEventArgs args)
        {
            var flyout = new MenuFlyout();

            var refreshItem = new MenuFlyoutItem
            {
                Text = LanguageBase.GetLangValue("btn_refresh_table"),
                Icon = new FontIcon { Glyph = "\uE72C" }
            };
            refreshItem.Click += async (s, e) =>
            {
                db.IsTablesLoaded = false;
                await ViewModel.LoadTablesAsync(db);
            };
            flyout.Items.Add(refreshItem);

            if (args.TryGetPosition(anchor, out var point))
            {
                flyout.ShowAt(anchor, point);
            }
            else
            {
                flyout.ShowAt(anchor);
            }
            args.Handled = true;
        }

        private async void SchemaTree_Expanding(TreeView sender, TreeViewExpandingEventArgs args)
        {
            if (args.Node.Content is not DatabaseTreeNode dtn) return;

            if (dtn.DataContext is DatabaseInfo db)
            {
                if (args.Node.HasUnrealizedChildren)
                {
                    // Guard immediately to prevent concurrent re-entrant expansion requests
                    args.Node.HasUnrealizedChildren = false;
                    args.Node.Children.Clear();

                    // Add Categories - Tables category node is unrealized and collapsed by default
                    var tablesCatNode = CreateNode(LanguageBase.GetLangValue("dbinf_tables_title"), "\uE8B7", new TableCategoryContext(db));
                    tablesCatNode.HasUnrealizedChildren = true;
                    tablesCatNode.IsExpanded = false;
                    args.Node.Children.Add(tablesCatNode);

                    // Placeholder categories
                    args.Node.Children.Add(CreateNode(LanguageBase.GetLangValue("dbinf_views_title"), "\uE890", db));
                    args.Node.Children.Add(CreateNode(LanguageBase.GetLangValue("dbinf_sps_title"), "\uE943", db));
                    args.Node.Children.Add(CreateNode(LanguageBase.GetLangValue("dbinf_fncs_title"), "\uF168", db));

                    // Explicitly set IsExpanded = true so WinUI 3 immediately renders child nodes on single click
                    args.Node.IsExpanded = true;
                }
            }
            else if (dtn.DataContext is TableCategoryContext tcc)
            {
                if (args.Node.HasUnrealizedChildren)
                {
                    // Guard immediately to prevent concurrent re-entrant expansion requests
                    args.Node.HasUnrealizedChildren = false;
                    dtn.IsLoading = true;

                    var tvi = sender.ContainerFromNode(args.Node) as TreeViewItem;
                    SetChevronLoading(tvi, true);

                    try
                    {
                        await ViewModel.LoadTablesAsync(tcc.Database);
                        args.Node.Children.Clear();

                        if (tcc.Database.Tables != null)
                        {
                            foreach (var table in tcc.Database.Tables)
                            {
                                var tableNode = CreateNode(table.Name, "\uF0E2", new TableNodeContext(tcc.Database, table));
                                args.Node.Children.Add(tableNode);
                            }
                        }

                        // Explicitly set IsExpanded = true post-await so WinUI 3 immediately renders realized tables on single click
                        args.Node.IsExpanded = true;
                    }
                    finally
                    {
                        dtn.IsLoading = false;
                        SetChevronLoading(tvi, false);
                    }
                }
            }
        }

        /// <summary>
        /// Updates the TreeViewItem's chevron glyph slot to display an active loading ProgressRing
        /// while asynchronous data fetching is in progress, transitioning smoothly back to the standard
        /// expanded downward chevron upon completion.
        /// </summary>
        /// <param name="tvi">The TreeViewItem container being expanded.</param>
        /// <param name="isLoading">True to activate loading spinner; false to restore down-arrow chevron.</param>
        private void SetChevronLoading(TreeViewItem? tvi, bool isLoading)
        {
            if (tvi == null) return;

            var chevronGrid = FindVisualChild<Grid>(tvi, "ExpandCollapseChevron");
            if (chevronGrid == null) return;

            var expandedGlyph = FindVisualChild<TextBlock>(chevronGrid, "ExpandedGlyph");
            var collapsedGlyph = FindVisualChild<TextBlock>(chevronGrid, "CollapsedGlyph");
            var existingRings = chevronGrid.Children.OfType<ProgressRing>().ToList();

            if (isLoading)
            {
                if (expandedGlyph != null) expandedGlyph.Opacity = 0;
                if (collapsedGlyph != null) collapsedGlyph.Opacity = 0;

                if (existingRings.Count == 0)
                {
                    var ring = new ProgressRing
                    {
                        Width = 14,
                        Height = 14,
                        IsActive = true,
                        Visibility = Visibility.Visible,
                        HorizontalAlignment = HorizontalAlignment.Center,
                        VerticalAlignment = VerticalAlignment.Center
                    };
                    chevronGrid.Children.Add(ring);
                }
                else
                {
                    foreach (var ring in existingRings)
                    {
                        ring.Visibility = Visibility.Visible;
                        ring.IsActive = true;
                    }
                }
            }
            else
            {
                foreach (var ring in existingRings)
                {
                    ring.IsActive = false;
                    ring.Visibility = Visibility.Collapsed;
                    chevronGrid.Children.Remove(ring);
                }

                if (expandedGlyph != null) expandedGlyph.Opacity = 1;
                if (collapsedGlyph != null) collapsedGlyph.Opacity = 1;
            }
        }

        /// <summary>
        /// Traverses the visual tree to locate a child element of specified type and optional name.
        /// </summary>
        /// <typeparam name="T">The visual child element type.</typeparam>
        /// <param name="parent">The root dependency object to search from.</param>
        /// <param name="name">The optional framework element name to match.</param>
        /// <returns>The matching framework element, or null if not found.</returns>
        private static T? FindVisualChild<T>(DependencyObject parent, string? name = null) where T : FrameworkElement
        {
            int count = VisualTreeHelper.GetChildrenCount(parent);
            for (int i = 0; i < count; i++)
            {
                var child = VisualTreeHelper.GetChild(parent, i);
                if (child is T typedChild && (name == null || typedChild.Name == name))
                {
                    return typedChild;
                }

                var found = FindVisualChild<T>(child, name);
                if (found != null)
                {
                    return found;
                }
            }
            return null;
        }

        private void SchemaTree_ItemInvoked(TreeView sender, TreeViewItemInvokedEventArgs args)
        {
            if (args.InvokedItem is TreeViewNode node && node.Content is DatabaseTreeNode dtn)
            {
                if (dtn.DataContext is TableNodeContext tnc)
                {
                    ViewModel.SelectTable(tnc.Database, tnc.Table);
                }
                else if (dtn.DataContext is TableCategoryContext || dtn.DataContext is DatabaseInfo)
                {
                    if (!dtn.IsLoading)
                    {
                        node.IsExpanded = !node.IsExpanded;
                    }
                }
            }
        }

        /// <inheritdoc/>
        public void Dispose()
        {
            ViewModel.RootConnections.CollectionChanged -= OnRootConnectionsChanged;
            ViewModel.Dispose();
        }

        private record TableCategoryContext(DatabaseInfo Database);

        private record TableNodeContext(DatabaseInfo Database, Table Table);
    }
}
