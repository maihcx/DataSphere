using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DataSphere.Models.Database
{
    public class DatabaseCategory : INotifyPropertyChanged
    {
        public event PropertyChangedEventHandler? PropertyChanged;

        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }

        public string NameKey
        {
            get
            {
                return field;
            }
            set
            {
                field = value;
                OnPropertyChanged(nameof(NameKey));
                OnPropertyChanged(nameof(Name));
            }
        } = string.Empty;

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
        }

        public SymbolIcon Icon
        {
            get
            {
                return field;
            }
            set
            {
                field = value;
                OnPropertyChanged(nameof(Icon));
            }
        } = new SymbolIcon() { Symbol = SymbolRegular.QuestionCircle16 };

        public IEnumerable Items 
        {
            get
            {
                return field;
            }
            set
            {
                field = value;
                OnPropertyChanged(nameof(Items));
            }
        } = new ObservableCollection<object>();

        public object? Parent {
            get
            {
                return field;
            }
            set
            {
                field = value;
                OnPropertyChanged(nameof(Parent));
            }
        }

        public DatabaseCategory()
        {
            TranslationSource.Instance.PropertyChanged += (s, e) =>
            {
                OnPropertyChanged(nameof(Name));
            };
        }
    }
}
