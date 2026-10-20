namespace DataSphere.Utils
{
    /// <summary>
    /// Provides dynamic localized string resource resolution and notifies bindings of culture changes.
    /// Exposes an indexer <c>this[string key]</c> allowing XAML bindings such as:
    /// <c>{Binding [KeyName], Source={StaticResource Localization}, Mode=OneWay}</c>.
    /// </summary>
    public class TranslationSource : INotifyPropertyChanged
    {
        private static readonly object syncLock = new();
        private static readonly List<WeakReference<TranslationSource>> activeInstances = new();
        private static CultureInfo currentCulture = CultureInfo.CurrentUICulture;
        private static readonly Lazy<TranslationSource> instance = new(() => new TranslationSource());

        /// <summary>
        /// Gets the singleton instance of the translation source.
        /// </summary>
        public static TranslationSource Instance => instance.Value;

        /// <summary>
        /// Initializes a new instance of the <see cref="TranslationSource"/> class and registers it for culture notifications.
        /// </summary>
        public TranslationSource()
        {
            lock (syncLock)
            {
                activeInstances.Add(new WeakReference<TranslationSource>(this));
            }
        }

        /// <summary>
        /// Gets the localized string resource for the given key via <see cref="LanguageBase.GetLangValue(string, object[])"/>.
        /// </summary>
        /// <param name="key">The resource key name.</param>
        /// <returns>The resolved localized string or the key itself if not found.</returns>
        public string? this[string key] => LanguageBase.GetLangValue(key);

        /// <summary>
        /// Gets or sets the active UI culture, raising PropertyChanged to update bindings across all instances.
        /// </summary>
        public CultureInfo CurrentCulture
        {
            get => currentCulture;
            set
            {
                if (!Equals(currentCulture, value))
                {
                    currentCulture = value;
                    NotifyAllInstances();
                }
            }
        }

        private static void NotifyAllInstances()
        {
            lock (syncLock)
            {
                for (int i = activeInstances.Count - 1; i >= 0; i--)
                {
                    if (activeInstances[i].TryGetTarget(out var target))
                    {
                        target.RaisePropertyChanged();
                    }
                    else
                    {
                        activeInstances.RemoveAt(i);
                    }
                }
            }
        }

        private void RaisePropertyChanged()
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(string.Empty));
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs("Item[]"));
        }

        /// <summary>
        /// Occurs when the culture changes and localized strings need to be re-evaluated.
        /// </summary>
        public event PropertyChangedEventHandler? PropertyChanged;
    }

    /// <summary>
    /// Helper utilities for application language management and culture synchronization.
    /// </summary>
    public static class LanguageBase
    {
        /// <summary>
        /// Gets the list of supported cultures in the application.
        /// </summary>
        public static List<CultureInfo> SupportedLanguages { get; } = new List<CultureInfo>
        {
            new CultureInfo("en"),
            new CultureInfo("vi")
        };

        /// <summary>
        /// Delegate for language change event handlers.
        /// </summary>
        /// <param name="language">Two-letter ISO language name.</param>
        public delegate void LanguageChangedEventHandler(string language);

        /// <summary>
        /// Occurs when the application language changes.
        /// </summary>
        public static event LanguageChangedEventHandler? LanguageChanged;

        /// <summary>
        /// Retrieves the list of available languages formatted as selectable items.
        /// </summary>
        /// <returns>Collection of <see cref="LanguageItem"/> entries.</returns>
        public static ObservableCollection<LanguageItem> GetLanguageItems()
        {
            ObservableCollection<LanguageItem> languageItems = new ObservableCollection<LanguageItem>();

            foreach (var item in SupportedLanguages)
            {
                languageItems.Add(new LanguageItem()
                {
                    Code = item.TwoLetterISOLanguageName,
                    NativeName = item.NativeName,
                    EnglishName = item.EnglishName,
                });
            }

            return languageItems;
        }

        /// <summary>
        /// Sets the current application display language and persists user preference.
        /// </summary>
        /// <param name="language">Two-letter language code (e.g., "en", "vi").</param>
        public static void SetLanguage(string language)
        {
            TranslationSource.Instance.CurrentCulture = new CultureInfo(language);
            UserDataStore.SetValue("Language", language);
            LanguageChanged?.Invoke(language);
        }

        /// <summary>
        /// Reads the persisted language preference from the data store with fallback to current UI culture.
        /// </summary>
        /// <returns>Configured CultureInfo.</returns>
        public static CultureInfo GetSetupLanguage()
        {
            try
            {
                var langCode = UserDataStore.GetValue<string>("Language");
                if (!string.IsNullOrWhiteSpace(langCode))
                {
                    var matchedCulture = SupportedLanguages.FirstOrDefault(
                        c => c.TwoLetterISOLanguageName.Equals(langCode, StringComparison.OrdinalIgnoreCase));
                    if (matchedCulture != null)
                    {
                        return matchedCulture;
                    }

                    return new CultureInfo(langCode);
                }
            }
            catch
            {
                // Fall back if stored culture code is invalid
            }

            var currentUi = CultureInfo.CurrentUICulture;
            var defaultCulture = SupportedLanguages.FirstOrDefault(
                c => c.TwoLetterISOLanguageName.Equals(currentUi.TwoLetterISOLanguageName, StringComparison.OrdinalIgnoreCase));

            return defaultCulture ?? SupportedLanguages.First();
        }

        /// <summary>
        /// Gets the currently active CultureInfo.
        /// </summary>
        /// <returns>Current culture.</returns>
        public static CultureInfo GetCurrentLanguage()
        {
            return TranslationSource.Instance.CurrentCulture;
        }

        /// <summary>
        /// Gets the current language formatted as a <see cref="LanguageItem"/>.
        /// </summary>
        /// <returns>Current language model.</returns>
        public static LanguageItem GetCurrentLanguageItem()
        {
            var currentLang = GetCurrentLanguage();
            return new LanguageItem()
            {
                Code = currentLang.TwoLetterISOLanguageName,
                NativeName = currentLang.NativeName,
                EnglishName = currentLang.EnglishName,
            };
        }

        /// <summary>
        /// Retrieves a localized string with optional format arguments.
        /// </summary>
        /// <param name="key">Resource key.</param>
        /// <param name="args">Format arguments.</param>
        /// <returns>Formatted localized string.</returns>
        public static string GetLangValue(string key, params object[] args)
        {
            if (string.IsNullOrEmpty(key))
            {
                return string.Empty;
            }

            string? raw = Resources.Locales.String.ResourceManager.GetString(
                key,
                TranslationSource.Instance.CurrentCulture
            );

            // Graceful fallback to invariant/English culture if key is not found in the active culture
            if (raw == null && !Equals(TranslationSource.Instance.CurrentCulture, CultureInfo.InvariantCulture))
            {
                raw = Resources.Locales.String.ResourceManager.GetString(key, CultureInfo.InvariantCulture);
            }

            if (raw == null)
            {
                return key;
            }

            if (args == null || args.Length == 0)
            {
                return raw;
            }

            return string.Format(raw, args);
        }
    }
}
