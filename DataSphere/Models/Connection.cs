namespace DataSphere.Models
{
    public class Connection : INotifyPropertyChanged
    {
        public event PropertyChangedEventHandler? PropertyChanged;

        private string? Name
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Name));
            }
        }

        private DatabaseType? Type
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Type));
            }
        }

        private string? Host
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Host));
            }
        }

        private string? User
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(User));
            }
        }

        private string? Password
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Password));
            }
        }
        private int? Port
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Port));
            }
        }

        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
