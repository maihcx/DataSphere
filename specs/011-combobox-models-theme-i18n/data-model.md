# Data Model: Dedicated ComboBox Models and Dynamic i18n Theme Architecture

**Feature Branch**: `011-combobox-models-theme-i18n`
**Date**: 2026-10-21
**Spec**: [spec.md](./spec.md) | **Research**: [research.md](./research.md)

## Domain Enums

### `AppThemeMode`

Defines the application visual theme mode.

```csharp
namespace DataSphere.Models
{
    /// <summary>
    /// Defines the application color theme mode.
    /// </summary>
    public enum AppThemeMode
    {
        /// <summary>
        /// Synchronizes with the current Windows system theme (Light or Dark).
        /// </summary>
        Default,

        /// <summary>
        /// Forces the application into Light theme mode.
        /// </summary>
        Light,

        /// <summary>
        /// Forces the application into Dark theme mode.
        /// </summary>
        Dark
    }
}
```

---

### `AppBackdropMode`

Defines the window background backdrop material.

```csharp
namespace DataSphere.Models
{
    /// <summary>
    /// Defines the window backdrop visual rendering material.
    /// </summary>
    public enum AppBackdropMode
    {
        /// <summary>
        /// Dynamic translucent Mica material matching the desktop wallpaper.
        /// </summary>
        Mica,

        /// <summary>
        /// Tabbed Mica Alt background material optimized for document/tabbed applications.
        /// </summary>
        Tabbed,

        /// <summary>
        /// Acrylic material with desktop blur.
        /// </summary>
        Acrylic,

        /// <summary>
        /// Solid opaque background rendering using standard page background theme brushes.
        /// </summary>
        Solid
    }
}
```

---

## Domain Models

### `ThemeOptionItem`

Represents a selectable theme option in the settings dropdown.

```csharp
namespace DataSphere.Models
{
    /// <summary>
    /// Represents a selectable application color theme option in settings.
    /// </summary>
    public partial class ThemeOptionItem : ObservableObject
    {
        /// <summary>
        /// Gets the underlying domain theme mode.
        /// </summary>
        public AppThemeMode Mode { get; init; }

        /// <summary>
        /// Gets or sets the localized display name of the theme mode.
        /// </summary>
        [ObservableProperty]
        public partial string DisplayName { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the localized descriptive subtitle explaining the theme characteristics.
        /// </summary>
        [ObservableProperty]
        public partial string Description { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the Segoe Fluent Icon glyph representing the theme mode.
        /// </summary>
        public string IconGlyph { get; init; } = "\uE790";

        /// <summary>
        /// Returns the display name of this theme option.
        /// </summary>
        public override string ToString() => DisplayName;

        /// <summary>
        /// Compares equality based on the domain <see cref="Mode"/>.
        /// </summary>
        public override bool Equals(object? obj) => obj is ThemeOptionItem other && Mode == other.Mode;

        /// <summary>
        /// Computes the hash code based on the domain <see cref="Mode"/>.
        /// </summary>
        public override int GetHashCode() => (int)Mode;
    }
}
```

---

### `BackdropOptionItem`

Represents a selectable backdrop material option in the settings dropdown.

```csharp
namespace DataSphere.Models
{
    /// <summary>
    /// Represents a selectable Windows system backdrop material option in personalization settings.
    /// </summary>
    public partial class BackdropOptionItem : ObservableObject
    {
        /// <summary>
        /// Gets the underlying domain backdrop mode.
        /// </summary>
        public AppBackdropMode Mode { get; init; }

        /// <summary>
        /// Gets the string key used for backward-compatible storage persistence.
        /// </summary>
        public string Key => Mode.ToString();

        /// <summary>
        /// Gets or sets the localized display name of the backdrop material.
        /// </summary>
        [ObservableProperty]
        public partial string DisplayName { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the localized summary description of the backdrop material.
        /// </summary>
        [ObservableProperty]
        public partial string Summary { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the Segoe Fluent Icon glyph representing the material.
        /// </summary>
        public string IconGlyph { get; init; } = "\uE790";

        /// <summary>
        /// Returns the display name of this backdrop option.
        /// </summary>
        public override string ToString() => DisplayName;

        /// <summary>
        /// Compares equality based on the domain <see cref="Mode"/>.
        /// </summary>
        public override bool Equals(object? obj) => obj is BackdropOptionItem other && Mode == other.Mode;

        /// <summary>
        /// Computes the hash code based on the domain <see cref="Mode"/>.
        /// </summary>
        public override int GetHashCode() => (int)Mode;
    }
}
```

---

### `LanguageOptionItem`

Represents a selectable language option in the settings dropdown.

```csharp
namespace DataSphere.Models
{
    /// <summary>
    /// Represents a selectable application display language option.
    /// </summary>
    public partial class LanguageOptionItem : ObservableObject
    {
        /// <summary>
        /// Gets the standard BCP-47 / ISO language code (e.g. "en", "vi").
        /// </summary>
        public string Code { get; init; } = string.Empty;

        /// <summary>
        /// Gets or sets the localized native display name of the language (e.g. "Tiếng Việt", "English").
        /// </summary>
        [ObservableProperty]
        public partial string NativeName { get; set; } = string.Empty;

        /// <summary>
        /// Gets or sets the English name of the language.
        /// </summary>
        [ObservableProperty]
        public partial string EnglishName { get; set; } = string.Empty;

        /// <summary>
        /// Returns the native display name of this language option.
        /// </summary>
        public override string ToString() => NativeName;

        /// <summary>
        /// Compares equality based on the language <see cref="Code"/>.
        /// </summary>
        public override bool Equals(object? obj) => obj is LanguageOptionItem other && string.Equals(Code, other.Code, StringComparison.OrdinalIgnoreCase);

        /// <summary>
        /// Computes the hash code based on the language <see cref="Code"/>.
        /// </summary>
        public override int GetHashCode() => StringComparer.OrdinalIgnoreCase.GetHashCode(Code);
    }
}
```

---

## State Transitions & Persistence Mapping

| Domain Mode | Persistent Key (`UserDataStore`) | WinUI 3 XAML / Composition Mapping |
|-------------|-----------------------------------|-----------------------------------|
| `AppThemeMode.Default` | `"Default"` | `fe.RequestedTheme = ElementTheme.Default;` |
| `AppThemeMode.Light` | `"Light"` | `fe.RequestedTheme = ElementTheme.Light;` |
| `AppThemeMode.Dark` | `"Dark"` | `fe.RequestedTheme = ElementTheme.Dark;` |
| `AppBackdropMode.Mica` | `"Mica"` | `win.SystemBackdrop = new MicaBackdrop { Kind = MicaKind.Base };` |
| `AppBackdropMode.Tabbed` | `"Tabbed"` | `win.SystemBackdrop = new MicaBackdrop { Kind = MicaKind.BaseAlt };` |
| `AppBackdropMode.Acrylic` | `"Acrylic"` | `win.SystemBackdrop = new DesktopAcrylicBackdrop();` |
| `AppBackdropMode.Solid` | `"Solid"` | `win.SystemBackdrop = null; rootPanel.ClearValue(Panel.BackgroundProperty);` |
