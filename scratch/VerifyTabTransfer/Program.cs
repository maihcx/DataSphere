using System;
using System.Linq;
using Microsoft.Extensions.DependencyInjection;
using DataSphere.Models;
using DataSphere.Services;
using DataSphere.Services.Contracts;

namespace VerifyTabTransfer
{
    class Program
    {
        static int Main(string[] args)
        {
            Console.WriteLine("=================================================");
            Console.WriteLine("Starting Multi-Window & Tab Transfer Verification Suite");
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
                // Test 1: Invariant - Primary window with 2 tabs must NEVER auto-close
                var primarySession = new WindowSession
                {
                    IsPrimary = true
                };
                var homeTab1 = new TabItemModel
                {
                    Title = "Home",
                    IsClosable = false
                };
                var dbTab1 = new TabItemModel
                {
                    Title = "Databases",
                    IsClosable = true
                };
                primarySession.AddTab(homeTab1);
                primarySession.AddTab(dbTab1);

                Assert("Test 1: Primary window with 2 tabs (Home + Content) must NOT auto-close",
                    !primarySession.CanAutoCloseOnTransfer());

                // Test 2: Invariant - Primary window with 1 tab must NEVER auto-close
                primarySession.Tabs.Remove(dbTab1);
                Assert("Test 2: Primary window with 1 tab (Home) must NOT auto-close",
                    !primarySession.CanAutoCloseOnTransfer());

                // Test 3: Invariant - Secondary window with 2 tabs (Home + Content) MUST auto-close on transfer
                var secondarySession = new WindowSession
                {
                    IsPrimary = false
                };
                var homeTab2 = new TabItemModel
                {
                    Title = "Home",
                    IsClosable = false
                };
                var settingsTab2 = new TabItemModel
                {
                    Title = "Settings",
                    IsClosable = true
                };
                secondarySession.AddTab(homeTab2);
                secondarySession.AddTab(settingsTab2);

                Assert("Test 3: Secondary window with 2 tabs (Home + Content) MUST auto-close on transfer",
                    secondarySession.CanAutoCloseOnTransfer());

                // Test 4: Invariant - Secondary window with 3 tabs must NOT auto-close on transfer
                var extraTab = new TabItemModel
                {
                    Title = "Extra",
                    IsClosable = true
                };
                secondarySession.AddTab(extraTab);
                Assert("Test 4: Secondary window with 3 tabs must NOT auto-close on transfer",
                    !secondarySession.CanAutoCloseOnTransfer());

                // Test 5: Invariant - Secondary window with 1 tab (Home) remaining MUST auto-close
                secondarySession.Tabs.Remove(extraTab);
                secondarySession.Tabs.Remove(settingsTab2);
                Assert("Test 5: Secondary window with only 1 tab (Home) remaining MUST auto-close",
                    secondarySession.CanAutoCloseOnTransfer());

                // Test 6: WindowManager Registration & Tab Transfer Verification
                var services = new ServiceCollection();
                services.AddSingleton<IWindowManager, WindowManager>();
                services.AddTransient<ITabService, TabService>();
                var serviceProvider = services.BuildServiceProvider();

                var windowManager = serviceProvider.GetRequiredService<IWindowManager>();

                var win1Session = new WindowSession
                {
                    IsPrimary = true
                };
                var win1Home = new TabItemModel { Title = "Home", IsClosable = false };
                var win1Settings = new TabItemModel { Title = "Settings", IsClosable = true };
                win1Session.AddTab(win1Home);
                win1Session.AddTab(win1Settings);
                windowManager.RegisterWindow(win1Session);

                var win2Session = new WindowSession
                {
                    IsPrimary = false
                };
                var win2Home = new TabItemModel { Title = "Home", IsClosable = false };
                var win2Db = new TabItemModel { Title = "Databases", IsClosable = true };
                win2Session.AddTab(win2Home);
                win2Session.AddTab(win2Db);
                windowManager.RegisterWindow(win2Session);

                Assert("Test 6: WindowManager registers both sessions",
                    windowManager.Windows.Count == 2);

                // Perform transfer of win2Db from win2Session to win1Session
                windowManager.TransferTab(win2Session.WindowId, win1Session.WindowId, win2Db, win1Session.Tabs.Count);

                Assert("Test 7: Transferred tab is added to target session",
                    win1Session.Tabs.Contains(win2Db));
                Assert("Test 8: Transferred tab is removed from source session",
                    !win2Session.Tabs.Contains(win2Db));
                Assert("Test 9: Target session SelectedTab is focused on transferred tab",
                    Equals(win1Session.SelectedTab, win2Db));
                Assert("Test 10: Target session tab count is 3 (Home, Settings, Databases)",
                    win1Session.Tabs.Count == 3);
                Assert("Test 11: Source secondary session has only Home left and meets auto-close criteria",
                    win2Session.Tabs.Count == 1 && win2Session.CanAutoCloseOnTransfer());

                // Test 12: Reverse transfer from Primary to Secondary does NOT auto-close Primary
                windowManager.TransferTab(win1Session.WindowId, win2Session.WindowId, win1Settings, win2Session.Tabs.Count);
                Assert("Test 12: Primary window never auto-closes even if down to only Home",
                    !win1Session.CanAutoCloseOnTransfer());
                Assert("Test 13: Primary window has only Home tab remaining and stays open",
                    win1Session.Tabs.Count == 2 && win1Session.IsPrimary);
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
