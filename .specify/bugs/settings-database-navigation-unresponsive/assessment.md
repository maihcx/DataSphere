# Bug Assessment: Unresponsive Settings and Database Navigation from Home Dashboard

- **Slug**: settings-database-navigation-unresponsive
- **Created**: 2026-10-20T09:12:00+07:00
- **Source**: "giờ khi tôi nhấn vào settings hay databases thì nó cũng đều không phản ứng gì"
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

The user reports that clicking the "Cơ sở dữ liệu" (Database) and "Cài Đặt" (Settings) action cards on the Home dashboard page produces no response or visible action:
> "giờ khi tôi nhấn vào settings hay databases thì nó cũng đều không phản ứng gì"

## Symptom

When clicking either the Database card or the Settings card on the `HomePage`, no new tabs are opened in the `ShellTabView`, the active viewport does not navigate or change, and the application appears completely unresponsive to those user actions.

Expected behavior:
- Clicking the Database card opens a new closable "Cơ sở dữ liệu" tab and focuses it.
- Clicking the Settings card opens a new closable "Cài Đặt" tab (or focuses the existing Settings tab if already open).

## Reproduction

1. Launch DataSphere (`dotnet run --project DataSphere\DataSphere.csproj`).
2. Ensure the application opens to the default Home dashboard tab ("Trang chủ").
3. Click the "Cơ sở dữ liệu" (Database) card.
   - **Observed**: Nothing happens; tab strip remains with only the Home tab; view does not change.
4. Click the "Cài Đặt" (Settings) card.
   - **Observed**: Nothing happens; no reaction or navigation.

## Suspected Code Paths

- `DataSphere/ViewModels/Windows/ShellViewModel.cs:104-114`:
  ```csharp
  var homeVm = new DataSphere.ViewModels.Pages.HomeViewModel(_tabService);
  object? homePageInstance = null;
  try
  {
      homePageInstance = _serviceProvider.GetService(typeof(HomePage)) ?? new HomePage(homeVm);
  }
  catch
  {
      homePageInstance = homeVm;
  }
  ```
  `_serviceProvider.GetService(typeof(HomePage))` is called before the fallback `new HomePage(homeVm)`. Because `HomePage` is registered in `App.xaml.cs` as transient, DI constructs `HomePage` using constructor injection `new HomePage(HomeViewModel)`.
- `DataSphere/App.xaml.cs:54`:
  `services.AddTransient<ITabService, TabService>();`
  When DI constructs `HomeViewModel`, it resolves a brand-new, isolated `ITabService` instance (Instance B) rather than the `_tabService` instance bound to the active `ShellViewModel` / `ShellWindow` (Instance A).
- `DataSphere/ViewModels/Pages/HomeViewModel.cs:59-73`:
  `OpenDatabase()` and `OpenSettings()` execute on `HomeViewModel`, invoking `_tabService.OpenTab(...)` against the isolated, disconnected `TabService` Instance B. `ShellViewModel` (listening to Instance A) never receives the tab addition or selection event.

## Root Cause Hypothesis

**Confidence: High**

In `ShellViewModel.InitializeHomeTab()`, the code attempts to resolve `HomePage` from DI via `_serviceProvider.GetService(typeof(HomePage))` before falling back to `new HomePage(homeVm)`. 

Because `HomePage`, `HomeViewModel`, and `ITabService` are all registered with transient lifetime in the service container (`App.xaml.cs`), Microsoft.Extensions.DependencyInjection resolves `HomePage` by instantiating a completely new `HomeViewModel` with a new, decoupled `TabService` instance. The `homeVm` that was explicitly configured with the shell window's active `_tabService` is discarded. 

As a result, user clicks on the Home dashboard cards execute commands against a disconnected `TabService` instance that has no listeners and is not bound to the `ShellWindow` visual tree, causing total unresponsiveness.

## Proposed Remediation

**Preferred**:
1. In `DataSphere/ViewModels/Windows/ShellViewModel.cs`, eliminate `_serviceProvider.GetService(typeof(HomePage))` and directly instantiate `homePageInstance = new HomePage(homeVm);`. This guarantees that the `HomePage`'s `ViewModel` is bound to the exact `_tabService` coordinating that window's tab strip.
2. In `DataSphere/ViewModels/Pages/HomeViewModel.cs`, provide a robust parameterless constructor `public HomeViewModel() : this(ResolveActiveTabService())` where `ResolveActiveTabService()` locates the active window's `ITabService` from `IWindowManager.Windows`. This ensures that even if `HomePage` is instantiated parameterless or via DI, it will always connect to the active window's tab service rather than an orphaned transient instance.

**Alternatives**:
- Register `ITabService` scoped per window. However, WinUI 3 does not have native per-window DI scopes without significant host boilerplate, so direct injection and active window resolution is much cleaner and less error-prone.

**Files likely to change**:
- `DataSphere/ViewModels/Windows/ShellViewModel.cs`
- `DataSphere/ViewModels/Pages/HomeViewModel.cs`

**Tests to add or update**:
- Unit/headless test verifying that `HomeViewModel` created with a given `ITabService` successfully populates that same `ITabService.Tabs` upon executing `OpenDatabaseCommand` and `OpenSettingsCommand`.
- Verify that `ShellViewModel.Tabs.Count` increases to 2 when `OpenDatabaseCommand` and `OpenSettingsCommand` are executed.

## Risks & Considerations

- Multi-window tab tear-off: Ensuring `HomePage` is bound to the specific window's `_tabService` maintains proper isolation between independent windows.

## Open Questions

- None. The root cause is directly identifiable from DI transient registration and constructor resolution.
