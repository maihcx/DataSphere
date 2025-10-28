namespace DataSphere.Models.Database
{
    /// <summary>
    /// Represents a database table with metadata and column information.
    /// </summary>
    public class Table
    {
        /// <summary>
        /// Gets or sets the name of the table.
        /// </summary>
        public required string Name { get; set; }

        /// <summary>
        /// Gets or sets the database schema that this table belongs to.
        /// For example: "public" in PostgreSQL or "dbo" in SQL Server.
        /// </summary>
        public required string Schema { get; set; }

        /// <summary>
        /// Gets or sets a Comment or comment about this table, if available.
        /// </summary>
        public string? Comment { get; set; }

        /// <summary>
        /// Gets or sets the list of columns that belong to this table.
        /// </summary>
        public List<Column> Columns { get; set; } = new();

        /// <summary>
        /// Gets or sets the primary key columns of the table.
        /// </summary>
        public List<string> PrimaryKeys { get; set; } = new();

        /// <summary>
        /// Gets or sets the list of foreign keys in the table.
        /// Each item can represent a foreign key constraint to another table.
        /// </summary>
        public List<ForeignKey> ForeignKeys { get; set; } = new();

        /// <summary>
        /// Gets or sets the total row count of the table.
        /// This property might be populated only when explicitly queried.
        /// </summary>
        public long? RowCount { get; set; }

        /// <summary>
        /// Returns a human-readable representation of the table.
        /// </summary>
        public override string ToString()
        {
            return $"{Schema}.{Name} ({Columns.Count} columns)";
        }
    }

    /// <summary>
    /// Represents a single column in a table.
    /// </summary>
    public class Column
    {
        public required string Name { get; set; }
        public required string DataType { get; set; }
        public bool IsNullable { get; set; }
        public bool IsPrimaryKey { get; set; }
        public string? DefaultValue { get; set; }
        public string? Comment { get; set; }

        public override string ToString() => $"{Name} ({DataType})";
    }

    /// <summary>
    /// Represents a foreign key relationship between two tables.
    /// </summary>
    public class ForeignKey
    {
        public required string Name { get; set; }
        public required string Column { get; set; }
        public required string ReferencedTable { get; set; }
        public required string ReferencedColumn { get; set; }

        public override string ToString() => $"{Name}: {Column} → {ReferencedTable}.{ReferencedColumn}";
    }
}
