using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml.Linq;

namespace DataSphere.Models
{
    public class TabItemView : INotifyPropertyChanged
    {
        public event PropertyChangedEventHandler? PropertyChanged;

        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }

        public TabItemView()
        {
            TranslationSource.Instance.PropertyChanged += (s, e) =>
            {
                OnPropertyChanged(nameof(Header));
            };
        }

        public string? Header
        {
            get
            {
                if (string.IsNullOrEmpty(HeaderKey))
                {
                    return field ?? string.Empty;
                }
                return TranslationSource.Instance[HeaderKey];
            }
            set
            {
                field = value;
                OnPropertyChanged(nameof(Header));
            }
        }

        public string HeaderKey
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(HeaderKey));
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

        public object? Content { get; set; }

        public bool CanClose
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(CanClose));
            }
        } = true;
    }
}
