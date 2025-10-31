namespace DataSphere.Models.Database
{
    public class ConnectionRoot : INotifyPropertyChanged
    {
        public event PropertyChangedEventHandler? PropertyChanged;

        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }

        public ConnectionModel? Connection {
            get
            {
                return field;
            }
            set
            {
                field = value;
                OnPropertyChanged(nameof(Connection));
                OnPropertyChanged(nameof(DisplayName));
            }
        }

        public ObservableCollection<DatabaseInfo> Databases {
            get
            {
                return field;
            }
            set
            {
                field = value;
                OnPropertyChanged(nameof(Databases));
            }
        } = new();

        public string DisplayName {
            get
            {
                return Connection?.Name ?? string.Empty;
            }
        }

        public bool IsExpanded
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(IsExpanded));
            }
        }
    }
}
