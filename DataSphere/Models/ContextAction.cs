using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DataSphere.Models
{
    public class ContextAction : INotifyPropertyChanged
    {
        public event PropertyChangedEventHandler? PropertyChanged;

        public string? Name
        {
            get
            {
                if (string.IsNullOrEmpty(NameKey))
                {
                   return field ?? string.Empty;

                }
                return TranslationSource.Instance[NameKey];
            }
            set
            {
                field = value;
                OnPropertyChanged(nameof(Name));
            }
        }

        public string NameKey
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Name));
                OnPropertyChanged(nameof(NameKey));
            }
        }

        public string Key
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Key));
            }
        }

        public ICommand? Command
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Command));
            }
        }

        public object? CommandParameter
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(CommandParameter));
            }
        }

        public SymbolIcon? Icon
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Icon));
            }
        }

        public bool IsEnabled
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(IsEnabled));
            }
        } = true;

        public ObservableCollection<ContextAction>? Children
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Children));
            }
        }

        public ContextAction()
        {
            TranslationSource.Instance.PropertyChanged += (s, e) =>
            {
                OnPropertyChanged(nameof(Name));
            };
        }

        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
