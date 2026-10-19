using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text.Json.Serialization;
using System.Windows.Input;
using DataSphere.Utils;

namespace DataSphere.Models
{
    /// <summary>
    /// Represents an individual command item in contextual menus and command bars.
    /// </summary>
    public class ContextAction : INotifyPropertyChanged
    {
        /// <summary>
        /// Occurs when a property value changes.
        /// </summary>
        public event PropertyChangedEventHandler? PropertyChanged;

        /// <summary>
        /// Gets or sets the localized or raw display name of the context action.
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
            set
            {
                field = value;
                OnPropertyChanged(nameof(Name));
            }
        }

        /// <summary>
        /// Gets or sets the localization translation key for this action's title.
        /// </summary>
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

        /// <summary>
        /// Gets or sets the unique action identifier key.
        /// </summary>
        public string Key
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Key));
            }
        }

        /// <summary>
        /// Gets or sets the command executed when the user activates this action.
        /// </summary>
        public ICommand? Command
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Command));
            }
        }

        /// <summary>
        /// Gets or sets the parameter passed to the command.
        /// </summary>
        public object? CommandParameter
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(CommandParameter));
            }
        }

        /// <summary>
        /// Gets or sets the icon symbol glyph code for this action.
        /// </summary>
        public string? SymbolKey { get; set; }

        /// <summary>
        /// Gets the resolved Segoe Fluent icon glyph string for presentation.
        /// </summary>
        [JsonIgnore]
        public string IconGlyph => SymbolKey ?? "\uE897";

        /// <summary>
        /// Gets or sets a value indicating whether this context action is enabled and interactive.
        /// </summary>
        public bool IsEnabled
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(IsEnabled));
            }
        } = true;

        /// <summary>
        /// Gets or sets sub-menu child actions nested under this item.
        /// </summary>
        public ObservableCollection<ContextAction>? Children
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Children));
            }
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="ContextAction"/> class.
        /// </summary>
        public ContextAction()
        {
            TranslationSource.Instance.PropertyChanged += (s, e) =>
            {
                OnPropertyChanged(nameof(Name));
            };
        }

        /// <summary>
        /// Raises the PropertyChanged event for the specified property name.
        /// </summary>
        /// <param name="propertyName">The name of the changed property.</param>
        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
