namespace DataSphere.Models
{
    /// <summary>
    /// Represents the database engine category or catalog node type.
    /// </summary>
    public enum DatabaseType
    {
        /// <summary>
        /// Grouping folder in the connection catalog.
        /// </summary>
        Folder,

        /// <summary>
        /// MySQL database engine.
        /// </summary>
        MySql,

        /// <summary>
        /// MariaDB database engine.
        /// </summary>
        MariaDB,

        /// <summary>
        /// PostgreSQL database engine.
        /// </summary>
        PostgreSql
    }
}
