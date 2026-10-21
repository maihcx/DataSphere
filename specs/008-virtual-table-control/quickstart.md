# Quickstart & Verification Guide: High-Performance WinUI 3 VirtualTable Control

**Feature**: `008-virtual-table-control`  
**Date**: 2026-10-21  

---

## 1. Prerequisites

- Active MySQL / MariaDB server with sample database (`ngocthamcatalog.banggiada`).
- Windows 10/11 x64 workstation.
- .NET 10 SDK (`net10.0-windows10.0.26100.0`).

---

## 2. Compilation Verification

```powershell
dotnet build DataSphere\DataSphere.csproj -c Debug
```
**Assertion**: Must succeed with `0 Error(s)`, `0 Warning(s)`.

---

## 3. End-to-End Verification Scenarios

### Scenario 1: Ultra-Fast Table Loading & Fixed Element Pool
1. Launch DataSphere.
2. Connect to localhost and select `ngocthamcatalog.banggiada`.
3. **Verify**:
   - `VirtualTable` renders the table records in $<50$ ms.
   - Inspect element tree: only ~25 visual row containers exist in memory.
   - Visual styling matches WinUI 3 Fluent Design 2 with crisp 1px gridlines, alternating row shading, and Segoe UI Variable fonts.

### Scenario 2: Zero-Allocation Smooth Fast Scrolling
1. With table `banggiada` open, scroll rapidly downward using mouse wheel (20 fast spins) or drag the scrollbar thumb.
2. **Verify**:
   - Scrolling maintains solid 60+ FPS without visual tearing, detached headers, or blank rows.
   - Headers and cells remain strictly synchronized.
   - Memory allocation on managed heap during scrolling is 0 bytes.

### Scenario 3: Interactive Column Resizing & 3-State Sorting
1. Hover cursor over the separator between column headers `id` and `cid`.
2. Drag divider to the right by 80 pixels.
3. **Verify**:
   - Column `id` widens fluidly.
   - All visible cells in column `id` widen synchronously without tearing.
4. Click column header `id`:
   - Sort arrow `↑` displays; server queries `ORDER BY \`id\` ASC`.
5. Click column header `id` again:
   - Sort arrow `↓` displays; server queries `ORDER BY \`id\` DESC`.
6. Click column header `id` third time:
   - Sort arrow clears; natural database retrieval order restores.

### Scenario 4: In-Place Cell Editing with Overlay Editor
1. Double-click first row cell in column `code`.
2. An in-place `TextBox` overlay appears directly over the cell with current text selected.
3. Type `"VIRTUAL_TEST"`, press Enter.
4. **Verify**:
   - Overlay closes; cell updates to `"VIRTUAL_TEST"`.
   - Row displays dirty indicator.
   - Toolbar "Commit" and "Discard" buttons become enabled.
5. Click "Commit":
   - Parameterized `UPDATE` executes.
   - Success notification displays.

---

## 4. Automated UI Verification Script (`WinSta0\default`)

Run the automated test harness:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-virtualtable-real-desktop.ps1
```
Captures DirectComposition screenshots:
1. `virtualtable_rendered_initial.png`
2. `virtualtable_scrolled_fast.png`
3. `virtualtable_column_resized.png`
4. `virtualtable_sorted_asc.png`
5. `virtualtable_sorted_desc.png`
6. `virtualtable_cell_edited_committed.png`
