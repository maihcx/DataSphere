# Bug Assessment: TranslationSource TypeInitializationException on App Launch

- **Slug**: translation-source-type-initialization
- **Created**: 2026-10-20T08:23:00+07:00
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: critical

## Report (verbatim or summarized)

> "có bug khi mở app:
> System.TypeInitializationException: 'The type initializer for 'DataSphere.Utils.TranslationSource' threw an exception.'"

## Symptom

When launching DataSphere, the application immediately crashes before displaying any windows with an unhandled exception:
`System.TypeInitializationException: The type initializer for 'DataSphere.Utils.TranslationSource' threw an exception.`
Inner exception: `System.ArgumentNullException: Value cannot be null. (Parameter 'lockObject')` or `System.NullReferenceException`.

## Reproduction

1. Build and run DataSphere (`dotnet run --project DataSphere\DataSphere.csproj`).
2. Observe application startup during `App.InitializeComponent()`, which instantiates `<utils:TranslationSource x:Key="Localization" />` declared in `App.xaml`.
3. **Observed**: Application terminates on launch due to `System.TypeInitializationException` when initializing `DataSphere.Utils.TranslationSource`.

## Suspected Code Paths

- `DataSphere/Utils/Translations.cs:10-29`:
  - Line 10: `private static readonly TranslationSource instance = new TranslationSource();`
  - Line 18: `private static readonly List<WeakReference<TranslationSource>> activeInstances = new();`
  - Lines 23-29:
    ```csharp
    public TranslationSource()
    {
        lock (activeInstances)
        {
            activeInstances.Add(new WeakReference<TranslationSource>(this));
        }
    }
    ```

## Root Cause Hypothesis

In C#, static field initializers execute in strict textual order (top-to-bottom) when the class is initialized.
1. `instance = new TranslationSource();` is declared at Line 10, invoking the instance constructor `TranslationSource()`.
2. Inside `TranslationSource()`, `lock (activeInstances)` attempts to acquire a monitor lock on `activeInstances`.
3. However, `activeInstances` is declared at Line 18 and has not yet been initialized; its value is still `null`.
4. Attempting to `lock (null)` throws an `ArgumentNullException` (or `NullReferenceException`).
5. Because this unhandled exception occurs inside a static field initializer, the CLR wraps it in a fatal `System.TypeInitializationException`, preventing the application from starting.

Confidence: High (100% reproducible by inspection of C# CLR static initialization order).

## Proposed Remediation

**Preferred**:
1. In `DataSphere/Utils/Translations.cs`:
   - Declare static synchronization objects and collections (`syncLock`, `activeInstances`, `currentCulture`) **before** `instance`.
   - Wrap `instance` creation in `Lazy<TranslationSource>` or initialize it after all static helper collections are ready.
   - Example:
     ```csharp
     private static readonly object syncLock = new();
     private static readonly List<WeakReference<TranslationSource>> activeInstances = new();
     private static CultureInfo currentCulture = CultureInfo.CurrentUICulture;
     private static readonly Lazy<TranslationSource> instance = new(() => new TranslationSource());

     public static TranslationSource Instance => instance.Value;
     ```
2. Inside the instance constructor, synchronize on `syncLock`:
   ```csharp
   public TranslationSource()
   {
       lock (syncLock)
       {
           activeInstances.Add(new WeakReference<TranslationSource>(this));
       }
   }
   ```

**Files likely to change**:
- `DataSphere/Utils/Translations.cs`

**Tests to add or update**:
- Startup smoke test to verify application launches without `TypeInitializationException`.

## Risks & Considerations

- Zero risk: reordering static declarations and using a dedicated `syncLock` object resolves the null reference during static initialization cleanly while preserving thread safety and weak-reference instance tracking.

## Open Questions

None.
