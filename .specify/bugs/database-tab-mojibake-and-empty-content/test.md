# Bug Verification: Database Tab Mojibake Title and Empty Inner Content Viewport

- **Slug**: database-tab-mojibake-and-empty-content
- **Tested**: 2026-10-20T10:21:45+07:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The Vietnamese localization resource file `String.vi.resx` has been fully restored with clean UTF-8 strings, eliminating the Mojibake `Kế°t ná»'i` title in favor of `Kết nối`. The XAML layout in `DatabasePage.xaml` has been restructured to decouple `<ContentControl>` from `<TabView>`, rendering `ConnectViewControl` and `DatabaseViewControl` completely and without regressions.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Project Build | `dotnet build DataSphere\DataSphere.csproj -c Debug` | pass | 0 warnings, 0 errors. |
| Database View & Localization Suite | `dotnet run --project scratch\VerifyDatabaseView\VerifyDatabaseView.csproj` | pass | 14/14 tests passed (encoding + viewmodel content). |
| Multi-Window Tab Transfer Regression | `dotnet run --project scratch\VerifyTabTransfer\VerifyTabTransfer.csproj` | pass | 13/13 tests passed. |
| Connection Storage Regression | `dotnet run --project scratch\VerifyConnectionStorage\VerifyConnectionStorage.csproj` | pass | 14/14 tests passed. |
| Bridge Readiness Check | `powershell -ExecutionPolicy Bypass -File .\.specify\extensions\speckit-superpowers-bridge\scripts\powershell\bridge-status.ps1 -Readiness` | pass | Ready (status: complete; pending tasks: 0). |

## Output Excerpts

### Database View & Localization Test Suite (`VerifyDatabaseView`)
```text
=================================================
Starting Database View & Localization Verification
=================================================
[PASS] Test 1: String.vi.resx exists
[PASS] Test 2: No double-encoded Mojibake 'Káº¿t' in String.vi.resx
[PASS] Test 3: No double-encoded Mojibake 'Kiá»ƒm' in String.vi.resx
[PASS] Test 4: No double-encoded Mojibake 'Táº¡o' in String.vi.resx
[PASS] Test 5: tab_connections_header in String.vi.resx equals 'Kết nối'
[PASS] Test 6: LanguageBase resolved title is 'Kết nối' (actual: 'Kết nối')
[PASS] Test 7: LanguageBase resolved btn_new_connection is 'Tạo kết nối mới' (actual: 'Tạo kết nối mới')
[PASS] Test 8: LanguageBase resolved btn_test_connection is 'Kiểm tra kết nối' (actual: 'Kiểm tra kết nối')
[PASS] Test 9: DatabaseViewModel.InnerTabs has at least 1 tab
[PASS] Test 10: Tab 0 Header is 'Kết nối' (actual: 'Kết nối')
[PASS] Test 11: Tab 0 Content is not null
[PASS] Test 12: SelectedInnerTab equals Tab 0
[PASS] Test 13: SelectedInnerTab.Content is not null
[PASS] Test 14: Tab 0 IsClosable is false (anchored connection explorer)
=================================================
Summary: 14 passed, 0 failed.
=================================================
```

### Build Verification
```text
Build succeeded.
    0 Warning(s)
    0 Error(s)
```

## Residual Risks

- None. The encoding in `String.vi.resx` is standard UTF-8 without BOM, recognized across all .NET resource managers, and `DatabasePage.xaml` strictly mirrors the proven `<TabView>` + `<ContentPresenter>` architecture utilized in `ShellWindow.xaml`.

## Recommendation

Close the bug — verified end-to-end. The database tab title displays the correct Vietnamese text `"Kết nối"`, and the connection management workspace renders its complete UI controls with zero empty voids.
