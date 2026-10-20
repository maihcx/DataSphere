# Quickstart: Data Table & Schema Tree UI Virtualization

**Branch**: `005-data-and-tree-virtualization` | **Date**: 2026-10-20 | **Spec**: [spec.md](./spec.md)

## 1. Developer Overview

This quickstart guides developers and reviewers on how UI virtualization is implemented, verified, and benchmarked across `DataSphere`.

Virtualization is implemented in:
1. **`DataSphere/Views/Pages/DatabaseGroup/DataViewControl.xaml`**:
   - Two-tier virtualized grid: Outer horizontal `ScrollViewer` + constrained inner `ListView` with `ItemsStackPanel`.
   - Synchronized column header and row cell alignment.
2. **`DataSphere/Views/Pages/DatabaseGroup/DatabaseViewControl.xaml`**:
   - Native `TreeView` virtualization with pure POCO `DatabaseTreeNode` items.
   - Guarded lazy expansion via `HasUnrealizedChildren` and `DatabaseControlViewModel._loadingDatabases` lock.

---

## 2. Verification & Testing Workflow

### Step 1: Clean Compilation Gate
Verify that the solution compiles with 0 errors and 0 warnings:
```powershell
dotnet build DataSphere\DataSphere.csproj -c Debug
```

### Step 2: Automated Unit & Invariant Suite
Execute the targeted verification test suite:
```powershell
dotnet run --project scratch\VerifyDatabaseView\VerifyDatabaseView.csproj
```
Expected output: All unit tests pass, verifying:
- `DataViewControl.xaml` layout hierarchy (no unconstrained vertical ScrollViewer wrapping ListView).
- `ItemsStackPanel` active on ListView.
- `NullToVisibilityConverter` on placeholder overlay with `IsHitTestVisible="False"`.
- `DatabaseTreeNode` purity (no `UIElement` inheritance).
- Re-entrancy guards and asynchronous lock patterns.

### Step 3: Real Desktop UI Verification Gate (`WinSta0\default`)
Execute the live end-to-end automation runner to verify physical interaction, smooth scrolling, and DirectComposition screen capture:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify-real-end-to-end.ps1
```
Visual artifacts generated in `<appDataDir>\brain\<conversation-id>\`:
- `real_evidence_table_selected.png`: Confirms table loaded, data displayed, and placeholder collapsed.
- `real_evidence_cell_interacted.png`: Confirms row selection and cell text selection active on virtualized elements.
- `real_evidence_after_stress.png`: Confirms treeview survived 10 rapid expand/collapse cycles with zero crashes.
