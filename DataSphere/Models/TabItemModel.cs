using System.ComponentModel;
using CommunityToolkit.Mvvm.ComponentModel;
using DataSphere.Utils;

namespace DataSphere.Models
{
    /// <summary>
    /// Represents an individual document or page tab displayed inside the window tab strip.
    /// </summary>
    public partial class TabItemModel : ObservableObject, IDisposable
    {
        /// <summary>
        /// Gets the unique identifier for this tab instance.
        /// </summary>
        public Guid Id { get; init; } = Guid.NewGuid();

        /// <summary>
        /// Gets or sets the 1-based instance index for multiple tabs sharing the same page type and title key.
        /// </summary>
        [ObservableProperty]
        public partial int InstanceIndex { get; set; } = 1;

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
        [NotifyPropertyChangedFor(nameof(CanSleep))]
        public partial bool IsClosable { get; set; } = true;

        /// <summary>
        /// Gets or sets a value indicating whether this tab is currently selected in the host window.
        /// </summary>
        [ObservableProperty]
        [NotifyPropertyChangedFor(nameof(CanSleep))]
        public partial bool IsSelected { get; set; }

        /// <summary>
        /// Gets or sets the UTC timestamp when this tab was last activated or interacted with.
        /// </summary>
        [ObservableProperty]
        public partial DateTime LastActiveTime { get; set; } = DateTime.UtcNow;

        /// <summary>
        /// Gets or sets a value indicating whether this tab is in the sleeping state to conserve memory.
        /// </summary>
        [ObservableProperty]
        [NotifyPropertyChangedFor(nameof(CanSleep))]
        [NotifyPropertyChangedFor(nameof(SleepingOpacity))]
        public partial bool IsSleeping { get; set; }

        /// <summary>
        /// Gets the visual opacity for this tab header, slightly muted when sleeping to visually indicate low-power state.
        /// </summary>
        public double SleepingOpacity => IsSleeping ? 0.65 : 1.0;

        /// <summary>
        /// Gets or sets a value indicating whether this tab contains uncommitted or unsaved modifications.
        /// </summary>
        [ObservableProperty]
        [NotifyPropertyChangedFor(nameof(CanSleep))]
        public partial bool HasUnsavedChanges { get; set; }

        /// <summary>
        /// Gets a value indicating whether this tab is eligible to enter the sleeping state.
        /// </summary>
        public bool CanSleep => IsClosable &&
                                PageType?.Name != "HomePage" &&
                                !HasUnsavedChanges &&
                                !IsSelected &&
                                (Content is not Services.Contracts.ISleepableTabContent sleepable || sleepable.CanSleep);

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
            UpdateFormattedTitle();
        }

        partial void OnTitleKeyChanged(string? value)
        {
            UpdateFormattedTitle();
        }

        partial void OnInstanceIndexChanged(int value)
        {
            UpdateFormattedTitle();
        }

        partial void OnIsSelectedChanged(bool value)
        {
            if (value)
            {
                LastActiveTime = DateTime.UtcNow;
                if (State != TabLifecycleState.Closing && State != TabLifecycleState.Disposed)
                {
                    State = TabLifecycleState.Active;
                }
            }
            else
            {
                if (State == TabLifecycleState.Active)
                {
                    State = IsSleeping ? TabLifecycleState.Sleeping : TabLifecycleState.Background;
                }
            }
        }

        partial void OnIsSleepingChanged(bool value)
        {
            if (value && State != TabLifecycleState.Closing && State != TabLifecycleState.Disposed)
            {
                State = TabLifecycleState.Sleeping;
            }
            else if (!value && State == TabLifecycleState.Sleeping)
            {
                State = IsSelected ? TabLifecycleState.Active : TabLifecycleState.Background;
            }
        }

        private void UpdateFormattedTitle()
        {
            if (!string.IsNullOrEmpty(TitleKey))
            {
                string baseText = LanguageBase.GetLangValue(TitleKey) ?? TitleKey;
                Title = InstanceIndex > 1 ? $"{baseText} ({InstanceIndex})" : baseText;
            }
        }

        /// <summary>
        /// Returns the display title for this tab instance.
        /// </summary>
        /// <returns>The tab header title string.</returns>
        public override string ToString() => Title;

        /// <summary>
        /// Releases managed event handlers and associated content resources.
        /// </summary>
        public void Dispose()
        {
            TranslationSource.Instance.PropertyChanged -= OnCultureChanged;
            if (Content is IDisposable disposable)
            {
                disposable.Dispose();
            }
        }
    }
}
