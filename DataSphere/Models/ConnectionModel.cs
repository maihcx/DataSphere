namespace DataSphere.Models
{
    public class ConnectionModel : INotifyPropertyChanged
    {
        public event PropertyChangedEventHandler? PropertyChanged;

        public string Name
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Name));
            }
        }

        public bool IsEditing
        {
            get => field;
            set 
            { 
                field = value; 
                OnPropertyChanged(nameof(IsEditing)); 
            }
        }

        public DatabaseType Type
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Type));
            }
        }

        public string Host
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Host));
            }
        }

        public string User
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(User));
            }
        }

        public string Password
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Password));
            }
        }
        public int Port
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Port));
            }
        }

        public SymbolIcon Icon
        {
            get
            {
                switch (Type)
                {
                    case DatabaseType.Folder:
                        return new SymbolIcon() { Symbol = SymbolRegular.Folder16 };

                    case DatabaseType.MySql:
                        return new SymbolIcon() { Symbol = SymbolRegular.Database16 };
                }
                return new SymbolIcon() { Symbol = SymbolRegular.QuestionCircle16 };
            }
        }

        public ObservableCollection<ConnectionModel>? Children
        {
            get => field;
            set 
            { 
                field = value; 
                OnPropertyChanged(); 
            }
        }

        public ObservableCollection<ContextAction> ContextMenuItems { get; set; } = new();

        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
