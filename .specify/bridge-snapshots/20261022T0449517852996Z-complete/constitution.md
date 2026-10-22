<!--
Sync Impact Report:
- Version change: 1.4.0 → 1.5.0 (Minor version bump introducing the Zero-Speculation / Mandatory Live UI Verification Gate, strictly prohibiting assumption-based handoff or speculative completion claims, and mandating end-to-end live UI testing on WinSta0\default with verified visual and interaction evidence prior to any delivery)
- Modified principles:
  - Principle VIII: Visual UI Reproduction, Diagnostic Inspection & Verification Gate (Expanded with strict Zero-Speculation / Zero-Guesswork Invariant, absolute ban on phrases like 'I guess it works' or 'theoretically resolved', mandatory live UI automation execution covering end-to-end user workflows, physical mouse interaction verification, and verified visual evidence as an uncompromising blocker for delivery)
- Added quality gates:
  - Zero-Speculation Live UI Verification Gate: Explicit gate prohibiting handoff or marking tasks complete without concrete live UI execution logs, physical interaction proofs, and DirectComposition screenshots.
- Removed sections: None
- Follow-up TODOs: None (all requirements strictly specified, declarative, and non-negotiable)
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
- **Strict UTF-8 Encoding Without BOM**: All `.resx` files MUST be authored, modified, and saved exclusively in strict UTF-8 encoding without BOM (`System.Text.UTF8Encoding(false)`). Modifying or appending `.resx` entries using shell scripts or PowerShell without explicit UTF-8 encoding is STRICTLY FORBIDDEN to eliminate double-byte Mojibake encoding corruption. Any programmatic resource generation MUST use XML DOM APIs or Unicode escape sequences (`\uXXXX`).
- **Dynamic Localization Source**: All runtime string resolution MUST use `TranslationSource` (`DataSphere.Utils.Translations`) or `LanguageBase.GetLangValue(key, args)` to allow instant language switching at runtime without requiring an application restart.
- **Dynamic Binding & Notification**: ViewModels and Models presenting localized properties MUST hook into `TranslationSource.Instance.PropertyChanged` or expose resource keys (`NameKey`, `TitleKey`) so that text refreshes immediately when the user changes language.
- **XAML Localization Compliance**: In XAML views, user-facing text MUST bind directly to the application's localization resource using indexer syntax: `Text="{Binding [KeyName], Source={StaticResource Localization}, Mode=OneWay}"`.
- **XAML Layout Decoupling Mandate**: In WinUI 3, `TabView` controls MUST strictly host only their tab headers/items. Viewport content hosts (such as `<ContentControl>` or `<ContentPresenter>`) MUST NEVER be placed directly inside `<TabView>` tags; they MUST be decoupled into a separate layout grid row to avoid visual tree orphaning and empty viewports.

### Principle VIII: Visual UI Reproduction, Diagnostic Inspection & Verification Gate
To eliminate guesswork, prevent misdiagnosed root causes, and standardize automated desktop testing without research overhead:
- **Mandatory Live Diagnostic Reproduction**: When an issue or bug report is received (e.g. during `/speckit-bug-assess` or incident intake), the agent MUST NOT hypothesize or guess the root cause based purely on static code analysis. If the report involves user interface behavior, rendering, navigation, window lifecycle, or localization, the agent MUST run the application and execute automated UI testing to reproduce the failure live, inspect the visual element tree, and capture initial failure screenshots (`.png`) into the session artifact directory (`<appDataDir>/brain/<conversation-id>`).
- **Interactive Desktop Station Protocol (`WinSta0\default`)**: In Windows agent environments, subshell processes operate by default under an isolated desktop station (`WinSta0\exebox-...`). To ensure testing runs against the user's real interactive desktop and avoids invisible/blank window captures, agents MUST:
  1. Launch `DataSphere.exe` using Win32 `CreateProcess` with `STARTUPINFO.lpDesktop = @"WinSta0\default"`.
  2. Switch the test thread's desktop by calling `OpenDesktop("default", 0, false, 0x01FF)` and `SetThreadDesktop(hDesk)` before invoking Windows UI Automation (`System.Windows.Automation`).
- **Zero-AutomationId Production Code Invariant**: Agents are STRICTLY PROHIBITED from modifying or polluting production XAML markup with temporary or testing-specific attributes such as `AutomationProperties.AutomationId`. Production XAML must remain 100% clean. Automated UI tests MUST locate controls dynamically via:
  1. **Structural Geometry & Layout Coordinates**: Finding container cards and major panels by their `BoundingRectangle` bounds (e.g., width, height, position offsets).
  2. **Control Hierarchy & Types**: Traversing `ControlType` (`ControlType.Button`, `ControlType.ComboBox`, `ControlType.Text`).
  3. **Localized Content Matching**: Inspecting child `TextBlock.Name` attributes against translated localization strings.
