# Quickstart Validation Guide: Native CommunityToolkit DataGrid with Interactive Sorting

- **Feature**: `006-datagrid-table-view`
- **Date**: 2026-10-21
- **Status**: Complete

---

## 1. Prerequisites

- Windows 10/11 x64 operating system with Developer Mode enabled.
- .NET 10 SDK (`net10.0-windows10.0.26100.0`).
- Local MySQL or MariaDB instance with sample database (e.g. `ngocthamcatalog.banggiada`).
- NuGet package: `CommunityToolkit.WinUI.UI.Controls.DataGrid` (Version 7.1.2).

---

## 2. Compilation Check

Validate that the application compiles cleanly without errors or warnings:

```powershell
dotnet build DataSphere\DataSphere.csproj -c Debug
```

**Expected Outcome**: `0 Warning(s), 0 Error(s)`.

---

## 3. End-to-End Live UI Automation Scenario

Validate on real desktop station (`WinSta0\default`):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify-real-end-to-end.ps1
```

### Scenario Steps:
1. **Launch**: DataSphere opens on `WinSta0\default` with Mica backdrop.
2. **Connect**: Connect to `localhost` and navigate to database `ngocthamcatalog`.
3. **Table View**: Click table `banggiada` (2889 rows).
   - **Verification**: `TableDataGrid` displays with integrated column headers (`id`, `cid`, `pid`, `code`, `code_xlsx`).
   - Gridlines are visible, separating columns and rows cleanly.
4. **Interactive Sorting Test**:
   - Click column header `id`:
     - Sort direction changes to `Ascending`.
     - An upward arrow glyph appears in the `id` column header.
     - Rows reorder: `id` values 1, 2, 3...
   - Click column header `id` again:
     - Sort direction changes to `Descending`.
     - A downward arrow glyph appears in the `id` column header.
     - Rows reorder: `id` values in descending order.
   - Click column header `id` a third time:
     - Sort direction clears (`null`).
     - Arrow glyph is removed.
     - Natural order restored.
5. **Column Resizing Test**:
   - Drag divider between column 0 and 1.
   - Column width resizes smoothly without clipping or layout desynchronization.
6. **Virtualization & Rapid Scroll Test**:
   - Drag vertical scrollbar from top to bottom.
   - 60 FPS continuous scrolling, zero grey placeholder boxes, instant rendering.
