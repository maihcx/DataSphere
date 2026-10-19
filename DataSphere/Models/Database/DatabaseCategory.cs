using System.Collections;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using DataSphere.Utils;

namespace DataSphere.Models.Database
{
    /// <summary>
    /// Represents a categorical group node in the database explorer tree (e.g. Tables, Views, Functions).
    /// </summary>
    public class DatabaseCategory : INotifyPropertyChanged
    {
        /// <summary>
        /// Occurs when a property value changes.
        /// </summary>
        public event PropertyChangedEventHandler? PropertyChanged;

        /// <summary>
        /// Raises the PropertyChanged event.
        /// </summary>
        /// <param name="propertyName">The name of the changed property.</param>
        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }

        /// <summary>
        /// Gets or sets the translation dictionary key for the category name.
        /// </summary>
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

        /// <summary>
        /// Gets the localized or raw display name of the category.
        /// </summary>
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

        /// <summary>
        /// Gets or sets the Segoe Fluent Icon glyph representing this category.
        /// </summary>
        public string IconGlyph
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(IconGlyph));
            }
        } = "\uE897";

        /// <summary>
        /// Gets or sets child database object items nested under this category.
        /// </summary>
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

        /// <summary>
        /// Gets or sets the parent node in the object explorer tree.
        /// </summary>
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

        /// <summary>
        /// Initializes a new instance of the <see cref="DatabaseCategory"/> class.
        /// </summary>
        public DatabaseCategory()
        {
            TranslationSource.Instance.PropertyChanged += (s, e) =>
            {
                OnPropertyChanged(nameof(Name));
            };
        }
    }
}
