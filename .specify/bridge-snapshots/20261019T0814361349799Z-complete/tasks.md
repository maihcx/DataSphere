# Tasks: DataSphere Platform Baseline

**Feature**: `001-platform-baseline` | **Date**: 2026-10-19 | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, toolchain verification, and coding standards validation

- [x] T001 Verify project file configuration and SDK target in DataSphere/DataSphere.csproj (Target: net10.0-windows7.0, LangVersion: preview, UseWPF: true)
- [x] T002 [P] Verify NuGet package references in DataSphere/DataSphere.csproj (CommunityToolkit.Mvvm v8.4.2, Microsoft.Extensions.Hosting v10.0.0, MySqlConnector v2.4.0, System.IO.Hashing v10.0.0)
- [x] T003 [P] Verify .editorconfig rules, C# style conventions, and file headers across all project items per .agents/rules/editorconfig-compliance.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core domain models, service contracts, and DI infrastructure that MUST be complete before ANY user story can proceed

**⚠️ CRITICAL**: No user story implementation may begin until this foundational phase is verified

- [x] T004 Define domain entity ConnectionProfile in DataSphere/Models/ConnectionProfile.cs with constraints: Name "1 - 100 characters, non-empty", Port "Range: 1 - 65535, Default: 3306", ConnectionTimeout "Range: 1 - 120, Default: 15"
- [x] T005 [P] Define DatabaseObjectNode model and DatabaseObjectType enum in DataSphere/Models/DatabaseObjectNode.cs
- [x] T006 [P] Define ApplicationSettings model and ConnectionTestResult value object in DataSphere/Models/ApplicationSettings.cs
- [x] T007 [P] Define service interfaces IConnectionService, IDatabaseExplorerService, and IApplicationStateService in DataSphere/Services/Contracts/
- [x] T008 Configure Generic Host Dependency Injection container in DataSphere/App.xaml.cs for singleton and transient service registrations

**Checkpoint**: Foundation ready - user story implementation can proceed in priority order or in parallel

---

## Phase 3: User Story 1 - Application Launch, Single-Instance Safety & Navigation Shell (Priority: P1) 🎯 MVP

**Goal**: Deliver a reliable, fast-starting desktop application shell that enforces single-instance Mutex protection and provides smooth Fluent navigation

**Independent Test**: Launch DataSphere, verify single-instance mutex blocks duplicate instances by focusing the existing window via Named Pipe IPC, and navigate between views without UI stutter

### Implementation for User Story 1

- [x] T009 [P] [US1] Implement single-instance Mutex check and background Named Pipe IPC server in DataSphere/Bootstrap.cs using UniqueAppId Global\DataSphere.SingleInstance.App
- [x] T010 [P] [US1] Implement application startup lifecycle and window activation handling in DataSphere/Services/ApplicationHostService.cs
- [x] T011 [US1] Implement UI-agnostic navigation commands and view state in DataSphere/ViewModels/Windows/MainWindowViewModel.cs
- [x] T012 [US1] Implement Fluent Design 2 navigation shell and window title bar in DataSphere/Views/Windows/MainWindow.xaml and DataSphere/Views/Windows/MainWindow.xaml.cs
- [x] T013 [US1] Validate single-instance launch and navigation frame time (<16ms) per Section 3 of specs/001-platform-baseline/quickstart.md

**Checkpoint**: User Story 1 is fully functional and delivers an independently testable MVP shell

---

## Phase 4: User Story 2 - Secure Database Connection Management & Testing (Priority: P1)

**Goal**: Enable users to create, test, and save database connection profiles with credentials encrypted at rest

**Independent Test**: Open connection dialog, input connection parameters, run asynchronous "Test Connection", observe non-blocking diagnostic results, save profile, and verify encrypted storage on disk

### Implementation for User Story 2

- [x] T014 [P] [US2] Implement DPAPI / AES-GCM credential encryption and decryption routines in DataSphere/Utils/PasswordEncryptor.cs
- [x] T015 [P] [US2] Implement connection profile persistence service in DataSphere/Services/ConnectionStorageService.cs with encrypted credential storage
- [x] T016 [US2] Implement asynchronous MySQL connection testing in DataSphere/Services/Database/ConnectionService.cs with CancellationToken support and error code parsing
- [x] T017 [US2] Implement ConnectionEditingViewModel in DataSphere/ViewModels/Pages/ConnectionEditingViewModel.cs with RelayCommand bindings for TestConnection and Save
- [x] T018 [US2] Implement non-blocking connection dialog view in DataSphere/Dialogs/Views/ConnectionEditing.xaml using IContentDialogService
- [x] T019 [US2] Validate connection test responsiveness and encrypted credential persistence per Section 4 of specs/001-platform-baseline/quickstart.md

**Checkpoint**: User Story 2 is complete; database connections can be tested and persisted securely

