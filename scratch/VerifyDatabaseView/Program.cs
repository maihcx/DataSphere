using System;
using System.Globalization;
using System.IO;
using System.Threading;
using System.Xml.Linq;
using DataSphere.Models;
using DataSphere.Services.Contracts;
using DataSphere.Utils;
using DataSphere.ViewModels.Pages.DatabaseGroup;

namespace VerifyDatabaseView
{
    class DummyDialogService : IDialogService
    {
        public Task<ConnectionModel?> ShowConnectionEditingDialogAsync(ConnectionModel? existingConnection = null, object? xamlRoot = null)
        {
            return Task.FromResult<ConnectionModel?>(null);
        }

        public Task<DataSphere.Models.Database.DatabaseInfo?> ShowDatabaseEditingDialogAsync(DataSphere.Services.Database.Interface.IDatabaseConnection connection, object? xamlRoot = null)
        {
            return Task.FromResult<DataSphere.Models.Database.DatabaseInfo?>(null);
        }

        public Task<bool> ShowConfirmationDialogAsync(string titleKey, string messageKey, object[]? formatArgs = null, object? xamlRoot = null)
        {
            return Task.FromResult(true);
        }
    }

    class Program
    {
        static int Main(string[] args)
        {
            Console.WriteLine("=================================================");
            Console.WriteLine("Starting Database View & Localization Verification");
            Console.WriteLine("=================================================");

            int passCount = 0;
            int failCount = 0;

            void Assert(string description, bool condition)
            {
                if (condition)
                {
                    Console.WriteLine($"[PASS] {description}");
                    passCount++;
                }
                else
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine($"[FAIL] {description}");
                    Console.ResetColor();
                    failCount++;
                }
            }

