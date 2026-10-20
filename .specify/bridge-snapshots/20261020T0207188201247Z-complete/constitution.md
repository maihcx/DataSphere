<!--
Sync Impact Report:
- Version change: 1.0.0 → 1.1.0 (Minor version bump for new i18n principle & WinUI 3 platform alignment)
- Modified principles:
  - Principle II: Modern Fluent UI / UX Standards (Updated references to WinUI 3, Windows App SDK, Mica backdrop, TabView, and WinUIEx)
- Added sections / principles:
  - Principle VII: Zero Hardcoded User-Facing Strings & Dynamic Internationalization (i18n)
  - Updated Technology Stack: Windows App SDK 2.5+, WinUI 3, net10.0-windows10.0.26100.0, WinUIEx
  - Added Internationalization (i18n) Verification Gate
- Removed sections: None
- Follow-up TODOs: None (all requirements concrete and non-negotiable)
-->

# DataSphere Constitution

## Core Principles

### Principle I: Clean MVVM & Type Safety
The application MUST strictly adhere to the Clean Model-View-ViewModel (MVVM) architectural pattern using `CommunityToolkit.Mvvm`:
- **Strict View / ViewModel Decoupling**: ViewModels MUST be completely UI-agnostic and MUST NOT import or reference UI visual types (such as `FrameworkElement`, `Window`, `Page`, or `ContentPresenter`).
- **Declarative Source Generators**: ViewModels MUST utilize `[ObservableProperty]`, `[RelayCommand]`, and `[NotifyPropertyChangedFor]` source generators on partial properties to maintain compile-time safety and eliminate boilerplate.
- **Zero Business Logic in Code-Behind**: Views (`*.xaml.cs`) MUST NOT contain business, database, or domain orchestration logic. Code-behind is strictly restricted to view-only lifecycle plumbing (such as setting titlebar drag regions or hooking native non-bindable events).
- **UI Thread Dispatching**: Any background thread seeking to update UI-bound state MUST marshal operations through the UI thread dispatcher (`DispatcherQueue`).

### Principle II: Modern Fluent UI / UX Standards
The graphical user interface MUST deliver a Tier-1 Windows desktop experience built on Windows App SDK (WinUI 3) Fluent Design 2:
- **Theme & Backdrop Synchronization**: The application MUST support full, glitch-free Light and Dark themes, seamlessly synchronized with Windows system settings, utilizing Mica/Acrylic system backdrops.
- **Modern Controls & Chrome Tab Strip**: All views MUST employ modern WinUI 3 controls, Segoe UI Variable fonts, standard spacing tokens, and native browser-style Chrome tabs (`TabView`) embedded into the window titlebar.
- **Asynchronous Modal Dialogs**: Blocking Win32 message boxes (`MessageBox.Show`) are STRICTLY FORBIDDEN. All prompts, confirmations, and alerts MUST use asynchronous `ContentDialog` or InfoBar notifications.

### Principle III: Secure Database Connection & Credential Protection
Protection of user data, database credentials, and server configurations is a non-negotiable security imperative:
- **Encrypted Credential Storage**: Database connection strings, passwords, and sensitive authentication tokens MUST NEVER be stored in plain text. They MUST be encrypted at rest using `PasswordEncryptor` (AES-GCM / Windows DPAPI).
- **Zero Plain-Text Leaks**: Passwords and secrets MUST NOT appear in plaintext in log files, crash dumps (`crash.log`), debug outputs, or error dialogs.
- **SQL Injection Prevention**: All queries and database interactions via `MySqlConnector` MUST use strictly parameterized queries or prepared statements. Dynamic string concatenation of SQL statements with raw user input is STRICTLY PROHIBITED.

### Principle IV: High Performance & Thread Stewardship
The UI MUST maintain fluid 60 FPS responsiveness (<16ms per frame) under all operational workloads:
- **Asynchronous Non-Blocking I/O**: Every database connection handshake, ping, schema discovery query, and dataset retrieval MUST execute asynchronously off the UI thread (`async`/`await`, `Task.Run`).
- **Cancellation Stewardship**: All long-running asynchronous tasks and database operations MUST accept and actively monitor a `CancellationToken` to allow instant user aborts without dangling locks.
- **Deterministic Resource Management**: Database connections, readers, commands, and transactions MUST be deterministically disposed via `await using` or `using` blocks to prevent socket exhaustion and connection leaks.
- **Memory Protection**: Query results and data records MUST use paging or virtualized collections to avoid large object heap (LOH) fragmentation and memory spikes.

### Principle V: English Technical Documentation Standard
To ensure long-term maintainability and alignment with automated analysis tools:
- **100% Documentation Coverage**: All public and internal classes, interfaces, records, structs, methods, properties, and RelayCommands MUST be documented with standard XML doc comments (`/// <summary>`, `<param>`, `<returns>`, `<exception>`).
- **Standard Technical US English**: All code documentation, code comments, and commit messages MUST be written exclusively in standard technical American English. Non-English doc comments, colloquial language, or empty boilerplate summaries are prohibited.

