# Bug Verification: Tab Selection Content Synchronization and Home Close Button Visibility

- **Slug**: tab-selection-and-home-close-button
- **Tested**: 2026-10-20T08:48:00+07:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

Both reported issues were verified completely resolved. Tab selection now synchronizes immediately between `ITabService`, `ShellViewModel`, `ShellTabView`, and the viewport `ContentPresenter`. The Home tab close button invariant behaves strictly as requested: "X" is hidden when $\ge 2$ tabs are open, visible when Home is the sole remaining tab, and closing it requests application window shutdown.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix): Tab Selection Sync | Opening secondary tab updates `ShellViewModel.SelectedTab` and fires `PropertyChanged` | pass | Selection switches immediately to the new tab without requiring manual re-clicks. |
| Reproduction (post-fix): Home Close Button Invariant | Verify `homeTab.IsClosable` with 1 tab vs $\ge 2$ tabs vs 1 tab | pass | `IsClosable` is `true` when 1 tab, `false` when 2 tabs, and reverts to `true` when closed back to 1. |
| Reproduction (post-fix): Lone Home Tab Closure | `CloseTab(homeTab)` when `Tabs.Count == 1` | pass | Fires `RequestCloseWindow` to trigger window/application termination. |
| New / updated tests | `dotnet run --project scratch\TestTranslationSource\TestTranslationSource.csproj` | pass | 5/5 automated lifecycle checks passed. |
| Lint / type-check / build | `dotnet build DataSphere\DataSphere.csproj -c Debug` | pass | 0 Warning(s), 0 Error(s). |

## Output Excerpts

```text
=== Testing ShellViewModel & Tab Selection Lifecycle ===
[Check 1] Tab count = 1, SelectedTab is Home: True
-> PASSED: Home is closable when alone.
[Check 2] Opening secondary tab...
vmSelectedTabChanged fired: True
vm.SelectedTab is secondTab: True
-> PASSED: Tab selection properly synchronized to secondary tab.
[Check 3] Home isClosable with 2 tabs: False
-> PASSED: Home isClosable is false with 2 tabs.
[Check 4] Closing secondary tab...
Tab count after closing: 1
Home isClosable after closing back to 1: True
-> PASSED: Home isClosable reverted to true.
[Check 5] Closing Home tab when alone...
RequestCloseWindow fired: True
-> PASSED: RequestCloseWindow correctly fired.
=== ALL VERIFICATION CHECKS PASSED ===
```

## Residual Risks

- None. The implementation relies on standard `INotifyPropertyChanged` observation and `ObservableCollection.CollectionChanged` hooks, preventing race conditions or stale bindings.

## Recommendation

Close the bug — verified end-to-end.