            try
            {
                // Test 1: Check String.vi.resx directly on disk for Mojibake
                string resxPath = "DataSphere/Resources/Locales/String.vi.resx";
                Assert("Test 1: String.vi.resx exists", File.Exists(resxPath));

                string resxContent = File.ReadAllText(resxPath);
                Assert("Test 2: No double-encoded Mojibake 'Káº¿t' in String.vi.resx",
                    !resxContent.Contains("Káº¿t"));
                Assert("Test 3: No double-encoded Mojibake 'Kiá»ƒm' in String.vi.resx",
                    !resxContent.Contains("Kiá»ƒm"));
                Assert("Test 4: No double-encoded Mojibake 'Táº¡o' in String.vi.resx",
                    !resxContent.Contains("Táº¡o"));

                var doc = XDocument.Parse(resxContent);
                var connHeaderElement = doc.Root?.Elements("data")
                    .FirstOrDefault(e => e.Attribute("name")?.Value == "tab_connections_header");
                string? connHeaderVal = connHeaderElement?.Element("value")?.Value;

                Assert("Test 5: tab_connections_header in String.vi.resx equals 'Kết nối'",
                    connHeaderVal == "Kết nối");

                // Test 6: Check LanguageBase resolution with Vietnamese culture
                Thread.CurrentThread.CurrentUICulture = new CultureInfo("vi");
                string resolvedTitle = LanguageBase.GetLangValue("tab_connections_header");
                Assert($"Test 6: LanguageBase resolved title is 'Kết nối' (actual: '{resolvedTitle}')",
                    resolvedTitle == "Kết nối");

                string resolvedBtnNew = LanguageBase.GetLangValue("btn_new_connection");
                Assert($"Test 7: LanguageBase resolved btn_new_connection is 'Tạo kết nối mới' (actual: '{resolvedBtnNew}')",
                    resolvedBtnNew == "Tạo kết nối mới");

                string resolvedBtnTest = LanguageBase.GetLangValue("btn_test_connection");
                Assert($"Test 8: LanguageBase resolved btn_test_connection is 'Kiểm tra kết nối' (actual: '{resolvedBtnTest}')",
                    resolvedBtnTest == "Kiểm tra kết nối");

                // Test 9: Check DatabaseViewModel Tab 0 Initialization
                var dialogService = new DummyDialogService();
                var dbVm = new DatabaseViewModel(dialogService);

                Assert("Test 9: DatabaseViewModel.InnerTabs has at least 1 tab",
                    dbVm.InnerTabs.Count >= 1);

                var tab0 = dbVm.InnerTabs[0];
                Assert($"Test 10: Tab 0 Header is 'Kết nối' (actual: '{tab0.Header}')",
                    tab0.Header == "Kết nối");

                Assert("Test 11: Tab 0 Content is not null",
                    tab0.Content != null);

                Assert("Test 12: SelectedInnerTab equals Tab 0",
                    Equals(dbVm.SelectedInnerTab, tab0));

                Assert("Test 13: SelectedInnerTab.Content is not null",
                    dbVm.SelectedInnerTab?.Content != null);

                Assert("Test 14: Tab 0 IsClosable is false (anchored connection explorer)",
                    !tab0.IsClosable);

                // Test 15: Check page_db_select_table_hint in String.vi.resx
                var hintElement = doc.Root?.Elements("data")
                    .FirstOrDefault(e => e.Attribute("name")?.Value == "page_db_select_table_hint");
                string? hintVal = hintElement?.Element("value")?.Value;
                Assert("Test 15: page_db_select_table_hint in String.vi.resx equals 'Chọn một bảng trong danh sách để xem dữ liệu'",
                    hintVal == "Chọn một bảng trong danh sách để xem dữ liệu");

                // Test 16: LanguageBase resolves page_db_select_table_hint for Vietnamese culture
                TranslationSource.Instance.CurrentCulture = new CultureInfo("vi");
                string viHint = LanguageBase.GetLangValue("page_db_select_table_hint");
                Assert($"Test 16: LanguageBase resolved Vietnamese hint is 'Chọn một bảng trong danh sách để xem dữ liệu' (actual: '{viHint}')",
                    viHint == "Chọn một bảng trong danh sách để xem dữ liệu");

                // Test 17: LanguageBase resolves page_db_select_table_hint for English culture
                TranslationSource.Instance.CurrentCulture = new CultureInfo("en");
                string enHint = LanguageBase.GetLangValue("page_db_select_table_hint");
                Assert($"Test 17: LanguageBase resolved English hint is 'Select a table in the explorer to browse its records' (actual: '{enHint}')",
                    enHint == "Select a table in the explorer to browse its records");

                // Test 18: DatabaseViewControl.xaml defines TreeView.ItemTemplate with TreeViewNode
                string viewXamlPath = "DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml";
                Assert("Test 18: DatabaseViewControl.xaml exists", File.Exists(viewXamlPath));
                string viewXamlContent = File.ReadAllText(viewXamlPath);

                Assert("Test 19: DatabaseViewControl.xaml defines TreeView.ItemTemplate with x:DataType=\"TreeViewNode\"",
                    viewXamlContent.Contains("<TreeView.ItemTemplate>") &&
                    viewXamlContent.Contains("x:DataType=\"TreeViewNode\"") &&
                    viewXamlContent.Contains("((dbmodels:DatabaseTreeNode)Content).Title"));

                // Test 20: DatabaseViewControl.xaml does not have hardcoded table hint
                Assert("Test 20: DatabaseViewControl.xaml uses dynamic localization binding for table hint",
                    viewXamlContent.Contains("Text=\"{Binding [page_db_select_table_hint], Source={StaticResource Localization}, Mode=OneWay}\"") &&
                    !viewXamlContent.Contains("Text=\"Select a table in the explorer to browse its records\""));

                // Test 21: NullToVisibilityConverter unit test
                var nullConverter = new DataSphere.Helpers.NullToVisibilityConverter();
                var nullResult = nullConverter.Convert(null, typeof(Microsoft.UI.Xaml.Visibility), null, "en");
                var objResult = nullConverter.Convert(new object(), typeof(Microsoft.UI.Xaml.Visibility), null, "en");
                Assert("Test 21: NullToVisibilityConverter returns Visible for null and Collapsed for non-null",
                    (Microsoft.UI.Xaml.Visibility)nullResult == Microsoft.UI.Xaml.Visibility.Visible &&
                    (Microsoft.UI.Xaml.Visibility)objResult == Microsoft.UI.Xaml.Visibility.Collapsed);

                // Test 22: NotNullToVisibilityConverter unit test
                var notNullConverter = new DataSphere.Helpers.NotNullToVisibilityConverter();
                var nnNullResult = notNullConverter.Convert(null, typeof(Microsoft.UI.Xaml.Visibility), null, "en");
                var nnObjResult = notNullConverter.Convert(new object(), typeof(Microsoft.UI.Xaml.Visibility), null, "en");
                Assert("Test 22: NotNullToVisibilityConverter returns Collapsed for null and Visible for non-null",
                    (Microsoft.UI.Xaml.Visibility)nnNullResult == Microsoft.UI.Xaml.Visibility.Collapsed &&
                    (Microsoft.UI.Xaml.Visibility)nnObjResult == Microsoft.UI.Xaml.Visibility.Visible);

                // Test 23: DatabaseViewControl.xaml uses NullToVisibilityConverter for empty selection placeholder
                Assert("Test 23: DatabaseViewControl.xaml uses NullToVisibilityConverter for placeholder",
                    viewXamlContent.Contains("Converter={StaticResource NullToVisibilityConverter}"));

                // Test 24: DatabaseViewControl.xaml sets IsHitTestVisible=\"False\" on empty selection placeholder
                Assert("Test 24: DatabaseViewControl.xaml sets IsHitTestVisible=\"False\" on placeholder",
                    viewXamlContent.Contains("IsHitTestVisible=\"False\""));

                // Test 25: DataViewControl.xaml uses SelectionMode=\"Single\"
                string dataViewXamlPath = "DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml";
                Assert("Test 25: DataViewControl.xaml exists", File.Exists(dataViewXamlPath));
                string dataViewXamlContent = File.ReadAllText(dataViewXamlPath);
                Assert("Test 26: DataViewControl.xaml has SelectionMode=\"Single\" on ListView",
                    dataViewXamlContent.Contains("SelectionMode=\"Single\""));

                // Test 27: DataViewControl.xaml enables text selection on cell TextBlock
                Assert("Test 27: DataViewControl.xaml has IsTextSelectionEnabled=\"True\" on cell TextBlock",
                    dataViewXamlContent.Contains("IsTextSelectionEnabled=\"True\""));

                // Test 28: DatabaseViewControl.xaml.cs icon glyphs
                string viewCsPath = "DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml.cs";
                string viewCsContent = File.ReadAllText(viewCsPath);
                Assert("Test 28: DatabaseViewControl.xaml.cs uses \\uEDA2 for Database and \\uF0E2 for Table",
                    viewCsContent.Contains("CreateNode(db.Name, \"\\uEDA2\", db)") &&
                    viewCsContent.Contains("CreateNode(table.Name, \"\\uF0E2\", new TableNodeContext(") &&
                    viewCsContent.Contains("CreateNode(LanguageBase.GetLangValue(\"dbinf_views_title\"), \"\\uE890\", db)") &&
                    viewCsContent.Contains("CreateNode(LanguageBase.GetLangValue(\"dbinf_fncs_title\"), \"\\uF168\", db)"));

                // Test 29: DatabaseInfo categories glyphs
                string dbInfoPath = "DataSphere/Models/Database/DatabaseInfo.cs";
                string dbInfoContent = File.ReadAllText(dbInfoPath);
                Assert("Test 29: DatabaseInfo.cs uses \\uE8B7 (Folder) for tables and \\uE890 for views and \\uF168 for fncs",
                    dbInfoContent.Contains("IconGlyph = \"\\uE8B7\"") &&
                    dbInfoContent.Contains("IconGlyph = \"\\uE890\"") &&
                    dbInfoContent.Contains("IconGlyph = \"\\uF168\""));

                // Test 30: DatabaseTreeNode exists and is pure data model
                var treeNodeData = new DataSphere.Models.Database.DatabaseTreeNode
                {
                    Title = "TestTitle",
                    IconGlyph = "\uEDA2",
                    DataContext = "TestData"
                };
                Assert("Test 30: DatabaseTreeNode holds pure data without inheriting UIElement",
                    treeNodeData.Title == "TestTitle" &&
                    treeNodeData.IconGlyph == "\uEDA2" &&
                    treeNodeData.DataContext?.ToString() == "TestData" &&
                    !typeof(Microsoft.UI.Xaml.UIElement).IsAssignableFrom(typeof(DataSphere.Models.Database.DatabaseTreeNode)));

                // Test 31: DatabaseViewControl.xaml.cs creates DatabaseTreeNode and guards HasUnrealizedChildren
                Assert("Test 31: DatabaseViewControl.xaml.cs creates DatabaseTreeNode and guards HasUnrealizedChildren before await",
                    viewCsContent.Contains("new DatabaseTreeNode") &&
                    viewCsContent.Contains("args.Node.HasUnrealizedChildren = false;") &&
                    viewCsContent.Contains("TreeNode_ContextRequested"));

                // Test 32: DatabaseControlViewModel guards concurrent LoadTablesAsync with lock
                string dbControlVmPath = "DataSphere/ViewModels/Pages/DatabaseGroup/DatabaseControlViewModel.cs";
                string dbControlVmContent = File.ReadAllText(dbControlVmPath);
                Assert("Test 32: DatabaseControlViewModel guards concurrent LoadTablesAsync with _loadingDatabases lock",
                    dbControlVmContent.Contains("_loadingDatabases") &&
                    dbControlVmContent.Contains("lock (_loadingDatabases)"));

                // Test 33: TableDataPage defines TotalTableWidth
                var testPage = new DataSphere.Models.TableDataPage();
                testPage.Columns.Add(new DataSphere.Models.Database.Column { Name = "id", DataType = "int" });
                testPage.Columns.Add(new DataSphere.Models.Database.Column { Name = "name", DataType = "string" });
                Assert("Test 33: TableDataPage defines calculated TotalTableWidth",
                    testPage.TotalTableWidth >= 600);

                // Test 34: DataViewControl.xaml uses Two-Tier Virtualized Grid
                dataViewXamlContent = File.ReadAllText(dataViewXamlPath);
                Assert("Test 34: DataViewControl.xaml disables vertical scroll on outer ScrollViewer to enable inner ListView virtualization",
                    dataViewXamlContent.Contains("VerticalScrollBarVisibility=\"Disabled\"") &&
                    dataViewXamlContent.Contains("VerticalScrollMode=\"Disabled\"") &&
                    dataViewXamlContent.Contains("HorizontalScrollBarVisibility=\"Auto\""));

                // Test 35: DataViewControl.xaml places ListView in a constrained Grid.Row
                Assert("Test 35: DataViewControl.xaml places ListView in Grid.Row=\"1\" with constrained height",
                    dataViewXamlContent.Contains("<ListView") &&
                    dataViewXamlContent.Contains("Grid.Row=\"1\""));

                // Test 36: DataViewControl.xaml configures ItemsStackPanel with CacheLength="2.0"
                Assert("Test 36: DataViewControl.xaml configures ItemsStackPanel with CacheLength=\"2.0\" on ListView",
                    dataViewXamlContent.Contains("<ItemsStackPanel Orientation=\"Vertical\" CacheLength=\"2.0\" />"));

                // Test 37: DataViewControl.xaml binds inner Grid MinWidth to TotalTableWidth
                Assert("Test 37: DataViewControl.xaml binds inner Grid MinWidth to TotalTableWidth for synchronized horizontal scroll",
                    dataViewXamlContent.Contains("MinWidth=\"{x:Bind ViewModel.DataPage.TotalTableWidth, Mode=OneWay}\""));

                // Test 38: DatabaseViewControl.xaml SchemaTree has explicit vertical scroll channel properties
                viewXamlContent = File.ReadAllText(viewXamlPath);
                Assert("Test 38: DatabaseViewControl.xaml SchemaTree has explicit scroll channel properties",
                    viewXamlContent.Contains("ScrollViewer.VerticalScrollBarVisibility=\"Auto\"") &&
                    viewXamlContent.Contains("ScrollViewer.VerticalScrollMode=\"Enabled\""));

                // Test 39: DatabaseTreeNode supports IsLoading property
                treeNodeData.IsLoading = true;
                Assert("Test 39: DatabaseTreeNode supports IsLoading observable property",
                    treeNodeData.IsLoading == true);

                // Test 40: DatabaseViewControl.xaml.cs does not auto-expand tables category node
                viewCsContent = File.ReadAllText(viewCsPath);
                Assert("Test 40: DatabaseViewControl.xaml.cs does not auto-expand tables category (tablesCatNode.IsExpanded = true removed)",
                    !viewCsContent.Contains("tablesCatNode.IsExpanded = true;"));

                // Test 41: DatabaseViewControl.xaml.cs configures TableCategoryContext with IsExpanded = false and HasUnrealizedChildren = true
                Assert("Test 41: DatabaseViewControl.xaml.cs configures TableCategoryContext with collapsed lazy loading",
                    viewCsContent.Contains("TableCategoryContext") &&
                    viewCsContent.Contains("tablesCatNode.HasUnrealizedChildren = true;") &&
                    viewCsContent.Contains("tablesCatNode.IsExpanded = false;"));

                // Test 42: DatabaseViewControl.xaml.cs implements SetChevronLoading with robust ProgressRing removal
                Assert("Test 42: DatabaseViewControl.xaml.cs implements SetChevronLoading with ProgressRing cleanup via Children.Remove",
                    viewCsContent.Contains("SetChevronLoading(tvi, true);") &&
                    viewCsContent.Contains("SetChevronLoading(tvi, false);") &&
                    viewCsContent.Contains("chevronGrid.Children.OfType<ProgressRing>()") &&
                    viewCsContent.Contains("chevronGrid.Children.Remove(ring)"));

                // Test 43: SchemaTree_Expanding explicitly sets args.Node.IsExpanded = true after realizing tables
                Assert("Test 43: SchemaTree_Expanding explicitly assigns args.Node.IsExpanded = true after realizing tables on first click",
                    viewCsContent.Contains("args.Node.IsExpanded = true;"));

                // Test 44: SchemaTree_ItemInvoked guards expansion with !dtn.IsLoading
                Assert("Test 44: SchemaTree_ItemInvoked guards expansion toggle with !dtn.IsLoading",
                    viewCsContent.Contains("if (!dtn.IsLoading)") &&
                    viewCsContent.Contains("node.IsExpanded = !node.IsExpanded;"));
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"[UNHANDLED EXCEPTION]: {ex}");
                Console.ResetColor();
                failCount++;
            }

            Console.WriteLine("=================================================");
            Console.WriteLine($"Summary: {passCount} passed, {failCount} failed.");
            Console.WriteLine("=================================================");

            return failCount == 0 ? 0 : 1;
        }
    }
}
