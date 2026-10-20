using DataSphere.Models;
using DataSphere.Services.Database.Connection;
using DataSphere.Services.Database.Interface;

namespace DataSphere.Services.Database
{
    /// <summary>
    /// Factory responsible for instantiating database connection providers matching the specified database engine type.
    /// </summary>
    public static class DatabaseConnectionFactory
    {
        /// <summary>
        /// Creates an active <see cref="IDatabaseConnection"/> instance corresponding to the connection model engine type.
        /// </summary>
        /// <param name="model">The connection configuration parameters.</param>
        /// <returns>An initialized database connection provider.</returns>
        /// <exception cref="ArgumentNullException">Thrown when <paramref name="model"/> is null.</exception>
        /// <exception cref="NotSupportedException">Thrown when the specified engine type is unsupported.</exception>
        public static IDatabaseConnection? Create(ConnectionModel model)
        {
            if (model == null)
            {
                throw new ArgumentNullException(nameof(model));
            }

            if (model.Type == null)
            {
                throw new NotSupportedException("Database type cannot be null.");
            }

            switch (model.Type.Value)
            {
                case DatabaseType.MySql:
                case DatabaseType.MariaDB:
                    return new MySqlDatabaseConnection(model);

                case DatabaseType.PostgreSql:
                    throw new NotSupportedException("PostgreSQL query execution engine integration is currently in progress. Please use MySQL or MariaDB.");

                default:
                    throw new NotSupportedException($"Database type '{model.Type.Value}' is not supported.");
            }
        }
    }
}
