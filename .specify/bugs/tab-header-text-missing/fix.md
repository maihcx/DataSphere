# Bug Fix: Missing Tab Header Text After Tab Memory Saver Changes

- **Slug**: `tab-header-text-missing`
- **Fixed**: 2026-10-23T09:27:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

---

## Summary

Fixed an issue where dynamic workspace tab headers failed to display their title text because `StringToVisibilityConverter` collapsed the header `ContentPresenter` whenever `TabViewItem.Header` was a compound UI container (`StackPanel`) instead of a string. Updated `StringToVisibilityConverter` to safely support any non-null object or `UIElement`, and implemented `TabItemModel.ToString()` to ensure accessibility and UI Automation reflect the human-readable tab title.

---

## Changes

| File | Change | Notes |
|---|---|---|
| `DataSphere/Helpers/Converters.cs` | Modified | Updated `StringToVisibilityConverter.Convert` to return `Visibility.Visible` for non-null objects/UIElements and check whitespace on strings. |
| `DataSphere/Models/TabItemModel.cs` | Modified | Added `override string ToString() => Title;` with US English XML doc comments for accessibility and automation inspection. |

---

## Diff Highlights

### `DataSphere/Helpers/Converters.cs`
```csharp
    public class StringToVisibilityConverter : IValueConverter
    {
        /// <inheritdoc/>
        public object Convert(object? value, Type targetType, object? parameter, string language)
        {
            if (value is string s)
            {
                return string.IsNullOrWhiteSpace(s) ? Visibility.Collapsed : Visibility.Visible;
            }
            return value != null ? Visibility.Visible : Visibility.Collapsed;
        }

        /// <inheritdoc/>
        public object ConvertBack(object? value, Type targetType, object? parameter, string language)
            => throw new NotSupportedException();
    }
```

### `DataSphere/Models/TabItemModel.cs`
```csharp
        /// <summary>
        /// Returns the display title for this tab instance.
        /// </summary>
        /// <returns>The tab header title string.</returns>
        public override string ToString() => Title;
```

---

## Tests Added or Updated

- `scripts/diagnose-tab-header-missing.ps1`: Automated UI Automation inspection on desktop `WinSta0\default` asserting that `Child Text elements in TabItem` is `>= 1`, tab width expands to fit text (`148x34`), and `Text.Name` matches the localized tab title (`"Cơ sở dữ liệu"`).

---

## Local Verification

- **Full Solution Build**: `dotnet build DataSphere\DataSphere.csproj -c Debug` -> **0 Error(s), 0 Warning(s)** in 13.31s.
- **Live Desktop Verification (`WinSta0\default`)**:
  - `TabItem[1]` width increased from `68x34` (collapsed icon-only) to `148x34`.
  - Child text element count in `TabItem[1]` restored from `0` to `1` (`Text: Name='Cơ sở dữ liệu' Rect=72x16`).
  - DirectComposition capture `01_reproduced_missing_header_text.png` confirms header title text is rendered sharply between the icon and close button.

---

## Deviations from Assessment

None. The preferred remediation was applied exactly as proposed.

---

## Follow-ups

- Proceed to `/speckit-bug-test slug=tab-header-text-missing` for formal verification and recording in `test.md`.
