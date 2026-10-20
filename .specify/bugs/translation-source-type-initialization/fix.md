# Bug Fix: TranslationSource TypeInitializationException on App Launch

- **Slug**: translation-source-type-initialization
- **Fixed**: 2026-10-20T08:27:00+07:00
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Resolved the fatal `System.TypeInitializationException` during application startup caused by static field initialization order in `TranslationSource`. Dedicated synchronization primitives and instance storage collections now initialize prior to the lazy singleton instance, preventing null reference monitor acquisition during XAML resource creation.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `DataSphere/Utils/Translations.cs` | modified | Reordered static fields (`syncLock`, `activeInstances`, `currentCulture`) before `Lazy<TranslationSource> instance`, and updated locks to synchronize on `syncLock`. |

## Diff Highlights

```csharp
<<<<
-        private static readonly TranslationSource instance = new TranslationSource();
-
-        public static TranslationSource Instance => instance;
-
-        private static CultureInfo currentCulture = CultureInfo.CurrentUICulture;
-        private static readonly List<WeakReference<TranslationSource>> activeInstances = new();
====
+        private static readonly object syncLock = new();
+        private static readonly List<WeakReference<TranslationSource>> activeInstances = new();
+        private static CultureInfo currentCulture = CultureInfo.CurrentUICulture;
+        private static readonly Lazy<TranslationSource> instance = new(() => new TranslationSource());
+
+        public static TranslationSource Instance => instance.Value;
>>>>
```

## Tests Added or Updated

- `scratch/TestTranslationSource` — Executed standalone verification checking both direct constructor instantiation (`new TranslationSource()`, as executed by XAML `App.xaml`) and singleton resolution (`TranslationSource.Instance`). Both succeeded with exit code 0.

## Local Verification

- Commands run:
  - `dotnet build DataSphere\DataSphere.csproj -c Debug` → 0 Warning(s), 0 Error(s)
  - `dotnet run --project scratch\TestTranslationSource\TestTranslationSource.csproj` → `Constructor instantiation succeeded: True`, `Singleton access succeeded: True`, `All checks passed!`
- Manual checks: Verified `TranslationSource` static initialization order and thread synchronization invariants.

## Deviations from Assessment

None.

## Follow-ups

- Run `/speckit-bug-test slug=translation-source-type-initialization` to record test verification.
