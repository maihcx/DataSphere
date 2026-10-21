using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Data;

namespace DataSphere.Helpers
{
    /// <summary>
    /// Converts a boolean value to its logical inverse.
    /// </summary>
    public class InverseBooleanConverter : IValueConverter
    {
        /// <inheritdoc/>
        public object Convert(object value, Type targetType, object parameter, string language)
        {
            if (value is bool b)
            {
                return !b;
            }
            return true;
        }

        /// <inheritdoc/>
        public object ConvertBack(object value, Type targetType, object parameter, string language)
        {
            if (value is bool b)
            {
                return !b;
            }
            return false;
        }
    }

    /// <summary>
    /// Converts a boolean value to a <see cref="Visibility"/> enumeration value.
    /// </summary>
    public class BooleanToVisibilityConverter : IValueConverter
    {
        /// <inheritdoc/>
        public object Convert(object value, Type targetType, object parameter, string language)
        {
            if (value is bool b && b)
            {
                return Visibility.Visible;
            }
            return Visibility.Collapsed;
        }

        /// <inheritdoc/>
        public object ConvertBack(object value, Type targetType, object parameter, string language)
        {
            return value is Visibility v && v == Visibility.Visible;
        }
    }

    /// <summary>
    /// Converts a boolean value to an inverted <see cref="Visibility"/> enumeration value.
    /// </summary>
    public class InverseBooleanToVisibilityConverter : IValueConverter
    {
        /// <inheritdoc/>
        public object Convert(object value, Type targetType, object parameter, string language)
        {
            if (value is bool b && b)
            {
                return Visibility.Collapsed;
            }
            return Visibility.Visible;
        }

        /// <inheritdoc/>
        public object ConvertBack(object value, Type targetType, object parameter, string language)
        {
            return value is Visibility v && v == Visibility.Collapsed;
        }
    }

    /// <summary>
    /// Converts an object reference to a <see cref="Visibility"/> enumeration value based on nullability.
    /// By default, returns <see cref="Visibility.Visible"/> when the object is null (useful for empty-state placeholders),
    /// and <see cref="Visibility.Collapsed"/> when non-null.
    /// Supports the "invert" or "inverse" parameter to reverse this logic.
    /// </summary>
    public class NullToVisibilityConverter : IValueConverter
    {
        /// <inheritdoc/>
        public object Convert(object? value, Type targetType, object? parameter, string language)
        {
            bool isNull = value == null || (value is string s && string.IsNullOrEmpty(s));
            bool invert = parameter is string p && (p.Equals("invert", StringComparison.OrdinalIgnoreCase) || p.Equals("inverse", StringComparison.OrdinalIgnoreCase));

            if (invert)
            {
                return isNull ? Visibility.Collapsed : Visibility.Visible;
            }

            return isNull ? Visibility.Visible : Visibility.Collapsed;
        }

        /// <inheritdoc/>
        public object ConvertBack(object? value, Type targetType, object? parameter, string language)
        {
            throw new NotSupportedException();
        }
    }

    /// <summary>
    /// Converts an object reference to a <see cref="Visibility"/> enumeration value, returning <see cref="Visibility.Visible"/>
    /// when the object is non-null, and <see cref="Visibility.Collapsed"/> when null.
    /// </summary>
    public class NotNullToVisibilityConverter : IValueConverter
    {
        /// <inheritdoc/>
        public object Convert(object? value, Type targetType, object? parameter, string language)
        {
            bool isNull = value == null || (value is string s && string.IsNullOrEmpty(s));
            return isNull ? Visibility.Collapsed : Visibility.Visible;
        }

        /// <inheritdoc/>
        public object ConvertBack(object? value, Type targetType, object? parameter, string language)
        {
            throw new NotSupportedException();
        }
    }

    /// <summary>
    /// Preserves full four-corner <see cref="CornerRadius"/> values for pill-shaped controls, overriding top-only filtering.
    /// </summary>
    public class FullCornerRadiusConverter : IValueConverter
    {
        /// <inheritdoc/>
        public object Convert(object? value, Type targetType, object? parameter, string language)
        {
            if (value is CornerRadius cr)
            {
                return cr;
            }
            if (value is double d)
            {
                return new CornerRadius(d);
            }
            return new CornerRadius(16);
        }

        /// <inheritdoc/>
        public object ConvertBack(object? value, Type targetType, object? parameter, string language)
        {
            throw new NotSupportedException();
        }
    }
}
