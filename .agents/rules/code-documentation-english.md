# code-documentation-english

> All functions, methods, interfaces, and structs MUST have comprehensive documentation comments written in Standard Industry Technical English.

## Why It Matters

Nexa Optimizer is a high-performance native Windows system built with Rust and C# (WinUI 3). Maintaining Tier-1 Enterprise standards requires that every public or internal function, method, struct, and interface has precise, industry-standard documentation.
Writing doc comments in standard technical English (US English) ensures:
- Full compatibility with automated tooling (IntelliSense, rustdoc, DocFX, Copilot/Antigravity indexing).
- Long-term maintainability without ambiguity across international engineering teams.
- Clear specification of inputs, return values, failure modes, side effects, and safety invariants.

## Bad

```csharp
// BAD: Missing or trivial comments, non-English or colloquial
// Hàm lấy thông tin hệ thống
public SystemInfo GetInfo() 
{
    // ...
}

// BAD: Empty summary or meaningless filler
/// <summary>
/// Does do work.
/// </summary>
public async Task OptimizeAsync(int mode) { ... }
```

```rust
// BAD: No doc comment on public or complex function
pub fn apply_tweak(registry_key: &str, value: u32) -> Result<(), TweakError> {
    // ...
}

// BAD: Non-English doc comment
/// Áp dụng tinh chỉnh bộ nhớ RAM
pub fn purge_standby_list() -> Result<(), MemoryError> {
    // ...
}
```

## Good

```csharp
/// <summary>
/// Retrieves hardware telemetry and resource utilization metrics from the background service.
/// </summary>
/// <param name="cancellationToken">A token to observe for cancellation requests.</param>
/// <returns>
/// An immutable <see cref="SystemTelemetryDto"/> containing current CPU, RAM, and Disk metrics.
/// </returns>
/// <exception cref="InvalidOperationException">
/// Thrown when the IPC connection to <c>nexa_service</c> is not in an active or connected state.
/// </exception>
public async Task<SystemTelemetryDto> GetTelemetryAsync(CancellationToken cancellationToken = default)
{
    // ...
}
```

```rust
/// Triggers a working-set trim and standby list purge across system memory.
///
/// Communicates directly with the Windows Memory Manager via NT native APIs
/// to reclaim non-paged pool and unused memory segments.
///
/// # Arguments
///
/// * `target_processes` - Optional slice of process IDs to specifically trim. If `None`,
///   all non-whitelisted working sets are evaluated.
///
/// # Returns
///
/// Returns `Ok(MemoryCleanupResult)` specifying the total bytes reclaimed, or `Err(MemoryError)`
/// if privilege escalation or NT API invocation fails.
///
/// # Errors
///
/// Fails with `MemoryError::PrivilegeRequired` if the calling daemon lacks `SeProfileSingleProcessPrivilege`
/// or `SeIncreaseQuotaPrivilege`.
pub fn purge_memory_cache(target_processes: Option<&[u32]>) -> Result<MemoryCleanupResult, MemoryError> {
    // ...
}
```

## Key Points

1. **Standard Industry Technical English**: All code comments, docstrings (`///`), inline algorithmic explanations, and error messages MUST be written in clear, concise, professional technical English.
2. **C# XML Documentation**:
   - Every class, interface, method, property, and command MUST have a `/// <summary>`.
   - Every parameter MUST have a `/// <param name="...">` describing its purpose and valid ranges.
   - Non-void methods MUST have a `/// <returns>` describing the return payload.
   - Document known exceptions with `/// <exception>`.
3. **Rust Doc Comments**:
   - Every module MUST have an introductory `//!` comment.
   - Every public struct, enum, and function MUST have a `///` doc comment.
   - Include `# Arguments`, `# Returns`, `# Errors` sections wherever fallible operations occur.
   - Any `unsafe` block or function MUST have a detailed `// SAFETY:` or `# Safety` section justifying memory safety invariants.
4. **No Slang, No Placeholders**: Avoid filler text like "TODO: comment this later" or trivial restatements of the function name.
5. **Localization Separation**: Vietnamese or other local languages are reserved strictly for end-user UI strings (via `.resw` resource files and `nexa_i18n` bundles). Code-level comments belong exclusively to technical English.
