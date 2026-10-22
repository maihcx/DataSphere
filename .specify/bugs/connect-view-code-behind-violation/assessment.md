# Bug Assessment: ConnectViewControl Violates Clean MVVM Separation with Excessive Code-Behind

- **Slug**: `connect-view-code-behind-violation`
- **Created**: 2026-10-22T14:18:00+07:00
- **Source**: "ConnectViewControl.xaml.cs hiện không tuân thủ nguyên tắc ít code behind"
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

The user identified an architectural and Clean MVVM compliance issue:
> *"ConnectViewControl.xaml.cs hiện không tuân thủ nguyên tắc ít code behind"*

Specifically, [`ConnectViewControl.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs) contains 195 lines of imperative code-behind, hosting business logic, direct service locator calls, imperative context menu construction, model mutations, and persistent storage I/O, violating Principle I (Clean MVVM & Type Safety) of the project constitution.

## Symptom

Instead of serving as a thin, declarative UI view, [`ConnectViewControl.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs) implements 195 lines of procedural logic. It dynamically builds a `MenuFlyout` in C# code, resolves [`IDialogService`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Services/Contracts/IDialogService.cs) via the service locator pattern (`App.GetRequiredService`), directly invokes dialogs, mutates [`ConnectionModel`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Models/ConnectionModel.cs) properties, manipulates connection collections, and directly executes asynchronous file persistence ([`ConnectionStorageService.SaveAsync`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Services/ConnectionStorageService.cs#L35-L55)).

Expected behavior: Views should declare UI elements in XAML, while all business operations (opening connections, editing connections, deleting connections, adding connections to folders, renaming, and persistence) are managed by [`ConnectControlViewModel`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/ViewModels/Pages/DatabaseGroup/ConnectControlViewModel.cs) using commands and dependency injection.

## Reproduction

1. Open [`ConnectViewControl.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs).
2. Inspect `TreeViewItem_ContextRequested` (lines 51–166): notice 115 lines of imperative MenuFlyout creation, direct calls to `App.GetRequiredService<IDialogService>()`, direct model mutations, and 5 separate direct invocations of `ConnectionStorageService.SaveAsync`.
3. Inspect `RenameTextBox_KeyDown` (lines 168–184) and `RenameTextBox_LostFocus` (lines 186–193): observe direct invocations of `ConnectionStorageService.SaveAsync`.
4. Launch the application on `WinSta0\default` and right-click any connection node in the Database page connection explorer.

### Diagnostic Evidence

- **Automated Live Reproduction Screenshot** (`WinSta0\default`):
  ![Diagnostic Reproduction](file:///d:/DEV/C%23DOTNET/DataSphere/.specify/bugs/connect-view-code-behind-violation/01_diagnostic_connect_view.png)
  *(Diagnostic screenshot captured via DirectComposition `PrintWindow` PW_RENDERFULLCONTENT showing the TreeView context menu rendered from code-behind)*

## Suspected Code Paths

- [`DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs:51-166`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs#L51-L166) — `TreeViewItem_ContextRequested`: 115 lines of imperative `MenuFlyout` construction, service location (`App.GetRequiredService<IDialogService>()`), dialog display, model mutation, and persistence.
- [`DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs:31-49`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs#L31-L49) — `ConnectionsTree_ItemInvoked` and `TreeViewItem_DoubleTapped`: Hardcoded database engine type checks (`conn.Type?.Value == DatabaseType.MySql`) and manual delegate invocation (`ViewModel.OnOpenConnection?.Invoke(conn)`).
- [`DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs:168-193`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs#L168-L193) — `RenameTextBox_KeyDown` and `RenameTextBox_LostFocus`: Direct manipulation of `conn.IsEditing` and direct file I/O calls to `ConnectionStorageService.SaveAsync`.
- [`DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml:97-135`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml#L97-L135) — `TreeView.ItemTemplate`: Missing declarative `TreeViewItem.ContextFlyout` in XAML markup, relying entirely on the procedural `ContextRequested` event handler.
- [`DataSphere/ViewModels/Pages/DatabaseGroup/ConnectControlViewModel.cs:92-157`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/ViewModels/Pages/DatabaseGroup/ConnectControlViewModel.cs#L92-L157) — `ConnectControlViewModel`: Contains unused callback initialization logic (`InitializeRuntimeProperties`) while lacking first-class `[RelayCommand]` endpoints for editing, deleting, adding to folder, and renaming connections.

## Root Cause Hypothesis

**Confidence: High (Confirmed by source code inspection and git history)**

During the WinUI 3 desktop migration (commit `8988e191b1b97b6bbf17e6e2d65a74271e308005`), the WPF context menu and tree event handlers were ported procedurally into C# code-behind rather than declarative XAML. The author re-implemented menu generation, service resolution, confirmation dialogs, and persistence calls directly in `TreeViewItem_ContextRequested`, ignoring existing abstractions in [`ConnectControlViewModel`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/ViewModels/Pages/DatabaseGroup/ConnectControlViewModel.cs) and creating duplicate logic, tightly coupling the View to [`IDialogService`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Services/Contracts/IDialogService.cs) and [`ConnectionStorageService`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Services/ConnectionStorageService.cs).

## Proposed Remediation

### Preferred: Declarative XAML ContextFlyout & Clean MVVM ViewModel Command Relaying

1. **Refactor [`ConnectControlViewModel`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/ViewModels/Pages/DatabaseGroup/ConnectControlViewModel.cs)**:
   - Expose explicit `[RelayCommand]` methods on `ConnectControlViewModel`:
     - `OpenConnectionCommand(ConnectionModel? conn)`: Validates connection type and invokes `OnOpenConnection`.
     - `EditConnectionCommand(ConnectionModel? conn)`: Uses constructor-injected `_dialogService.ShowConnectionEditingDialogAsync`, updates properties, and triggers storage save.
     - `DeleteConnectionCommand(ConnectionModel? conn)`: Prompts confirmation via `_dialogService.ShowConfirmationDialogAsync`, removes item from parent folder or root collection, and saves.
     - `NewConnectionInFolderCommand(ConnectionModel? folder)`: Prompts connection dialog and appends child connection to the target folder.
     - `StartRenameCommand(ConnectionModel? conn)`: Sets `conn.IsEditing = true`.
     - `EndRenameCommand(ConnectionModel? conn)`: Sets `conn.IsEditing = false` (auto-saved via existing `PropertyChanged` listener).
   - Clean up dead callback code in `ModelInitialize`.

2. **Declarative Context Menu in [`ConnectViewControl.xaml`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml)**:
   - Declare `<TreeViewItem.ContextFlyout>` directly inside the `DataTemplate` in XAML.
   - Bind menu items to the `Localization` resource dictionary (`{Binding [Key], Source={StaticResource Localization}, Mode=OneWay}`).
   - Bind commands to `ViewModel` commands with `CommandParameter="{x:Bind}"`.
   - Control visibility of Folder vs Database connection menu items via binding or dedicated converters.

3. **Eliminate Procedural Code in [`ConnectViewControl.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs)**:
   - Delete `TreeViewItem_ContextRequested` completely (removes 115 lines).
   - Replace `ConnectionsTree_ItemInvoked` and `TreeViewItem_DoubleTapped` with clean 1-line delegations to `ViewModel.OpenConnectionCommand.Execute(...)`.
   - Simplify `RenameTextBox_KeyDown` and `RenameTextBox_LostFocus` to simply set `conn.IsEditing = false`, removing direct file I/O calls (`ConnectionStorageService.SaveAsync`).
   - Reduce code-behind footprint from 195 lines to under 30 lines of pure view wiring.

