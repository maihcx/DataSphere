using System.Collections.ObjectModel;
using DataSphere.Models;
using DataSphere.Services;
using DataSphere.Utils;

Console.WriteLine("==================================================");
Console.WriteLine("DataSphere Headless Verification: Connection Storage");
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
    // Test 1: PasswordEncryptor Encrypt and Decrypt Round-trip
    string plain = "SuperSecretPassword123!@#";
    string encrypted = PasswordEncryptor.Encrypt(plain);
    string decrypted = PasswordEncryptor.Decrypt(encrypted);
    Assert(!string.IsNullOrEmpty(encrypted) && encrypted != plain, "Test 1A: Encrypted password differs from plain text");
    Assert(decrypted == plain, "Test 1B: Decrypted password exactly matches original plain text");

    // Test 2: ConnectionStorageService Saves with Transparent Encryption
    var connections = new ObservableCollection<ConnectionModel>
    {
        new ConnectionModel
        {
            Name = "Local MySQL Dev",
            Host = "127.0.0.1",
            Port = 3306,
            User = "root",
            Password = "MyTestPassword_9999",
            Type = new DatabaseTypes { Value = DatabaseType.MySql }
        },
        new ConnectionModel
        {
            Name = "Team Folder",
            Type = new DatabaseTypes { Value = DatabaseType.Folder },
            Children = new ObservableCollection<ConnectionModel>
            {
                new ConnectionModel
                {
                    Name = "Staging MySQL",
                    Host = "staging.internal",
                    Port = 3306,
                    User = "staging_user",
                    Password = "StagingSecretPassword_4444",
                    Type = new DatabaseTypes { Value = DatabaseType.MySql }
                }
            }
        }
    };

    await ConnectionStorageService.SaveAsync(connections, delayMs: 0);
    Assert(File.Exists(ConnectionStorageService.ConfigFilePath), "Test 2A: connections.json created on disk");

    string jsonOnDisk = await File.ReadAllTextAsync(ConnectionStorageService.ConfigFilePath);
    Assert(!jsonOnDisk.Contains("MyTestPassword_9999"), "Test 2B: Root password NOT present in plain text on disk");
    Assert(!jsonOnDisk.Contains("StagingSecretPassword_4444"), "Test 2C: Nested child password NOT present in plain text on disk");

    // Test 3: ConnectionStorageService Loads and Decrypts Transparently
    var loaded = await ConnectionStorageService.LoadAsync();
    Assert(loaded.Count == 2, "Test 3A: Loaded collection has 2 root items");
    Assert(loaded[0].Name == "Local MySQL Dev", "Test 3B: Root connection name matches");
    Assert(loaded[0].Password == "MyTestPassword_9999", "Test 3C: Root connection password decrypted correctly in memory");
    Assert(loaded[1].Children.Count == 1, "Test 3D: Child folder contains 1 connection");
    Assert(loaded[1].Children[0].Password == "StagingSecretPassword_4444", "Test 3E: Nested child password decrypted correctly in memory");

    // Test 4: Corrupted connections.json Resilience
    string backupJson = jsonOnDisk;
    await File.WriteAllTextAsync(ConnectionStorageService.ConfigFilePath, "{ bad json corrupted content !!! }");
    var corruptedLoad = await ConnectionStorageService.LoadAsync();
    Assert(corruptedLoad != null && corruptedLoad.Count == 0, "Test 4A: Corrupted JSON returns empty collection without throwing");

    // Restore valid file
    await File.WriteAllTextAsync(ConnectionStorageService.ConfigFilePath, backupJson);

    // Test 5: TableDataPage TotalPages Calculation
    var page = new TableDataPage
    {
        TotalRecords = 250,
        PageSize = 100,
        CurrentPage = 1
    };
    Assert(page.TotalPages == 3, "Test 5A: TotalPages calculated correctly (250 / 100 = 3)");

    page.TotalRecords = 100;
    Assert(page.TotalPages == 1, "Test 5B: TotalPages calculated correctly (100 / 100 = 1)");

    page.TotalRecords = 0;
    Assert(page.TotalPages == 0, "Test 5C: TotalPages calculated correctly for 0 records");
}
catch (Exception ex)
{
    Console.ForegroundColor = ConsoleColor.Red;
    Console.WriteLine($"[EXCEPTION] Unexpected test error: {ex}");
    Console.ResetColor();
    failed++;
}

Console.WriteLine("==================================================");
Console.WriteLine($"RESULTS: {passed} PASSED, {failed} FAILED");
Console.WriteLine("==================================================");

return failed == 0 ? 0 : 1;
