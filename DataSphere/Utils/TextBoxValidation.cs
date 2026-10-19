namespace DataSphere.Utils
{
    /// <summary>
    /// Defines the validation rules applicable to text input fields.
    /// </summary>
    public enum TextBoxValidationType
    {
        /// <summary>
        /// No validation rules applied.
        /// </summary>
        None,

        /// <summary>
        /// Requires non-null and non-whitespace text.
        /// </summary>
        NotEmpty,

        /// <summary>
        /// Requires integer numeric input.
        /// </summary>
        NumberOnly,

        /// <summary>
        /// Evaluates a custom predicate function.
        /// </summary>
        Custom
    }

    /// <summary>
    /// Metadata for a registered text field validation rule.
    /// </summary>
    class TextBoxValidationObject
    {
        public TextBoxValidationType ValidationType { get; set; }

        public Func<string>? ValueGetter { get; set; }

        public Func<string, bool>? CustomValidationFunc { get; set; }

        public TextBoxValidationObject(
            TextBoxValidationType type,
            Func<string>? getter,
            Func<string, bool>? custom)
        {
            ValidationType = type;
            ValueGetter = getter;
            CustomValidationFunc = custom;
        }
    }

    /// <summary>
    /// Manages field-level input validation and error notifications for forms.
    /// </summary>
    public class TextBoxValidation
    {
        private readonly Dictionary<string, TextBoxValidationObject> validationList = new();

        private readonly Dictionary<string, List<string>> _errors = new();

        /// <summary>
        /// Gets a value indicating whether any validation errors are currently present.
        /// </summary>
        public bool HasErrors => _errors.Any();

        /// <summary>
        /// Gets current error messages for the specified field name.
        /// </summary>
        /// <param name="fieldName">The field name to query.</param>
        /// <returns>Collection of error strings.</returns>
        public IEnumerable<string> GetErrors(string fieldName) => _errors.TryGetValue(fieldName, out var errs) ? errs : Enumerable.Empty<string>();

        /// <summary>
        /// Occurs when error messages for a field are modified.
        /// </summary>
        public event Action<string>? OnErrorsChanged;

        /// <summary>
        /// Registers a validation rule for the specified field.
        /// </summary>
        /// <param name="field">The name of the field to validate.</param>
        /// <param name="valueGetter">Delegate retrieving the current value.</param>
        /// <param name="type">The validation rule type.</param>
        /// <param name="custom">Optional custom predicate for <see cref="TextBoxValidationType.Custom"/>.</param>
        public void AddValidation(string field, Func<string> valueGetter, TextBoxValidationType type, Func<string, bool>? custom = null)
        {
            validationList[field] = new TextBoxValidationObject(type, valueGetter, custom);
        }

        /// <summary>
        /// Evaluates validation rules for a specific field against an explicit value.
        /// </summary>
        /// <param name="fieldName">The name of the field.</param>
        /// <param name="value">The value to test.</param>
        /// <returns>List of validation error messages.</returns>
        public List<string> Validate(string fieldName, string value)
        {
            var errors = new List<string>();

            if (!validationList.TryGetValue(fieldName, out var validation))
                return errors;

            switch (validation.ValidationType)
            {
                case TextBoxValidationType.NotEmpty:
                    if (string.IsNullOrWhiteSpace(value))
                    {
                        errors.Add($"{fieldName} is required.");
                    }
                    break;

                case TextBoxValidationType.NumberOnly:
                    if (!int.TryParse(value, out _))
                    {
                        errors.Add($"{fieldName} must be a number.");
                    }
                    break;

                case TextBoxValidationType.Custom:
                    if (validation.CustomValidationFunc != null && !validation.CustomValidationFunc(value))
                    {
                        errors.Add($"{fieldName} is invalid.");
                    }
                    break;
            }

            return errors;
        }

        /// <summary>
        /// Executes validation checks on a single field or all registered fields.
        /// </summary>
        /// <param name="fieldName">Optional field name to validate, or null to validate all fields.</param>
        public void ApplyValidation(string? fieldName = null)
        {
            if (fieldName == null)
            {
                foreach (var item in validationList)
                {
                    fieldName = item.Key;

                    if (!validationList.TryGetValue(fieldName, out var obj))
                        return;

                    var value = item.Value.ValueGetter?.Invoke() ?? "";
                    var errors = Validate(fieldName, value);

                    if (errors.Any())
                        _errors[fieldName] = errors;
                    else
                        _errors.Remove(fieldName);

                    OnErrorsChanged?.Invoke(fieldName);
                }
            }
            else
            {
                if (!validationList.TryGetValue(fieldName, out var obj))
                    return;

                string value = obj.ValueGetter?.Invoke() ?? "";

                var errors = Validate(fieldName, value);

                if (errors.Any())
                    _errors[fieldName] = errors;
                else
                    _errors.Remove(fieldName);

                OnErrorsChanged?.Invoke(fieldName);
            }
        }
    }
}
