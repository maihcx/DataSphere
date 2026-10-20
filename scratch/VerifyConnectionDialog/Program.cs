using System;
using System.Linq;
using System.Xml.Linq;
using Microsoft.Extensions.DependencyInjection;
using DataSphere.Models;
using DataSphere.Services;
using DataSphere.Services.Contracts;
using DataSphere.Services.Database;
using DataSphere.ViewModels.Dialogs;

namespace VerifyConnectionDialog
{
    class Program
    {
        static int _passed = 0;
        static int _failed = 0;

        static void Assert(bool condition, string message)
        {
            if (condition)
            {
                Console.WriteLine($"[PASS] {message}");
                _passed++;
            }
            else
            {
                Console.WriteLine($"[FAIL] {message}");
                _failed++;
            }
        }

        static void Main(string[] args)
        {
            Console.WriteLine("=================================================");
            Console.WriteLine("Starting Multi-Window & Connection Dialog Tests");
            Console.WriteLine("=================================================");

            TestDatabaseTypesEnum();
            TestConnectionEditingViewModel();
            TestDatabaseConnectionFactory();
            TestWindowManagerActiveTracking();
            TestResxIntegrity();

            Console.WriteLine("=================================================");
            Console.WriteLine($"Summary: {_passed} passed, {_failed} failed.");
            Console.WriteLine("=================================================");

            if (_failed > 0)
            {
                Environment.Exit(1);
            }
        }

        static void TestDatabaseTypesEnum()
        {
            Assert(Enum.IsDefined(typeof(DatabaseType), "MySql"), "DatabaseType enum defines MySql");
            Assert(Enum.IsDefined(typeof(DatabaseType), "MariaDB"), "DatabaseType enum defines MariaDB");
            Assert(Enum.IsDefined(typeof(DatabaseType), "PostgreSql"), "DatabaseType enum defines PostgreSql");
        }

        static void TestConnectionEditingViewModel()
        {
            var vm = new ConnectionEditingViewModel();

            Assert(vm.AvailableDatabaseTypes.Count == 3, $"AvailableDatabaseTypes count is 3 (actual: {vm.AvailableDatabaseTypes.Count})");
            Assert(vm.AvailableDatabaseTypes.Any(t => t.Type == DatabaseType.MySql), "AvailableDatabaseTypes contains MySQL");
            Assert(vm.AvailableDatabaseTypes.Any(t => t.Type == DatabaseType.MariaDB), "AvailableDatabaseTypes contains MariaDB");
            Assert(vm.AvailableDatabaseTypes.Any(t => t.Type == DatabaseType.PostgreSql), "AvailableDatabaseTypes contains PostgreSQL");

            // Default selection is MySQL with port 3306
            Assert(vm.SelectedDatabaseType?.Type == DatabaseType.MySql, "Default SelectedDatabaseType is MySQL");
            Assert(vm.ConnectionPort == 3306, $"Default port is 3306 (actual: {vm.ConnectionPort})");

            // Switch to PostgreSQL -> port auto-adjusts to 5432
            var pgOption = vm.AvailableDatabaseTypes.First(t => t.Type == DatabaseType.PostgreSql);
            vm.SelectedDatabaseType = pgOption;
            Assert(vm.ConnectionPort == 5432, $"Port automatically changed to 5432 for PostgreSQL (actual: {vm.ConnectionPort})");

            // Switch back to MariaDB -> port auto-adjusts to 3306
            var mariaOption = vm.AvailableDatabaseTypes.First(t => t.Type == DatabaseType.MariaDB);
            vm.SelectedDatabaseType = mariaOption;
            Assert(vm.ConnectionPort == 3306, $"Port automatically changed to 3306 for MariaDB (actual: {vm.ConnectionPort})");

            // Verify ToConnectionModel assigns selected type and database
            vm.ConnectionName = "Test Production MariaDB";
            vm.ConnectionHost = "192.168.1.100";
            vm.ConnectionUser = "dbadmin";
            vm.ConnectionPassword = "secret";
            vm.ConnectionDatabase = "production_db";

            var model = vm.ToConnectionModel();
            Assert(model.Type?.Value == DatabaseType.MariaDB, "ToConnectionModel sets Type to MariaDB");
            Assert(model.Database == "production_db", $"ToConnectionModel sets Database correctly (actual: {model.Database})");
            Assert(model.Port == 3306, "ToConnectionModel sets Port to 3306");

            // Verify existing connection model editing initializes correctly
            var existingPg = new ConnectionModel
            {
                Name = "Localhost PostgreSQL",
                Host = "localhost",
                Port = 5432,
                User = "postgres",
                Type = new DatabaseTypes { Value = DatabaseType.PostgreSql },
                Database = "app_data"
            };

            var vmEdit = new ConnectionEditingViewModel(existingPg);
            Assert(vmEdit.SelectedDatabaseType?.Type == DatabaseType.PostgreSql, "ViewModel initializes SelectedDatabaseType from existing model");
            Assert(vmEdit.ConnectionPort == 5432, "ViewModel initializes port 5432 from existing model");
            Assert(vmEdit.ConnectionDatabase == "app_data", "ViewModel initializes Database name from existing model");
        }

