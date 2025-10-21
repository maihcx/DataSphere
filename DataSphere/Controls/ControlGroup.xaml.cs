// This Source Code Form is subject to the terms of the MIT License.
// If a copy of the MIT was not distributed with this file, You can obtain one at https://opensource.org/licenses/MIT.
// Copyright (C) Leszek Pomianowski and WPF UI Contributors.
// All Rights Reserved.

namespace DataSphere.Controls;

[ContentProperty(nameof(ExampleContent))]
public class ControlGroup : Control
{
    public static readonly DependencyProperty HeaderTextProperty = DependencyProperty.Register(
        nameof(HeaderText),
        typeof(string),
        typeof(ControlGroup),
        new PropertyMetadata(null)
    );

    public static readonly DependencyProperty ExampleContentProperty = DependencyProperty.Register(
        nameof(ExampleContent),
        typeof(object),
        typeof(ControlGroup),
        new PropertyMetadata(null)
    );

    public static readonly DependencyProperty ExplainProperty = DependencyProperty.Register(
        nameof(Explain),
        typeof(string),
        typeof(ControlGroup),
        new PropertyMetadata(null)
    );

    public static readonly DependencyProperty ExplainSourceProperty = DependencyProperty.Register(
        nameof(ExplainSource),
        typeof(Uri),
        typeof(ControlGroup),
        new PropertyMetadata(
            null,
            static (o, args) => ((ControlGroup)o).OnExplainSourceChanged((Uri)args.NewValue)
        )
    );

    public static readonly DependencyProperty CsharpCodeProperty = DependencyProperty.Register(
        nameof(CsharpCode),
        typeof(string),
        typeof(ControlGroup),
        new PropertyMetadata(null)
    );

    public static readonly DependencyProperty CsharpCodeSourceProperty = DependencyProperty.Register(
        nameof(CsharpCodeSource),
        typeof(Uri),
        typeof(ControlGroup),
        new PropertyMetadata(
            null,
            static (o, args) => ((ControlGroup)o).OnCsharpCodeSourceChanged((Uri)args.NewValue)
        )
    );

    public string? HeaderText
    {
        get => (string)GetValue(HeaderTextProperty);
        set => SetValue(HeaderTextProperty, value);
    }

    public object? ExampleContent
    {
        get => GetValue(ExampleContentProperty);
        set => SetValue(ExampleContentProperty, value);
    }

    public string? Explain
    {
        get => (string)GetValue(ExplainProperty);
        set => SetValue(ExplainProperty, value);
    }

    public Uri? ExplainSource
    {
        get => (Uri)GetValue(ExplainSourceProperty);
        set => SetValue(ExplainSourceProperty, value);
    }

    public string? CsharpCode
    {
        get => (string)GetValue(CsharpCodeProperty);
        set => SetValue(CsharpCodeProperty, value);
    }

    public Uri? CsharpCodeSource
    {
        get => (Uri)GetValue(CsharpCodeSourceProperty);
        set => SetValue(CsharpCodeSourceProperty, value);
    }

    private void OnExplainSourceChanged(Uri uri)
    {
        Explain = LoadResource(uri);
    }

    private void OnCsharpCodeSourceChanged(Uri uri)
    {
        CsharpCode = LoadResource(uri);
    }

    private static string LoadResource(Uri uri)
    {
        try
        {
            if (Application.GetResourceStream(uri) is not { } steamInfo)
            {
                return string.Empty;
            }

            using StreamReader streamReader = new(steamInfo.Stream, Encoding.UTF8);

            return streamReader.ReadToEnd();
        }
        catch (Exception e)
        {
            Debug.WriteLine(e);
            return e.ToString();
        }
    }
}
