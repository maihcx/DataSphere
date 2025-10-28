using DataSphere.Models.Database;

namespace DataSphere.Services.Database
{
    public interface IDatabaseConnection
    {
        bool IsConnected { get; }

        Task<bool> ConnectAsync();

        Task DisconnectAsync();

        Task<bool> TestConnectionAsync();

        Task<ObservableCollection<Table>?> GetAllTablesAsync(string dbName);

        Task<Table?> GetTableInfoAsync(string tableName);

        Task<ObservableCollection<Models.Database.DatabaseInfo>?> GetAllDatabasesAsync();
    }
}
