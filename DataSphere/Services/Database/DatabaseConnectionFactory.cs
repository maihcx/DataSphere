using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DataSphere.Services.Database
{
    public static class DatabaseConnectionFactory
    {
        public static IDatabaseConnection? Create(ConnectionModel model)
        {
            if (model.Type == null)
                throw new NotSupportedException($"Database type null is not supported."); ;

            switch (model.Type.Value)
            {
                case DatabaseType.MySql:
                    return new MySqlDatabaseConnection(model);

                default:
                    throw new NotSupportedException($"Database type '{model.Type.Value}' is not supported.");
            }
        }
    }
}
