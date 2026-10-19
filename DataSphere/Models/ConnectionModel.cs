using System.Collections.ObjectModel;
using System.Collections.Specialized;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text.Json.Serialization;
using CommunityToolkit.Mvvm.Input;
using DataSphere.Utils;

namespace DataSphere.Models
{
    /// <summary>
    /// Represents a database connection configuration and hierarchical tree node.
    /// </summary>
    public class ConnectionModel : INotifyPropertyChanged
    {
        /// <summary>
        /// Occurs when a property value changes.
        /// </summary>
        public event PropertyChangedEventHandler? PropertyChanged;

        /// <summary>
        /// Gets or sets the display name of the connection.
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
        /// Gets or sets the unique encryption key/hash for this connection.
        /// </summary>
        public string Key
        {
            get 
            { 
                if (string.IsNullOrWhiteSpace(field))
                {
                    field = PasswordEncryptor.RandomHash();
                }
                return field;
            }
            set
            {
                field = value;
                OnPropertyChanged(nameof(Key));
            }
        }

        /// <summary>
        /// Gets or sets a value indicating whether inline renaming/editing is currently active.
        /// </summary>
        public bool IsEditing
        {
            get => field;
            set 
            { 
                field = value; 
                OnPropertyChanged(nameof(IsEditing)); 
            }
        }

