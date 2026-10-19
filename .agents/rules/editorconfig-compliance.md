---
description: 'Mandatory workspace-wide .editorconfig formatting, C# syntax conventions, naming rules, and proprietary closed-source copyright file header enforcement.'
applyTo: '**/*.cs, **/*.csproj, **/*.sln, **/*.slnx, **/*.json, **/*.xml, **/*.md'
---

# editorconfig-compliance

> All source, configuration, build, and documentation files MUST strictly adhere to the root `.editorconfig` rules, Roslyn diagnostic severities, and proprietary header requirements.

## Why It Matters

Nexa Optimizer is a Tier-1 Enterprise native Windows ecosystem. The root `.editorconfig` serves as the Single Source of Truth (SSOT) across all languages and build assets.
Strict adherence guarantees:
- **Zero Style Drift**: Prevents noisy diffs, conflicting indentation styles (spaces vs tabs), and broken IDE analyzers.
- **Legal & IP Protection**: Mandates the approved 4-line proprietary closed-source copyright header on every single C# file.
- **Modern C# Discipline**: Guarantees file-scoped namespaces, top-level usings outside namespaces, Allman braces, and explicit typing for clean maintainability.
- **Automated Validation**: Aligns directly with Roslyn diagnostics (`IDE0073`, `IDE0065`, `IDE0161`, `IDE0005`, `IDE0008`) and CI/CD quality gates.

---

## Multi-Scope Formatting Matrix

| File Pattern | Indent Size | Indent Style | Charset | Additional Rules |
|---|---|---|---|---|
| `[*]` | 4 | Space | UTF-8 | No trailing whitespace, `insert_final_newline = false` |
| `[*.{sln,slnx}]` | 4 | Tab | UTF-8 | Visual Studio solution files require tab indentation |
| `[*.{json,xml,yml,config,runsettings}]` | 2 | Space | UTF-8 | Standard compact formatting for configuration files |
| `[*.{slnf,props,targets,projitems,csproj,shproj}]` | 2 | Space | UTF-8 | MSBuild project and targets files |
| `[*.md]` | 2 | Space | UTF-8 | Markdown files require `insert_final_newline = true` |
| `[*.cs]` | 4 | Space | UTF-8 | Allman braces, file-scoped namespaces, proprietary header |

---

## Mandatory C# Rules (Roslyn Analyzers)

### 1. Mandatory Proprietary File Header (`IDE0073 = warning`)
Every C# file (`*.cs`) MUST begin with the exact 4-line proprietary closed-source header:

```csharp
// Copyright (c) Nexa Optimizer. All rights reserved.
// Licensed under the proprietary and confidential license.
// Unauthorized copying, distribution, modification, or disclosure of this file,
// via any medium, is strictly prohibited without prior written permission.
```

### 2. File-Scoped Namespaces (`IDE0161 = warning`)
- **NEVER** use block-scoped namespaces with enclosing braces `{ }`.
- **ALWAYS** use file-scoped namespace declarations:

```csharp
// GOOD
namespace NexaOptimizer.UI.ViewModels;

// BAD: Block-scoped namespace
namespace NexaOptimizer.UI.ViewModels
{
    public class SampleViewModel { }
}
```

### 3. Using Directives Outside Namespace (`IDE0065 = warning`)
- **NEVER** place `using` directives inside namespace declarations.
- Place all `using` directives immediately after the file header, before the namespace declaration.

### 4. Explicit Typing vs `var` (`csharp_style_var_elsewhere = false:warning`)
- Favor explicit types over `var` whenever the type is not immediately obvious from the right-hand assignment.
- Keep types readable and strongly-typed.

### 5. Braces Required (`csharp_prefer_braces = true:warning`)
- **ALWAYS** wrap single-line control flow bodies (`if`, `else`, `for`, `foreach`, `while`) in braces `{}`:

```csharp
// GOOD
if (condition)
{
    ExecuteAction();
}

// BAD
if (condition) ExecuteAction();
```

### 6. Naming Conventions
- **Classes, Structs, Enums, Delegates, Methods, Properties**: `PascalCase`.
- **Interfaces**: `I` prefix + `PascalCase` (`prefix_interface_interface_with_i`).
- **Private Fields**: `_` prefix + `camelCase` (`prefix_private_field_with_underscore`).
- **Parameters & Local Variables**: `camelCase`.
- **Async Methods**: MUST end with `Async` suffix (`end_in_async`).

---

## Agent Enforcement Checklist

Before proposing or applying any changes to files in this repository:
1. Verify that the file header matches the proprietary license template.
2. Confirm indentation: 4 spaces for C#, 2 spaces for JSON/XML/MSBuild/Markdown, tabs for `.sln`.
3. Check namespace style (file-scoped only).
4. Run `dotnet build src/NexaOptimizer.UI/NexaOptimizer.UI.csproj -c Debug` to confirm 0 errors and 0 warnings.
