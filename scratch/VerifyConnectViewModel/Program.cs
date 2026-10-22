using System;
using System.Collections.ObjectModel;
using System.Threading.Tasks;
using DataSphere.Models;
using DataSphere.Models.Database;
using DataSphere.Services.Contracts;
using DataSphere.Services.Database.Interface;
using DataSphere.ViewModels.Pages.DatabaseGroup;

namespace VerifyConnectViewModel
{
    class Program
    {
        static async Task Main(string[] args)
        {
            Console.WriteLine("==================================================");
            Console.WriteLine("DataSphere Verification: ConnectView Clean MVVM");
            Console.WriteLine("==================================================");

            int passed = 0;
            int failed = 0;

            void Assert(bool condition, string testName)
            {
                if (condition)
                {
                    Console.WriteLine($"[PASS] {testName}");
                    passed++;
                }
                else
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine($"[FAIL] {testName}");
                    Console.ResetColor();
                    failed++;
                }
            }

            try
            {
                var fakeDialog = new FakeDialogService();
                var vm = new ConnectControlViewModel(fakeDialog);

                // Test 1: IsFolder and IsConnection properties
                var conn = new ConnectionModel
                {
                    Name = "Test MySQL",
                    Type = new DatabaseTypes { Value = DatabaseType.MySql }
                };
                var folder = new ConnectionModel
                {
                    Name = "Test Folder",
                    Type = new DatabaseTypes { Value = DatabaseType.Folder }
                };

                Assert(!conn.IsFolder && conn.IsConnection, "Test 1A: MySQL connection has IsConnection=true and IsFolder=false");
                Assert(folder.IsFolder && !folder.IsConnection, "Test 1B: Folder node has IsFolder=true and IsConnection=false");

                // Test 2: StartRename command sets IsEditing
                conn.IsEditing = false;
                vm.StartRenameCommand.Execute(conn);
                Assert(conn.IsEditing, "Test 2: StartRenameCommand sets IsEditing=true");

                // Test 3: OpenConnectionCommand invokes callback for database, ignores folder
                ConnectionModel? openedConn = null;
                vm.OnOpenConnection = c => openedConn = c;

                vm.OpenConnectionCommand.Execute(folder);
                Assert(openedConn == null, "Test 3A: OpenConnectionCommand ignores folder nodes");

                vm.OpenConnectionCommand.Execute(conn);
                Assert(openedConn == conn, "Test 3B: OpenConnectionCommand invokes callback for database connection");

                // Test 4: EditConnectionCommand calls dialog service and updates model
                fakeDialog.ReturnConnectionOnEdit = new ConnectionModel
                {
                    Name = "Updated Name",
                    Host = "192.168.1.100",
                    Port = 3307,
                    User = "dbuser",
                    Password = "newpassword"
                };

                await vm.EditConnectionCommand.ExecuteAsync(conn);
                Assert(fakeDialog.EditDialogCalled, "Test 4A: EditConnectionCommand invoked IDialogService");
                Assert(conn.Name == "Updated Name" && conn.Port == 3307 && conn.Host == "192.168.1.100", "Test 4B: Model properties were successfully updated from dialog result");

                // Test 5: AddConnectionToFolderCommand
                fakeDialog.ReturnConnectionOnEdit = new ConnectionModel
                {
                    Name = "Child Connection",
                    Type = new DatabaseTypes { Value = DatabaseType.MySql }
                };
                await vm.AddConnectionToFolderCommand.ExecuteAsync(folder);
                Assert(folder.Children.Count == 1 && folder.Children[0].Name == "Child Connection", "Test 5: AddConnectionToFolderCommand appended child connection to folder");

                // Test 6: DeleteConnectionCommand removes node from tree after confirmation
                var childConn = folder.Children[0];
                await vm.DeleteConnectionCommand.ExecuteAsync(childConn);
                Assert(fakeDialog.ConfirmDialogCalled && folder.Children.Count == 0, "Test 6: DeleteConnectionCommand prompted confirmation and removed child node");

                // Test 7: ConnectionModel command delegation
                vm.ModelInitialize(conn);
                openedConn = null;
                conn.OpenCommand?.Execute(null);
                Assert(openedConn == conn, "Test 7A: ConnectionModel.OpenCommand delegates cleanly to OpenConnection");

                conn.IsEditing = false;
                conn.RenameCommand?.Execute(null);
                Assert(conn.IsEditing, "Test 7B: ConnectionModel.RenameCommand sets IsEditing=true");
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"[EXCEPTION] {ex}");
                Console.ResetColor();
                failed++;
            }

            Console.WriteLine("==================================================");
            Console.WriteLine($"Summary: {passed} PASSED, {failed} FAILED");
            Console.WriteLine("==================================================");

            if (failed > 0) Environment.Exit(1);
        }
    }

    class FakeDialogService : IDialogService
    {
        public ConnectionModel? ReturnConnectionOnEdit { get; set; }
        public bool ReturnConfirmation { get; set; } = true;
        public bool EditDialogCalled { get; set; }
        public bool ConfirmDialogCalled { get; set; }

        public Task<ConnectionModel?> ShowConnectionEditingDialogAsync(ConnectionModel? existing = null, object? xamlRoot = null)
        {
            EditDialogCalled = true;
            return Task.FromResult(ReturnConnectionOnEdit);
        }

        public Task<bool> ShowConfirmationDialogAsync(string titleKey, string messageKey, object[]? messageArgs = null, object? xamlRoot = null)
        {
            ConfirmDialogCalled = true;
            return Task.FromResult(ReturnConfirmation);
        }

        public Task<DatabaseInfo?> ShowDatabaseEditingDialogAsync(IDatabaseConnection connection, object? xamlRoot = null)
        {
            return Task.FromResult<DatabaseInfo?>(null);
        }
    }
}