### Principle VI: Spec-Driven Development & Superpowers Discipline
Every feature, architectural refactoring, and defect resolution MUST follow the dual-engine methodology combining **Spec-Kit** (design authority) and **Superpowers** (engineering execution):
- **Spec-Kit as the Source of Truth**: Requirements (`spec.md`), architectural plans (`plan.md`), and task breakdowns (`tasks.md`) MUST be established before writing code.
- **Bridge Handoff & Guard Integrity**: The handoff between Spec-Kit and Superpowers MUST proceed through `speckit-superpowers-bridge`, respecting contract immutability while tasks are in execution.
- **Superpowers Technical Discipline**: Engineers MUST apply Test-Driven Development (Red-Green-Refactor), Systematic Debugging for root-cause isolation, subagent verification, and multi-perspective code review before claiming completion.

### Principle VII: Zero Hardcoded User-Facing Strings & Dynamic Internationalization (i18n)
All user-facing text, titles, descriptions, dialog messages, and menu labels MUST support multi-language internationalization and MUST NOT be hardcoded in application code:
- **Zero Hardcoded Strings in C# & XAML**: Hardcoded string literals for user-facing UI text (such as tab titles, button labels, card headers, error messages, or tooltip content) are STRICTLY FORBIDDEN. All UI text MUST be defined in localization resource files (`Resources/Locales/String.resx`, `String.en.resx`, `String.vi.resx`).
- **Dynamic Localization Source**: All runtime string resolution MUST use `TranslationSource` (`DataSphere.Utils.Translations`) or `LanguageBase.GetLangValue(key, args)` to allow instant language switching at runtime without requiring an application restart.
- **Dynamic Binding & Notification**: ViewModels and Models presenting localized properties MUST hook into `TranslationSource.Instance.PropertyChanged` or expose resource keys (`NameKey`, `TitleKey`) so that text refreshes immediately when the user changes language.
- **XAML Localization Compliance**: In XAML views, user-facing text MUST bind directly to the application's localization resource using indexer syntax: `Text="{Binding [KeyName], Source={StaticResource Localization}, Mode=OneWay}"`. Hardcoding UI strings or introducing redundant string properties on ViewModels when XAML static resource binding can be used is prohibited.

## Technology Stack & Security Constraints

- **Platform & Runtime**: .NET 10 (`net10.0-windows10.0.26100.0`), C# (Language Version `preview`), Windows App SDK (WinUI 3).
- **Core Presentation Libraries**: `Microsoft.WindowsAppSDK` (WinUI 3 controls, Theme management, TabView), `WinUIEx` (window management), `CommunityToolkit.Mvvm` (MVVM Toolkit v8.4+).
- **Host & Dependency Injection**: `Microsoft.Extensions.Hosting` (Generic Host, `IServiceCollection`, hosted application lifecycle).
- **Database Engine**: `MySqlConnector` (high-performance async MySQL/MariaDB driver), `System.IO.Hashing` (fast data integrity checks).
- **Inter-Process Communication (IPC)**: Per-process Named Pipe Server with Windows Access Control Lists (ACL) supporting multi-instance process concurrency.
- **Internationalization (i18n)**: `TranslationSource` with `INotifyPropertyChanged` indexer, `.resx` resource bundles (`String.resx`, `String.en.resx`, `String.vi.resx`), supporting live language switching (English, Vietnamese).

## Development Workflow & Quality Gates

- **Zero-Error Compilation Gate**: Every pull request and committed change MUST compile cleanly (`dotnet build DataSphere\DataSphere.csproj -c Debug`) with 0 errors and 0 warnings.
- **Documentation Verification Gate**: All modified or introduced methods, properties, and types MUST meet 100% English XML documentation requirements.
- **Internationalization (i18n) Gate**: All newly introduced or modified UI elements, commands, and viewmodels MUST NOT contain hardcoded user-facing strings; all user text MUST use `TranslationSource` / `.resx` keys.
- **Convergence Verification Gate**: Prior to feature sign-off, `/speckit-converge` MUST confirm that the implementation exhibits zero gaps against `spec.md`, `plan.md`, and `tasks.md`.
- **Evidence-Before-Assertion Mandate**: No task may be marked as complete without verifiable execution evidence (passing build logs, test executions, or runtime traces).

## Governance

- **Constitutional Supremacy**: This Constitution represents the supreme architectural and technical law of the DataSphere repository. It supersedes informal conventions, legacy habits, and ad-hoc suggestions.
- **Amendment Procedure**: Amendments to this Constitution require an explicit `/speckit-constitution` cycle detailing:
  1. The specific principle or constraint being modified.
  2. The architectural rationale and impact assessment.
  3. A corresponding semantic version bump according to SemVer rules:
     - **MAJOR**: Incompatible removal or fundamental redefinition of core architectural invariants.
     - **MINOR**: Addition of new principles, platforms, or substantially expanded quality gates.
     - **PATCH**: Non-semantic clarifications, typo fixes, or wording refinements.
- **Compliance Enforcement**: All code reviews and agent orchestrations MUST actively verify adherence to these constitutional principles.

**Version**: 1.1.0 | **Ratified**: 2026-10-19 | **Last Amended**: 2026-10-19
