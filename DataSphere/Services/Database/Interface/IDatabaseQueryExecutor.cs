using System.Data;

namespace DataSphere.Services.Database.Interface
{
    public interface IDatabaseQueryExecutor
    {
        Task<DataTable?> ExecuteQueryAsync(string sql);

        Task<DataTable?> ExecuteQueryAsync(ISqlBuilder builder);
    }
}