        /// <summary>
        /// Gets or sets the database engine type category.
        /// </summary>
        public DatabaseTypes? Type
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Type));
            }
        }

        /// <summary>
        /// Gets or sets the server host name or IP address.
        /// </summary>
        public string Host
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Host));
            }
        }

        /// <summary>
        /// Gets or sets the authentication username.
        /// </summary>
        public string User
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(User));
            }
        }

        /// <summary>
        /// Gets or sets the encrypted connection password.
        /// </summary>
        public string Password
        {
            get => field ?? string.Empty;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Password));
            }
        }

        /// <summary>
        /// Gets or sets the network port number.
        /// </summary>
        public int Port
        {
            get => field;
            set
            {
                field = value;
                OnPropertyChanged(nameof(Port));
            }
        }

        /// <summary>
        /// Gets the Segoe Fluent Icon glyph representing this connection or folder node.
        /// </summary>
        [JsonIgnore]
        public string IconGlyph
        {
            get
            {
                switch (Type?.Value)
                {
                    case DatabaseType.Folder:
                        return "\uE838";

                    case DatabaseType.MySql:
                        return "\uE774";
                }
                return "\uE897";
            }
        }

        /// <summary>
        /// Gets or sets the parent folder node in the connection hierarchy.
        /// </summary>
        [JsonIgnore]
        public ConnectionModel? Parent {  get; set; }

        /// <summary>
        /// Gets or sets the child connection items under this node.
        /// </summary>
        public ObservableCollection<ConnectionModel> Children
        {
            get {
                if (field == null)
                {
                    field = new ObservableCollection<ConnectionModel>();
                    HookChildrenEvents(field);
                }
                return field;
            }
            set 
            { 
                if (field != null)
                {
                    field.CollectionChanged -= OnChildrenCollectionChanged;
                }

                field = value;
                HookChildrenEvents(field);
                OnPropertyChanged(); 
            }
        }

        /// <summary>
        /// Gets or sets the context menu actions available for this node.
        /// </summary>
        [JsonIgnore]
        public ObservableCollection<ContextAction>? ContextMenuItems { get; set; }

        /// <summary>
        /// Raises the PropertyChanged event for the specified property name and notifies children.
        /// </summary>
        /// <param name="propertyName">The name of the changed property.</param>
        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));

            if (Children != null && Children.Count > 0)
            {
                foreach (var child in Children)
                {
                    child.OnParentPropertyChanged(propertyName);
                }
            }
        }

        /// <summary>
        /// Handles notification propagation from parent properties to child nodes.
        /// </summary>
        /// <param name="propertyName">The name of the property that changed on the parent.</param>
        internal void OnParentPropertyChanged(string? propertyName)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs($"Parent.{propertyName}"));

            if (Children != null && Children.Count > 0)
            {
                foreach (var child in Children)
                {
                    child.OnParentPropertyChanged(propertyName);
                }
            }
        }

        /// <summary>
        /// Initializes runtime commands, contextual menus, and event handlers for the connection node.
        /// </summary>
        /// <param name="addConnectionCallback">Action executed when adding a new child connection.</param>
        /// <param name="removeConnectionCallback">Action executed when deleting this connection.</param>
        /// <param name="editConnectionCallback">Action executed when editing this connection properties.</param>
        /// <param name="startConnectionCallback">Action executed when establishing a database session.</param>
        public void InitializeRuntimeProperties(
            Action<ConnectionModel>? addConnectionCallback,
            Action<ConnectionModel>? removeConnectionCallback,
            Action<ConnectionModel>? editConnectionCallback,
            Action<ConnectionModel>? startConnectionCallback)
        {
            switch (Type?.Value)
            {
                case DatabaseType.Folder:
                    ContextMenuItems = new ObservableCollection<ContextAction>()
                    {
                        new ContextAction()
                        {
                            NameKey = "ctx_add_title",
                            SymbolKey = "\uE710",
                            Children = new ObservableCollection<ContextAction>()
                            {
                                new ContextAction()
                                {
                                    NameKey = "ctx_mysql_title",
                                    SymbolKey = "\uE774",
                                    Command = new RelayCommand(() =>
                                    {
                                        addConnectionCallback?.Invoke(this);
                                    })
                                }
                            }
                        },
                        new ContextAction()
                        {
                            NameKey = "ctx_rename_title",
                            SymbolKey = "\uE8AC",
                            Command = new RelayCommand<ConnectionModel>((param) =>
                            {
                                if (param != null)
                                {
                                    param.IsEditing = true;
                                }
                            }),
                            CommandParameter = this
                        },
                        new ContextAction()
                        {
                            NameKey = "ctx_delete_title",
                            SymbolKey = "\uE74D",
                            Command = new RelayCommand<ConnectionModel>((param) =>
                            {
                                if (param != null)
                                {
                                    removeConnectionCallback?.Invoke(param);
                                }
                            }),
                            CommandParameter = this
                        }
                    };
                    break;

                case DatabaseType.MySql:
                    ContextMenuItems = new ObservableCollection<ContextAction>()
                    {
                        new ContextAction()
                        {
                            NameKey = "ctx_opencnn_title",
                            SymbolKey = "\uE774",
                            Command = new RelayCommand<ConnectionModel>((param) =>
                            {
                                if (param != null)
                                {
                                    startConnectionCallback?.Invoke(param);
                                }
                            }),
                            CommandParameter = this
                        },
                        new ContextAction()
                        {
                            NameKey = "ctx_edit_title",
                            SymbolKey = "\uE70F",
                            Command = new RelayCommand<ConnectionModel>((param) =>
                            {
                                if (param != null)
                                {
                                    editConnectionCallback?.Invoke(param);
                                }
                            }),
                            CommandParameter = this
                        },
                        new ContextAction()
                        {
                            NameKey = "ctx_rename_title",
                            SymbolKey = "\uE8AC",
                            Command = new RelayCommand<ConnectionModel>((param) =>
                            {
                                if (param != null)
                                {
                                    param.IsEditing = true;
                                }
                            }),
                            CommandParameter = this
                        },
                        new ContextAction()
                        {
                            NameKey = "ctx_delete_title",
                            SymbolKey = "\uE74D",
                            Command = new RelayCommand<ConnectionModel>((param) =>
                            {
                                if (param != null)
                                {
                                    removeConnectionCallback?.Invoke(param);
                                }
                            }),
                            CommandParameter = this
                        }
                    };
                    break;
            }
        }

        private void HookChildrenEvents(ObservableCollection<ConnectionModel> collection)
        {
            collection.CollectionChanged += OnChildrenCollectionChanged;
        }

        private void OnChildrenCollectionChanged(object? sender, NotifyCollectionChangedEventArgs e)
        {
            if (e.NewItems != null)
            {
                foreach (ConnectionModel child in e.NewItems)
                {
                    child.Parent = this;
                }
            }

            if (e.OldItems != null)
            {
                foreach (ConnectionModel child in e.OldItems)
                {
                    if (child.Parent == this)
                    {
                        child.Parent = null;
                    }
                }
            }
        }
    }
}
