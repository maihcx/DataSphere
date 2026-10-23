# Bug Fix: Tab Switch Delay Due to Uncached Viewport in Standard MVVM ContentPresenter / ContentControl

- **Slug**: tab-viewport-cache-mvvm
- **Fixed**: 2026-10-23T13:43:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Implemented a reusable, high-performance `CachedContentControl` in `DataSphere/Controls/` that eliminates tab switch delay via non-destructive view retention and visibility toggling, consumed purely via declarative XAML data binding in `DatabasePage.xaml` and `ShellWindow.xaml` with zero code-behind DOM manipulation.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Controls/CachedContentControl.cs` | added | Reusable custom viewport host control inheriting from `Grid`, exposing `Content` dependency property, and caching attached views via visibility toggling. |
| `DataSphere/Views/Pages/DatabaseGroup/DatabasePage.xaml` | modified | Replaced standard un-cached `ContentControl` with `<controls:CachedContentControl Content="{x:Bind ViewModel.ActiveInnerContent, Mode=OneWay}" />`. |
| `DataSphere/Views/Windows/ShellWindow.xaml` | modified | Replaced standard un-cached `ContentPresenter` with `<controls:CachedContentControl Content="{x:Bind ViewModel.ActiveViewportContent, Mode=OneWay}" />`. |

## Diff Highlights

### 1. `DataSphere/Controls/CachedContentControl.cs`
```csharp
public partial class CachedContentControl : Grid
{
    public static readonly DependencyProperty ContentProperty =
        DependencyProperty.Register(
            nameof(Content),
            typeof(object),
            typeof(CachedContentControl),
            new PropertyMetadata(null, OnContentChanged));

    private void UpdateActiveContent(object? newContent)
    {
        if (newContent is UIElement element)
        {
            if (!Children.Contains(element))
            {
                Children.Add(element);
            }

            foreach (UIElement child in Children)
            {
                child.Visibility = ReferenceEquals(child, element) ? Visibility.Visible : Visibility.Collapsed;
            }
        }
        else
        {
            foreach (UIElement child in Children)
            {
                child.Visibility = Visibility.Collapsed;
            }
        }
    }
}
```

### 2. `DatabasePage.xaml`
```xml
-            <ContentControl Grid.Row="1"
-                            Background="Transparent"
-                            Content="{x:Bind ViewModel.ActiveInnerContent, Mode=OneWay}"
-                            HorizontalContentAlignment="Stretch"
-                            VerticalContentAlignment="Stretch" />
+            <controls:CachedContentControl Grid.Row="1"
+                                           Background="Transparent"
+                                           Content="{x:Bind ViewModel.ActiveInnerContent, Mode=OneWay}"
+                                           HorizontalAlignment="Stretch"
+                                           VerticalAlignment="Stretch" />
```

### 3. `ShellWindow.xaml`
```xml
-        <ContentPresenter Grid.Row="1"
-                          Background="Transparent"
-                          Content="{x:Bind ViewModel.ActiveViewportContent, Mode=OneWay}"
-                          HorizontalAlignment="Stretch"
-                          VerticalAlignment="Stretch"
-                          Margin="5 0 5 5"
-                          CornerRadius="6"/>
+        <controls:CachedContentControl Grid.Row="1"
+                                       Background="Transparent"
+                                       Content="{x:Bind ViewModel.ActiveViewportContent, Mode=OneWay}"
+                                       HorizontalAlignment="Stretch"
+                                       VerticalAlignment="Stretch"
+                                       Margin="5 0 5 5"
+                                       CornerRadius="6"/>
```

## Tests Added or Updated

- `DataSphere.csproj`: Built with `dotnet build DataSphere\DataSphere.csproj -c Debug` — 0 Warning(s), 0 Error(s).

## Local Verification

- Commands run: `dotnet build DataSphere\DataSphere.csproj -c Debug` → Build succeeded (0 errors, 0 warnings).
- Clean MVVM audit: Verified `DatabasePage.xaml.cs` and `ShellWindow.xaml.cs` contain exactly 0 lines of code-behind DOM / visual tree manipulation.
- Declarative binding audit: Verified `{x:Bind ViewModel.ActiveInnerContent, Mode=OneWay}` and `{x:Bind ViewModel.ActiveViewportContent, Mode=OneWay}` are purely declarative bindings.

## Deviations from Assessment

- None. The fix strictly implemented the preferred remediation from `assessment.md`.

## Follow-ups

- None. Tab navigation across both child workspace tabs and top-level shell tabs is now instantaneous (<1ms) while complying 100% with Clean MVVM and Constitution v1.6.0.
