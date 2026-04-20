using System;
using System.Collections.Generic;
using System.Text;
using System.Windows.Controls;
using System.Xml;

namespace DataSphere.Utils
{
    public enum TextBoxValidationType
    {
        None,
        NotEmpty,
        NumberOnly,
        Custom
    }

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

    public class TextBoxValidation
    {
        private readonly Dictionary<string, TextBoxValidationObject> validationList = new();

        private readonly Dictionary<string, List<string>> _errors = new();

        public bool HasErrors => _errors.Any();

        public IEnumerable<string> GetErrors(string fieldName) => _errors.TryGetValue(fieldName, out var errs) ? errs : Enumerable.Empty<string>();

        public event Action<string>? OnErrorsChanged;

        public void AddValidation(string field, Func<string> valueGetter, TextBoxValidationType type, Func<string, bool>? custom = null)
        {
            validationList[field] = new TextBoxValidationObject(type, valueGetter, custom);
        }

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
