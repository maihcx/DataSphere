# Research: Tab Sleeping & Memory Saver Architecture

- **Feature**: `016-tab-sleeping-memory-saver`
- **Date**: 2026-10-23
- **Status**: Completed

## 1. Tab Sleeping Strategy in Modern Desktop Applications

### Decision
Implement a decoupled two-tier tab lifecycle policy:
1. **Tier 1 (Instant Keep-Alive / Hot Cache)**:
   - Inactive tabs that were recently viewed remain 100% alive in memory.
   - Switching back is 0ms (0 layout passes, 0 visual recreation, exact scroll offsets preserved).
2. **Tier 2 (Background Tab Sleeping / Cold Suspension)**:
   - When an inactive tab's idle duration exceeds the configured threshold (`TabSleepTimeoutMinutes`), it transitions from `TabLifecycleState.Background` to `TabLifecycleState.Sleeping`.
   - The tab triggers `ISleepableTabContent.Sleep()`, which clears visual element pools (`_rowPool.Clear(VirtualCanvas)`), stops compositor animations, and trims large query buffers, reducing per-tab memory consumption by >60%.
   - On selection, the tab triggers `ISleepableTabContent.WakeUp()`, restoring the active viewport seamlessly.

### Rationale
- Emulates the proven architecture of modern web browsers (Microsoft Edge Sleeping Tabs & Google Chrome Memory Saver).
- Eliminates the anti-pattern of disposing controls on every tab switch, while guaranteeing that dormant tabs do not hoard RAM indefinitely during multi-hour desktop sessions.

### Alternatives Considered
- **Dispose on every tab switch (Status Quo Antipattern)**: Rejected because it causes visual flash, stutter, layout recalculations, and broke `VirtualTable` interactivity when `Unloaded` called `Dispose()`.
- **Operating-system process suspension**: WinUI 3 desktop applications run as a single unpackaged/packaged Win32 process; suspending individual threads or processes is not applicable for intra-window tabs. In-app lifecycle coordination is the proper mechanism.

---

## 2. Idle Tracking & Background Scheduling

### Decision
Use a centralized, lightweight `DispatcherTimer` (or `System.Threading.PeriodicTimer`) running every 60 seconds within `TabService` / `ShellViewModel`.

### Rationale
- A 60-second polling interval produces near-zero CPU overhead (<0.01% CPU utilization).
- Evaluates `(DateTime.UtcNow - tab.LastActiveTime).TotalMinutes >= timeoutMinutes` only for non-selected, closable tabs where `CanSleep == true`.
- Exemption checks:
  - `tab.IsSelected == false` (active tab never sleeps).
  - `tab.IsClosable == true` (Home tab never sleeps).
  - `tab.HasUnsavedChanges == false` (tabs with pending edits never sleep).
  - Background queries / tasks not active.

### Alternatives Considered
- **Per-tab individual timers**: Creates timer proliferation (e.g. 20 timers for 20 tabs) and unnecessary thread pool churn. A single orchestrator timer is much cleaner and easier to cancel.

---

## 3. Settings Configuration & Persistence

### Decision
Integrate settings directly into `SettingsViewModel` and `SettingsPage.xaml` under a new section: **Performance & Memory (Hiệu năng & Bộ nhớ)**:
1. `ToggleSwitch`: "Tiết kiệm bộ nhớ cho tab nền" (`EnableTabMemorySaver`). Default: `true`.
2. `ComboBox`: "Thời gian chờ trước khi ngủ đông" (`TabSleepTimeoutMinutes`). Options: `5`, `15` (default), `30`, `60` minutes.
3. Persisted via `UserDataStoreService` (`SettingsModel.json` / `appsettings.json`) so user preferences survive restarts.

### Rationale
- Follows existing Fluent Design 2 card layout pattern established in `SettingsPage.xaml`.
- Adheres 100% to Principle VII: All labels, options, and descriptions are loaded from `String.resx`, `String.en.resx`, `String.vi.resx` via `TranslationSource`.

---

## 4. Visual Indication of Sleeping Tabs

### Decision
In `ShellWindow.xaml`, bind visual feedback to `TabItemModel.IsSleeping`:
- Subtle opacity adjustment on tab header (`Opacity = 0.65` when sleeping, `1.0` when active).
- Small sleep badge glyph (`\uEC46` - Moon icon or `\uE708`) displayed beside the title when `IsSleeping == true`.

### Rationale
- Gives immediate visual clarity to the user about why a tab might take a momentary rehydration frame when clicked after hours of inactivity.
- Matches user expectations from Edge and Chrome sleeping tab design.
