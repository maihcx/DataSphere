using DataSphere.Models.Database;
using System.Data;

namespace DataSphere.Services.Database.Interface
{
    public interface IDatabaseConnection
    {
        bool IsConnected { get; }

        Task<bool> ConnectAsync();

        Task DisconnectAsync();

        Task<bool> TestConnectionAsync();

        Task<ObservableCollection<Table>?> GetAllTablesAsync(string dbName);

        Task<Table?> GetTableInfoAsync(string tableName);

        Task<ObservableCollection<DatabaseInfo>?> GetAllDatabasesAsync();

        Task<DataTable?> ExecuteQueryAsync(string sql);

        Task<DataTable?> ExecuteQueryAsync(ISqlBuilder builder);
    }
}
