# Quickstart & Verification Guide: High-Performance Data Pipeline, Server-Side Sorting, and In-Place Table Editor

**Feature**: `007-table-editor-and-query-pipeline`  
**Date**: 2026-10-21  

---

## 1. Prerequisites

- Active MySQL / MariaDB database server with sample database (e.g. `ngocthamcatalog.banggiada`).
- Windows 10/11 x64 workstation.
- .NET 10 SDK (`net10.0-windows10.0.26100.0`).

---

## 2. Compilation Verification

```powershell
dotnet build DataSphere\DataSphere.csproj -c Debug
```
**Assertion**: Must succeed with `0 Error(s)`, `0 Warning(s)`.

---

## 3. End-to-End Test Scenarios

### Scenario 1: Instant Table Switching & Cancellation Verification
1. Open DataSphere.
2. Connect to the active database.
3. Rapidly click Table 1 (e.g. `banggiada`) and immediately click Table 2 (e.g. `cai_dat`) within 100ms.
4. **Expected**:
   - The query for Table 1 cancels cleanly in the background.
   - Table 2 loads without delay.
   - No crash, no hanging dialogs, and no socket deadlocks occur.

### Scenario 2: Server-Side SQL Sorting Verification
1. Navigate to table `banggiada`.
2. Click the `id` column header once (Ascending `↑`).
   - Query executes: `ORDER BY \`id\` ASC LIMIT 100 OFFSET 0`.
   - Rows display from smallest `id` (e.g. `1, 2, 3...`).
3. Click the `id` column header again (Descending `↓`).
   - Query executes: `ORDER BY \`id\` DESC LIMIT 100 OFFSET 0`.
   - Rows display from largest `id` (e.g. `125, 124, 123...`).
4. Click the `id` column header a third time.
   - Sort clears, natural database order restores.

### Scenario 3: In-Place Editing & Commit Verification
1. Navigate to a table with a primary key (e.g. `banggiada`).
2. Double-click any editable cell (e.g. `code` column).
3. Change text from `OLD_CODE` to `TEST_EDIT_123`.
4. Press Enter or click outside the cell.
5. **Expected**:
   - Cell displays visual dirty state.
   - "Commit" and "Discard" buttons on the Viewport Toolbar become enabled.
6. Click "Discard".
   - Cell reverts to `OLD_CODE`.
   - "Commit" and "Discard" buttons disable.
7. Double-click the cell again, type `TEST_EDIT_123`, and click "Commit".
   - Parameterized `UPDATE` executes:
     `UPDATE \`ngocthamcatalog\`.\`banggiada\` SET \`code\` = @p0 WHERE \`id\` = @k0;`
   - Success notification is displayed.
   - Cell is no longer dirty.

---

## 4. Automated UI Verification Script (`WinSta0\default`)

Adapt the proven blueprint in `scripts/verify-datagrid-real-desktop.ps1`:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-table-editor-real-desktop.ps1
```
Captures DirectComposition screenshots:
1. `cancellation_switched_fast.png`
2. `server_sort_descending.png`
3. `inplace_cell_edited_dirty.png`
4. `inplace_cell_committed_success.png`