- **Physical Mouse Control & Realistic Interaction**: When testing on the interactive desktop, the automation harness MUST calculate the center point of the target element `(X, Y) = (rect.X + rect.Width / 2, rect.Y + rect.Height / 2)`, move the physical cursor via Win32 `SetCursorPos(X, Y)`, and emit realistic native input events via `mouse_event(MOUSEEVENTF_LEFTDOWN | MOUSEEVENTF_LEFTUP)`.
- **DirectComposition High-Fidelity Capture**: Screenshots of WinUI 3 hardware-accelerated XAML windows MUST be captured using Win32 `PrintWindow` with `PW_RENDERFULLCONTENT` (`flag = 2`) to ensure full visual fidelity (including mica backdrops, acrylic controls, and open dropdowns/dialogs) without black or empty bounding boxes.
- **Standardized Execution Blueprint**: All UI automation testing MUST reuse or adapt the proven blueprint established in `scripts/test-real-desktop.ps1` and `scripts/verify-real-end-to-end.ps1`. Future agents MUST NOT re-investigate or re-engineer the UI automation pipeline; they MUST execute this established pattern directly.
- **Zero-Speculation & Mandatory Live UI Verification Gate Before Handoff**:
  - **Absolute Ban on Speculation & Assumption**: Agents are STRICTLY FORBIDDEN from guessing, speculating, or stating phrases such as "tôi đoán là nó hoạt động" ("I guess it works"), "it should work now", "theoretically fixed", or "likely resolved". No task may be marked as complete, no PR may be approved, and no handoff may occur based on code inspection, compilation success (`dotnet build`), or headless unit tests alone whenever UI, layout, interaction, or rendering is involved.
  - **Uncompromising Delivery Gate**: Handoff and task completion are PERMITTED ONLY IF live end-to-end UI automation testing has completed successfully on the real desktop station (`WinSta0\default`), fully executing the actual user workflow (opening connections, navigating tabs, expanding tree nodes via exact coordinates, selecting items, interacting with rows/cells), verifying the absence of crashes, and capturing genuine DirectComposition screenshots (`.png`) saved into the session artifact directory (`<appDataDir>/brain/<conversation-id>`).
  - **Click Target & Interaction Accuracy Mandate**: The automation harness must verify accurate click coordinates and offsets. If an interaction fails to hit the intended control or produces no state change, the agent MUST NOT assume success; the agent MUST inspect the element hierarchy, calibrate the coordinates, and re-execute until unambiguous visual and behavioral proof is obtained.
- **Mandatory Visual Inspection Prior to Completion**: Before any bug fix or new user-facing feature is signed off (e.g. during `/speckit-bug-test` or `/speckit-converge`), the agent MUST verify the visual presentation of the running application and embed the genuine captured screenshot (`verification_visual_evidence.png` / `real_evidence_*.png`) into the verification report (`test.md`).
- **Prohibition on Purely Static / Headless Verification**: An agent is STRICTLY FORBIDDEN from diagnosing a UI defect or declaring a UI bug fix / frontend feature complete based solely on compilation success (`dotnet build`), static code inspection, or headless unit tests whenever visual presentation, layout templates, user interaction, or localization strings are involved.

## Technology Stack & Security Constraints

- **Platform & Runtime**: .NET 10 (`net10.0-windows10.0.26100.0`), C# (Language Version `preview`), Windows App SDK (WinUI 3).
- **Core Presentation Libraries**: `Microsoft.WindowsAppSDK` (WinUI 3 controls, Theme management, TabView), `WinUIEx` (window management), `CommunityToolkit.Mvvm` (MVVM Toolkit v8.4+).
- **Host & Dependency Injection**: `Microsoft.Extensions.Hosting` (Generic Host, `IServiceCollection`, hosted application lifecycle).
- **Database Engine**: `MySqlConnector` (high-performance async MySQL/MariaDB driver), `System.IO.Hashing` (fast data integrity checks).
- **Inter-Process Communication (IPC)**: Per-process Named Pipe Server with Windows Access Control Lists (ACL) supporting multi-instance process concurrency.
- **Internationalization (i18n)**: `TranslationSource` with `INotifyPropertyChanged` indexer, `.resx` resource bundles (`String.resx`, `String.en.resx`, `String.vi.resx`) encoded in UTF-8 without BOM, supporting live language switching (English, Vietnamese).
- **UI Automation & Verification**: Windows UI Automation (`System.Windows.Automation`), Win32 Interactive Desktop (`WinSta0\default`), Physical Cursor Dispatch (`SetCursorPos`/`mouse_event`), High-Fidelity `PW_RENDERFULLCONTENT` Screen Capture, Standardized Runner (`scripts/test-real-desktop.ps1`, `scripts/verify-real-end-to-end.ps1`).

## Development Workflow & Quality Gates

- **Zero-Error Compilation Gate**: Every pull request and committed change MUST compile cleanly (`dotnet build DataSphere\DataSphere.csproj -c Debug`) with 0 errors and 0 warnings.
- **Documentation Verification Gate**: All modified or introduced methods, properties, and types MUST meet 100% English XML documentation requirements.
- **Internationalization (i18n) Gate**: All newly introduced or modified UI elements, commands, and viewmodels MUST NOT contain hardcoded user-facing strings; all user text MUST use `TranslationSource` / `.resx` keys with verified UTF-8 encoding.
- **Diagnostic Reproduction Gate**: Every bug assessment involving UI behavior, window interaction, or visual anomalies MUST produce live reproduction evidence (UI element inspection trace or screenshot) captured via automated UI tooling on `WinSta0\default` during the assessment phase and documented in `assess.md`.
- **Zero-Pollution XAML Gate**: Automated UI testing MUST NOT add `AutomationId` or testing markers to production XAML files. Production views must remain clean and decoupled.
- **Zero-Speculation Live UI Verification Gate**: Every frontend feature, UI modification, or defect remediation MUST execute live end-to-end automated UI testing on `WinSta0\default` with verified physical mouse interaction and capture real visual evidence before handoff. Handing off with guesswork, assumptions, or speculative claims ("I guess it works") is an explicit constitutional violation.
- **Visual Evidence Verification Gate**: Every frontend feature or bug fix MUST provide visual evidence (screenshot of running UI on real desktop) captured via automated UI tooling to prove layout rendering, non-emptiness, and correct typography before handoff.
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

**Version**: 1.5.0 | **Ratified**: 2026-10-19 | **Last Amended**: 2026-10-20
