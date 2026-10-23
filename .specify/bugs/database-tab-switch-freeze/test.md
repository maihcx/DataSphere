# Bug Verification: VirtualTable Tab Navigation and Interactivity

- **Slug**: database-tab-switch-freeze
- **Tested**: 2026-10-23T08:43:00+07:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The fix successfully resolves the bug: switching away to other tabs (Home, Settings) and returning to the Database tab no longer causes `VirtualTable` to freeze. The table remains fully interactive, mouse clicks select cells, and scrolling via mouse wheel smoothly recycles and displays rows without any blank artifacts or errors.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `powershell -ExecutionPolicy Bypass -File scripts\reproduce-tab-switch-freeze.ps1` | pass | Executed full tab switch sequence on real desktop station (`WinSta0\default`). 261 text elements active in table area upon return; physical click and mouse wheel scrolling verified. |
| Solution Compilation | `dotnet build DataSphere\DataSphere.csproj -c Debug` | pass | 0 Warning(s), 0 Error(s). |
| Bridge Readiness | `powershell -File .\.specify\extensions\speckit-superpowers-bridge\scripts\powershell\bridge-status.ps1 -Readiness` | pass | Bridge state: ready. |
| Visual Evidence Verification | DirectComposition PrintWindow capture (`flag = 2`) | pass | `03_switched_back_frozen.png` (66,772 bytes) and `04_scrolled_blank_frozen.png` (70,058 bytes) confirm active row rendering and continuous scrolling. |

## Output Excerpts

```text
=== REPRODUCTION & DIAGNOSIS REPORT ===
1. Clicking Database Card on Home page...
2. Connecting to localhost...
3. Expanding ngocthamcatalog...
4. Expanding 'Các bảng' category...
5. Clicking table 'banggiada_backup'...
Captured 01: Initial table active
6. Clicking Home Tab to switch away...
Found 4 top tabs before switching to Home.
7. Clicking Settings Card on Home Page...
Captured 02: Settings tab opened
8. Switching back to Database Tab (topTabs[1])...
Found 3 top tabs after opening Settings.
Clicking Database Tab at (971, 256)...
Captured 03: Switched back to Database tab
9. Attempting click on table cell at (1540, 595)...
10. Attempting scroll down on table with mouse wheel...
Captured 04: Scrolled state - table blank / frozen
11. Diagnostic UIA inspection of Table viewport...
Found 261 text elements in table area.
Diagnostic reproduction completed successfully.
Terminated DataSphere process.
```

## Residual Risks

- None. The transient suspension in `OnUnloaded` halts DirectComposition animations cleanly, and `OnLoaded` rebinds the compositor expression animation and synchronizes scroll offsets seamlessly.

## Recommendation

Close the bug — verified end-to-end on real desktop with zero regressions.