### Alternatives:

- **Alternative 1: Data-Driven Hierarchical Menu via Custom Attached Flyout**:
  - Dynamically generate Flyout items from `ConnectionModel.ContextMenuItems`.
  - *Trade-off*: WinUI 3 `MenuFlyout` lacks native item templating without custom attached properties, adding unnecessary complexity compared to declarative XAML `ContextFlyout`.

## Files Likely to Change

- [`DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml.cs) — Remove procedural context menu generation, service locator calls, and direct persistence logic.
- [`DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/Views/Pages/DatabaseGroup/ConnectViewControl.xaml) — Declare `ContextFlyout` directly in XAML markup with localized text and command bindings.
- [`DataSphere/ViewModels/Pages/DatabaseGroup/ConnectControlViewModel.cs`](file:///d:/DEV/C%23DOTNET/DataSphere/DataSphere/ViewModels/Pages/DatabaseGroup/ConnectControlViewModel.cs) — Implement RelayCommands for open, edit, delete, add-in-folder, and rename lifecycle actions.

## Tests to Add or Update

- Unit test verifying `ConnectControlViewModel.EditConnectionCommand`, `DeleteConnectionCommand`, and `NewConnectionInFolderCommand` correctly invoke `IDialogService` and update `ConnectItems`.
- UI Automation verification ensuring right-click context menu opens seamlessly and all menu actions (Open, Edit, Rename, Delete) operate identically on real desktop (`WinSta0\default`).

## Risks & Considerations

- **Dialog XamlRoot Handling**: WinUI 3 `ContentDialog` requires a valid `XamlRoot`. When invoked from `ConnectControlViewModel`, `IDialogService` implementation must safely retrieve active window `XamlRoot` if not passed explicitly (already handled by `DialogService` fallback or passed via service context).
- **ContextFlyout Item Binding Scope**: Inside `DataTemplate x:DataType="models:ConnectionModel"`, bindings to `ViewModel` commands can use element-name binding (`ElementName=RootControl, Path=ViewModel.CommandName`) or x:Bind to code-behind ViewModel helper property.

## Open Questions

- None. The architectural requirement and remediation paths are clear and well-defined within DataSphere's existing MVVM conventions.
