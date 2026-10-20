using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace DataSphere.Models.Database
{
    /// <summary>
    /// Represents a database (schema) in the MySQL server, 
    /// including metadata such as name, size, collation, and contained tables.
    /// </summary>
    public class DatabaseInfo : INotifyPropertyChanged
    {
        /// <summary>
        /// Occurs when a property value changes.
        /// </summary>
        public event PropertyChangedEventHandler? PropertyChanged;

        /// <summary>
        /// Initializes a new instance of the <see cref="DatabaseInfo"/> class.
        /// </summary>
        public DatabaseInfo()
        {
            Tables = new ObservableCollection<Table>()
            {
                new()
                {
                    Name = "Loading...",
                    Schema = "LoadingHolder"
                }
            };

            Tables.CollectionChanged += (s, e) =>
            {
                OnPropertyChanged(nameof(Tables));
            };
        }

        /// <summary>
        /// Gets or sets the name of the database schema.
        /// </summary>
        public string Name
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Name));
            }
        }

        /// <summary>
        /// Gets or sets the default character set of the database.
        /// </summary>
        public string Charset
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Charset));
            }
        }

        /// <summary>
        /// Gets or sets the default collation model of the database.
        /// </summary>
        public CollationModel Collation
        {
            get => field ?? new CollationModel();
            set
            {
                field = value;
                OnPropertyChanged(nameof(Collation));
            }
        }

        /// <summary>
        /// Gets or sets the estimated total storage size in bytes.
        /// </summary>
        public long? SizeInBytes
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(SizeInBytes));
            }
        }

        /// <summary>
        /// Gets or sets the count of tables contained in this schema.
        /// </summary>
        public int TableCount
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(TableCount));
            }
        } = 0;

        /// <summary>
        /// Gets or sets schema-level comments or notes.
        /// </summary>
        public string? Comment
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Comment));
            }
        }

        /// <summary>
        /// Gets or sets a value indicating whether child table definitions have been loaded from the server.
        /// </summary>
        public bool IsTablesLoaded
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(IsTablesLoaded));
            }
        } = false;

        /// <summary>
        /// Gets or sets a value indicating whether this node is expanded in the explorer tree.
        /// </summary>
        public bool IsExpanded
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(IsExpanded));
            }
        } = false;

        /// <summary>
        /// Gets a value indicating whether a dummy child placeholder exists for lazy loading.
        /// </summary>
        public bool HasDummyChild => true;

        /// <summary>
        /// Gets or sets the collection of tables loaded under this database.
        /// </summary>
        public ObservableCollection<Table>? Tables { get; set; }

        /// <summary>
        /// Returns a display summary string for this database.
        /// </summary>
        public override string ToString()
        {
            string sizeInfo = SizeInBytes.HasValue
                ? $" ~{(SizeInBytes.Value / 1024.0 / 1024.0):0.##} MB"
                : string.Empty;

            return $"{Name} ({TableCount} tables){sizeInfo}";
        }

        /// <summary>
        /// Raises the PropertyChanged event.
        /// </summary>
        /// <param name="propertyName">The name of the changed property.</param>
        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }

        /// <summary>
        /// Gets child categories for tables, views, procedures, functions, triggers, and events.
        /// </summary>
        public IEnumerable<DatabaseCategory> Categories
        {
            get
            {
                yield return new DatabaseCategory
                {
                    NameKey = "dbinf_tables_title",
                    IconGlyph = "\uE8B7",
                    Items = Tables ?? new ObservableCollection<Table>(),
                    Parent = this
                };

                // Additional categories:
                yield return new DatabaseCategory
                {
                    NameKey = "dbinf_views_title",
                    IconGlyph = "\uE890",
                    Items = new ObservableCollection<object>(),
                    Parent = this
                };

                yield return new DatabaseCategory
                {
                    NameKey = "dbinf_sps_title",
                    IconGlyph = "\uE943",
                    Items = new ObservableCollection<object>(),
                    Parent = this
                };

                yield return new DatabaseCategory
                {
                    NameKey = "dbinf_fncs_title",
                    IconGlyph = "\uF168",
                    Items = new ObservableCollection<object>(),
                    Parent = this
                };

                yield return new DatabaseCategory
                {
                    NameKey = "dbinf_triggers_title",
                    IconGlyph = "\uE713",
                    Items = new ObservableCollection<object>(),
                    Parent = this
                };

                yield return new DatabaseCategory
                {
                    NameKey = "dbinf_events_title",
                    IconGlyph = "\uE787",
                    Items = new ObservableCollection<object>(),
                    Parent = this
                };
            }
        }
    }
}
