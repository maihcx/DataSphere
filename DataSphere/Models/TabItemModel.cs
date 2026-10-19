using System.ComponentModel;
using CommunityToolkit.Mvvm.ComponentModel;
using DataSphere.Utils;

namespace DataSphere.Models
{
    /// <summary>
    /// Represents an individual document or page tab displayed inside the window tab strip.
    /// </summary>
    public partial class TabItemModel : ObservableObject
    {
        /// <summary>
        /// Gets the unique identifier for this tab instance.
        /// </summary>
        public Guid Id { get; init; } = Guid.NewGuid();

        /// <summary>
        /// Gets or sets the display text shown on the tab header.
        /// </summary>
        [ObservableProperty]
        public partial string Title { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the localization resource key used to dynamically resolve and refresh the tab title.
        /// </summary>
        [ObservableProperty]
        public partial string? TitleKey { get; set; }

        /// <summary>
        /// Gets or sets the Segoe Fluent Icon glyph or symbol text displayed next to the tab title.
        /// </summary>
        [ObservableProperty]
        public partial string IconGlyph { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the concrete Page class type associated with this tab.
        /// </summary>
        [ObservableProperty]
        public partial Type? PageType { get; set; }

        /// <summary>
        /// Gets or sets the instantiated view or page element rendered in the main viewport.
        /// </summary>
        [ObservableProperty]
        public partial object? Content { get; set; }

        /// <summary>
        /// Gets or sets a value indicating whether the tab close button is enabled and interactive.
        /// </summary>
        [ObservableProperty]
        public partial bool IsClosable { get; set; } = true;

        /// <summary>
        /// Gets or sets a value indicating whether this tab is currently selected in the host window.
        /// </summary>
        [ObservableProperty]
        public partial bool IsSelected { get; set; }

        /// <summary>
        /// Gets or sets the current lifecycle state of this tab.
        /// </summary>
        [ObservableProperty]
        public partial TabLifecycleState State { get; set; } = TabLifecycleState.Created;

        /// <summary>
        /// Gets or sets optional arbitrary context data or ViewModel payload associated with the tab.
        /// </summary>
        public object? Tag { get; set; }

        /// <summary>
        /// Initializes a new instance of the <see cref="TabItemModel"/> class.
        /// </summary>
        public TabItemModel()
        {
            TranslationSource.Instance.PropertyChanged += OnCultureChanged;
        }

        private void OnCultureChanged(object? sender, PropertyChangedEventArgs e)
        {
            if (!string.IsNullOrEmpty(TitleKey))
            {
                Title = LanguageBase.GetLangValue(TitleKey);
            }
        }

        partial void OnTitleKeyChanged(string? value)
        {
            if (!string.IsNullOrEmpty(value))
            {
                Title = LanguageBase.GetLangValue(value);
            }
        }
    }
}