---

## Phase 5: User Story 3 - Database Schema & Object Exploration (Priority: P2)

**Goal**: Provide users with a hierarchical tree view to inspect database catalogs, tables, views, and column definitions asynchronously

**Independent Test**: Select an active connection, expand database nodes, and observe asynchronous lazy-loading of tables and columns with CancellationToken cancellation support

### Implementation for User Story 3

- [x] T020 [P] [US3] Implement asynchronous catalog and table introspection queries in DataSphere/Services/Database/DatabaseExplorerService.cs using MySqlConnector
- [x] T021 [US3] Implement column metadata retrieval (data type, primary key, nullability) in DataSphere/Services/Database/DatabaseExplorerService.cs
- [x] T022 [US3] Implement DatabaseExplorerViewModel in DataSphere/ViewModels/Pages/DatabaseExplorerViewModel.cs with lazy-loaded tree nodes and cancellation handling
- [x] T023 [US3] Implement database explorer tree view in DataSphere/Views/Pages/DatabaseExplorerPage.xaml with UI virtualization
- [x] T024 [US3] Validate schema loading performance and cancellation responsiveness per quickstart guide in specs/001-platform-baseline/quickstart.md

**Checkpoint**: User Story 3 is complete; users can browse database schemas hierarchically

---

## Phase 6: User Story 4 - Visual Theme & Internationalization Preferences (Priority: P2)

**Goal**: Provide runtime theme switching (Dark/Light/System) and multi-language localization (English and Vietnamese)

**Independent Test**: Toggle theme and language in Settings; observe instant visual update across all views and dialogs without restarting the application

### Implementation for User Story 4

- [x] T025 [P] [US4] Configure string resource dictionary tables for en-US and vi-VN in DataSphere/Resources/Locales/
- [x] T026 [P] [US4] Implement dynamic runtime language switching in DataSphere/Utils/Translations.cs via TranslationSource
- [x] T027 [US4] Implement theme management and system theme synchronization in DataSphere/Services/ApplicationThemeManager.cs using Wpf.Ui IThemeService
- [x] T028 [US4] Implement SettingsViewModel in DataSphere/ViewModels/PagesBottom/SettingsViewModel.cs for theme and locale selection
- [x] T029 [US4] Implement settings view in DataSphere/Views/PagesBottom/SettingsPage.xaml using Fluent cards and toggle controls
- [x] T030 [US4] Validate runtime theme and language switching per Section 5 of specs/001-platform-baseline/quickstart.md

**Checkpoint**: User Story 4 is complete; full accessibility, theming, and localization operational

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: System-wide compliance, documentation completeness, security audit, and zero-error verification

- [x] T031 [P] Ensure 100% US English XML doc comments (/// <summary>, <param>, <returns>) across all classes, interfaces, and methods per .agents/rules/code-documentation-english.md
- [x] T032 [P] Audit log files and error handlers to ensure zero plain-text password leakage per .agents/rules/obs-no-sensitive-data.md
- [x] T033 Verify Clean MVVM boundary: confirm zero System.Windows.* visual tree imports in DataSphere/ViewModels/
- [x] T034 Execute full project compilation via dotnet build DataSphere/DataSphere.csproj -c Debug and verify 0 Warnings and 0 Errors
- [x] T035 Execute end-to-end quickstart validation scenarios defined in specs/001-platform-baseline/quickstart.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — executes immediately
- **Foundational (Phase 2)**: Depends on Phase 1 completion — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Phase 2 — MVP target
- **User Story 2 (Phase 4)**: Depends on Phase 2 — Integrates with US1 shell
- **User Story 3 (Phase 5)**: Depends on Phase 4 connection management
- **User Story 4 (Phase 6)**: Depends on Phase 2 — Can run in parallel with US2/US3
- **Polish (Phase 7)**: Depends on all user stories completing

### Parallel Opportunities

- Tasks marked `[P]` within Phase 1, Phase 2, and within each story phase can be executed concurrently
- US1 (Shell), US2 (Connection Service), and US4 (Theming & I18n) have clean boundaries and can proceed in parallel once Phase 2 completes

---

## Implementation Strategy

### MVP First (Phases 1, 2, 3)
1. Complete Phase 1 Setup and Phase 2 Foundational models.
2. Complete Phase 3 (US1: Single-instance shell and navigation).
3. Validate MVP: Application launches under 2s with Mica/Acrylic Fluent theme and single-instance IPC.

### Incremental Delivery (Phases 4, 5, 6, 7)
1. Add Phase 4 (US2: Connection profiles & DPAPI encryption).
2. Add Phase 5 (US3: Schema introspection tree).
3. Add Phase 6 (US4: Dark/Light theming & English/Vietnamese i18n).
4. Run Phase 7 Polish (100% XML doc comments, 0 warnings build, security audit).
