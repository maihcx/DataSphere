// This Source Code Form is subject to the terms of the MIT License.
// If a copy of the MIT was not distributed with this file, You can obtain one at https://opensource.org/licenses/MIT.
// Copyright (C) Leszek Pomianowski and WPF UI Contributors.
// All Rights Reserved.

namespace DataSphere.Models;

public class NavigationCard : INotifyPropertyChanged
{
    private string? _nameKey;
    private string? _descriptionKey;

    public string NameKey
    {
        get => _nameKey ?? string.Empty;
        init
        {
            _nameKey = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(Name));
        }
    }

    public string DescriptionKey
    {
        get => _descriptionKey ?? string.Empty;
        init
        {
            _descriptionKey = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(Description));
        }
    }

    public string? Name => string.IsNullOrEmpty(NameKey)
        ? string.Empty
        : TranslationSource.Instance[NameKey];

    public string? Description => string.IsNullOrEmpty(DescriptionKey)
        ? string.Empty
        : TranslationSource.Instance[DescriptionKey];

    public SymbolRegular Icon { get; init; }

    public Type? PageType { get; init; }

    public event PropertyChangedEventHandler? PropertyChanged;

    public NavigationCard()
    {
        TranslationSource.Instance.PropertyChanged += (s, e) =>
        {
            OnPropertyChanged(nameof(Name));
            OnPropertyChanged(nameof(Description));
        };
    }

    protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}