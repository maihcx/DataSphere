# Quickstart: Database Connection Management Verification

**Feature**: `004-database-connection-management`  
**Date**: 2026-10-20  

This guide provides step-by-step instructions for testing and validating the restored database connection features in DataSphere.

---

## 1. Prerequisites

- Windows 10/11 x64 or ARM64.
- .NET 10 SDK (`net10.0-windows10.0.26100.0`).
- Local or accessible MySQL/MariaDB instance (optional for unit verification; mock/test cases cover headless scenarios).

---

## 2. Compilation Verification Gate

Ensure the codebase builds with 0 errors and 0 warnings:

```powershell
dotnet build DataSphere\DataSphere.csproj -c Debug
```

---

## 3. Headless Verification Suite

Run the headless verification harness:

```powershell
dotnet run --project scratch/VerifyUserDataStore/VerifyUserDataStore.csproj
```

The verification harness confirms:
1. `ConnectionStorageService.SaveAsync` encrypts passwords with AES-CBC.
2. `connections.json` contains ZERO plain-text passwords.
3. `ConnectionStorageService.LoadAsync` accurately recovers decrypted passwords.
4. Corrupted or missing `connections.json` is safely handled without exceptions.
5. In-memory `ConnectionModel` tree hierarchy propagates parent-child events.
6. Multi-tab inner session lifecycle handles Tab 0 non-closable connections and dynamic connection tabs.

---

## 4. Interactive UI Testing Scenarios

### Scenario A: Empty State & New Connection Creation
1. Delete or rename `%LOCALAPPDATA%\DataSphere\connections.json`.
2. Launch DataSphere: `dotnet run --project DataSphere\DataSphere.csproj`.
3. Click the **Database** navigation card or tab in the shell.
4. **Verify**:
   - Tab 0 ("Connections") is displayed.
   - The empty-state banner is visible with a "New Connection" button.
5. Click "New Connection":
   - The `ConnectionEditingDialog` opens centered in the window.
   - Host defaults to `127.0.0.1`, Port to `3306`, User to `root`.
6. Click "Test Connection":
   - If MySQL is running locally, a success badge appears.
   - If not, an informative connection error message displays within 5 seconds without freezing the UI.
7. Click "Save":
   - Connection appears in the tree view immediately.
   - File `%LOCALAPPDATA%\DataSphere\connections.json` is created with encrypted password.

### Scenario B: Multi-Connection Inner Tabs & Schema Discovery
1. Double-click the saved connection in the Connections list.
2. **Verify**:
   - An inner closable tab opens with the connection name.
   - The object explorer tree expands to show databases.
   - Categories appear under each database: Tables, Views, Stored Procedures, Functions, Triggers, Events.
3. Expand a database (e.g. `sys` or `mysql`):
   - Table items populate under the Tables category.

### Scenario C: Table Data Viewing & Pagination
1. Double-click or select any table in the schema tree.
2. **Verify**:
   - The right panel loads `DataViewControl`.
   - Columns are rendered with header titles.
   - The page selector shows 100 records per page.
   - The Refresh button re-executes the paginated query.

### Scenario D: Dynamic Localization (i18n)
1. Open the **Settings** tab.
2. Switch Language between **English** and **Tiếng Việt**.
3. Return to the **Database** tab:
   - Tab titles, empty-state text, buttons, context menus, and column headers refresh dynamically without restarting the application.