        static void TestDatabaseConnectionFactory()
        {
            var mySqlModel = new ConnectionModel
            {
                Name = "MySQL Test",
                Host = "127.0.0.1",
                Port = 3306,
                User = "root",
                Type = new DatabaseTypes { Value = DatabaseType.MySql }
            };

            var mySqlConn = DatabaseConnectionFactory.Create(mySqlModel);
            Assert(mySqlConn != null, "DatabaseConnectionFactory returns connection for MySQL");

            var mariaModel = new ConnectionModel
            {
                Name = "MariaDB Test",
                Host = "127.0.0.1",
                Port = 3306,
                User = "root",
                Type = new DatabaseTypes { Value = DatabaseType.MariaDB }
            };

            var mariaConn = DatabaseConnectionFactory.Create(mariaModel);
            Assert(mariaConn != null, "DatabaseConnectionFactory returns connection for MariaDB");

            var pgModel = new ConnectionModel
            {
                Name = "PostgreSQL Test",
                Host = "127.0.0.1",
                Port = 5432,
                User = "postgres",
                Type = new DatabaseTypes { Value = DatabaseType.PostgreSql }
            };

            bool caughtPg = false;
            try
            {
                DatabaseConnectionFactory.Create(pgModel);
            }
            catch (NotSupportedException ex)
            {
                caughtPg = true;
                Assert(ex.Message.Contains("PostgreSQL"), "NotSupportedException contains informative PostgreSQL message");
            }
            Assert(caughtPg, "DatabaseConnectionFactory throws NotSupportedException for PostgreSQL pending driver integration");
        }

        static void TestWindowManagerActiveTracking()
        {
            var services = new Microsoft.Extensions.DependencyInjection.ServiceCollection();
            var sp = services.BuildServiceProvider();
            var wm = new WindowManager(sp);

            var session1 = new WindowSession { IsPrimary = true };
            var session2 = new WindowSession { IsPrimary = false };

            wm.RegisterWindow(session1);
            Assert(wm.ActiveWindowSession == session1, "ActiveWindowSession initializes to first registered window");

            wm.RegisterWindow(session2);
            Assert(wm.Windows.Count == 2, "WindowManager tracks 2 registered windows");

            // Deregister session1 -> ActiveWindowSession transitions to remaining window
            wm.UnregisterWindow(session1.WindowId);
            Assert(wm.ActiveWindowSession == session2, "ActiveWindowSession updates to remaining window upon deregistering active window");
        }

        static void TestResxIntegrity()
        {
            string resxPath = @"DataSphere\Resources\Locales\String.vi.resx";
            var doc = XDocument.Load(resxPath);
            var root = doc.Root;

            var dbTypeElem = root?.Elements("data").FirstOrDefault(e => e.Attribute("name")?.Value == "lbl_database_type");
            string? dbTypeVal = dbTypeElem?.Element("value")?.Value;
            Assert(dbTypeVal == "Loại cơ sở dữ liệu", $"lbl_database_type is correctly encoded (actual: '{dbTypeVal}')");
            Assert(!dbTypeVal!.Contains("Ã") && !dbTypeVal.Contains("áº¡"), "lbl_database_type has no Mojibake");

            var pgSocketElem = root?.Elements("data").FirstOrDefault(e => e.Attribute("name")?.Value == "msg_test_pg_socket");
            string? pgSocketVal = pgSocketElem?.Element("value")?.Value;
            Assert(pgSocketVal != null && pgSocketVal.Contains("PostgreSQL"), "msg_test_pg_socket contains PostgreSQL");
            Assert(!pgSocketVal!.Contains("Ã") && !pgSocketVal.Contains("áº£"), "msg_test_pg_socket has no Mojibake");
        }
    }
}
