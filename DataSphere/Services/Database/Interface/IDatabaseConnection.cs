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

        Task<ObservableCollection<CollationModel>?> GetAllCollation();

        Task<CollationModel> GetDefCollation();

        Task<CollationModel> GetCollationInfo(string strCollation, CollationModel? collation = null);

        Task<ObservableCollection<DatabaseInfo>?> GetAllDatabasesAsync();

        Task<DataTable?> ExecuteQueryAsync(string sql);

        Task<DataTable?> ExecuteQueryAsync(ISqlBuilder builder);

        Task<bool> DatabaseExistsAsync(string dbname);

        Task CreateDatabase(DatabaseInfo databaseInfo);

        Task DropDatabase(DatabaseInfo databaseInfo);
    }
}
