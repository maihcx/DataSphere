using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DataSphere.Models.Database
{
    /// <summary>
    /// Represents a database (schema) in the MySQL server, 
    /// including metadata such as name, size, collation, and contained tables.
    /// </summary>
    public class DatabaseInfo
    {
        /// <summary>
        /// Gets or sets the database name.
        /// </summary>
        public required string Name { get; set; }

        /// <summary>
        /// Gets or sets the default character set used by this database.
        /// </summary>
        public string? Charset { get; set; }

        /// <summary>
        /// Gets or sets the default collation for this database.
        /// </summary>
        public string? Collation { get; set; }

        /// <summary>
        /// Gets or sets the total size of the database in bytes (approximate).
        /// </summary>
        public long? SizeInBytes { get; set; }

        /// <summary>
        /// Gets or sets the number of tables contained in this database.
        /// </summary>
        public int? TableCount { get; set; }

        /// <summary>
        /// Gets or sets an optional comment or description of the database.
        /// </summary>
        public string? Comment { get; set; }

        /// <summary>
        /// Gets or sets a collection of tables that belong to this database.
        /// May be populated lazily when needed.
        /// </summary>
        public ObservableCollection<Table>? Tables { get; set; }

        /// <summary>
        /// Returns a human-readable representation of the database.
        /// </summary>
        public override string ToString()
        {
            string sizeInfo = SizeInBytes.HasValue
                ? $" ~{(SizeInBytes.Value / 1024.0 / 1024.0):0.##} MB"
                : string.Empty;

            return $"{Name} ({TableCount ?? 0} tables){sizeInfo}";
        }
    }
}
