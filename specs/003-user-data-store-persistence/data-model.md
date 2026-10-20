# Phase 1: Data Model — User Preferences & State Persistence

**Feature**: `003-user-data-store-persistence`
**Date**: 2026-10-20
**Status**: Completed

## 1. Physical Storage Format (`userdata.json`)

The user preferences file is stored at:
`%LOCALAPPDATA%\DataSphere\userdata.json`

### JSON Schema & Key Registry

```json
{
  "IThemeType": "Dark",
  "Language": "vi",
  "IsWindow_Maximized": false,
  "Window_Left": 120.0,
  "Window_Top": 80.0,
  "Window_Width": 1280.0,
  "Window_Height": 800.0,
  "StartUpCode": "xv2",
  "IsAutoHideNavPanel": false
}
```

### Key Registry Table

| Key | Type | Default Value | Description |
|-----|------|---------------|-------------|
| `IThemeType` | `string` | `"Default"` | Active visual theme mode: `"Light"`, `"Dark"`, or `"Default"` (System Auto). |
| `Language` | `string` | `"en"` | Two-letter ISO language code: `"en"`, `"vi"`. |
| `IsWindow_Maximized` | `bool` | `false` | Whether the primary shell window was maximized when closed. |
| `Window_Left` | `double` | `100.0` | Horizontal pixel position of the primary window top-left corner. |
| `Window_Top` | `double` | `100.0` | Vertical pixel position of the primary window top-left corner. |
| `Window_Width` | `double` | `1280.0` | Physical width in pixels of the primary window (min 800.0). |
| `Window_Height` | `double` | `800.0` | Physical height in pixels of the primary window (min 500.0). |
| `StartUpCode` | `string` | `"xv2"` | State identifier indicating valid saved window bounds. |
| `IsAutoHideNavPanel` | `bool` | `false` | Optional navigation auto-hide preference. |

---

## 2. In-Memory Entities & Models

### 2.1 WindowPlacementState

Represents the physical bounds and window presentation state of a top-level window.

```csharp
public record WindowPlacementState
{
    public double Left { get; init; } = 100.0;
    public double Top { get; init; } = 100.0;
    public double Width { get; init; } = 1280.0;
    public double Height { get; init; } = 800.0;
    public bool IsMaximized { get; init; } = false;

    public bool IsValid => Width >= 800.0 && Height >= 500.0;
}
```

### 2.2 ThemeConfiguration

Represents the user's chosen theme and its mapping to platform element theme values.

```csharp
public enum AppThemeMode
{
    Default = 0,
    Light = 1,
    Dark = 2
}
```

### 2.3 StoredCredential (Encrypted Payload)

Represents sensitive data values that are encrypted prior to writing to the `userdata.json` store.

```csharp
public record EncryptedPreferenceEntry
{
    public string Key { get; init; } = string.Empty;
    public string CipherText { get; init; } = string.Empty;
}
```
Validation: `CipherText` must be valid Base64 string produced by `PasswordEncryptor.Encrypt()`. Plain text storage is strictly forbidden.
