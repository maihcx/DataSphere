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
    public class DatabaseInfo : INotifyPropertyChanged
    {
        public event PropertyChangedEventHandler? PropertyChanged;

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

        public string Name
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Name));
            }
        }

        public string Charset
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Charset));
            }
        }

        public string Collation
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Collation));
            }
        }

        public long? SizeInBytes
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(SizeInBytes));
            }
        }

        public int TableCount
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(TableCount));
            }
        } = 0;

        public string? Comment
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Comment));
            }
        }

        public bool IsTablesLoaded
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(IsTablesLoaded));
            }
        } = false;

        public bool IsExpanded
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(IsExpanded));
            }
        } = false;

        public bool HasDummyChild => true;

        public ObservableCollection<Table>? Tables { get; set; }

        public override string ToString()
        {
            string sizeInfo = SizeInBytes.HasValue
                ? $" ~{(SizeInBytes.Value / 1024.0 / 1024.0):0.##} MB"
                : string.Empty;

            return $"{Name} ({TableCount} tables){sizeInfo}";
        }

        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }

        public IEnumerable<DatabaseCategory> Categories
        {
            get
            {
                yield return new DatabaseCategory
                {
                    NameKey = "dbinf_tables_title",
                    Icon = new SymbolIcon() { Symbol = SymbolRegular.BookDatabase20 },
                    Items = Tables ?? new ObservableCollection<Table>(),
                    Parent = this
                };

                // Các nhóm khác bạn có thể thêm sau khi có dữ liệu thực:
                yield return new DatabaseCategory
                {
                    NameKey = "dbinf_views_title",
                    Icon = new SymbolIcon() { Symbol = SymbolRegular.ContentView20 },
                    Items = new ObservableCollection<object>(),
                    Parent = this
                };

                yield return new DatabaseCategory
                {
                    NameKey = "dbinf_sps_title",
                    Icon = new SymbolIcon() { Symbol = SymbolRegular.Code20 },
                    Items = new ObservableCollection<object>(),
                    Parent = this
                };

                yield return new DatabaseCategory
                {
                    NameKey = "dbinf_fncs_title",
                    Icon = new SymbolIcon() { Symbol = SymbolRegular.AppFolder20 },
                    Items = new ObservableCollection<object>(),
                    Parent = this
                };

                yield return new DatabaseCategory
                {
                    NameKey = "dbinf_triggers_title",
                    Icon = new SymbolIcon() { Symbol = SymbolRegular.Settings20 },
                    Items = new ObservableCollection<object>(),
                    Parent = this
                };

                yield return new DatabaseCategory
                {
                    NameKey = "dbinf_events_title",
                    Icon = new SymbolIcon() { Symbol = SymbolRegular.CalendarLtr20 },
                    Items = new ObservableCollection<object>(),
                    Parent = this
                };
            }
        }
    }
}
