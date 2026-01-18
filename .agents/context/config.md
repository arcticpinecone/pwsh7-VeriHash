# VeriHash Configuration Context

Project-specific configuration guidance for VeriHash development.

## VeriHash Configuration Architecture

VeriHash uses a unified configuration system that merges settings from multiple sources with a clear priority order:

1. **Environment variables** (highest priority)
2. **Config file** (`config.json`)
3. **Defaults** (lowest priority)

### Module Dependencies

```powershell
# Config module (no external dependencies)
. .\VeriHash.Config.ps1
```

### File Locations

```bash
VeriHash/
├── VeriHash.Config.ps1           # Configuration functions
└── Tests/
    └── VeriHash.Config.Tests.ps1 # Config tests (25 tests)
```

### Config File Location

- **Windows**: `$env:APPDATA\VeriHash\config.json`
- **Linux/macOS**: `~/.verihash/config.json`

---

## Configuration Schema

```json
{
  "logging": {
    "level": "INFO",
    "file": true,
    "console": true
  },
  "virustotal": {
    "apiKey": "",
    "enabled": true,
    "preferApi": true,
    "autoOpen": false
  }
}
```

### Logging Settings

| Setting | Type | Default | Description |
| ------- | ---- | ------- | ----------- |
| `level` | string | `INFO` | Log level: DEBUG, VERBOSE, INFO, WARNING, ERROR, NONE |
| `file` | bool | `true` | Enable file logging |
| `console` | bool | `true` | Enable console logging |

### VirusTotal Settings

| Setting | Type | Default | Description |
| ------- | ---- | ------- | ----------- |
| `apiKey` | string | `""` | VirusTotal API key |
| `enabled` | bool | `true` | Enable VirusTotal integration |
| `preferApi` | bool | `true` | Prefer API over browser fallback |
| `autoOpen` | bool | `false` | Auto-open browser for results |

---

## Environment Variables

Environment variables override config file values:

| Variable | Config Path | Example |
| -------- | ----------- | ------- |
| `VERIHASH_LOG_LEVEL` | `logging.level` | `DEBUG` |
| `VERIHASH_LOG_FILE` | `logging.file` | `true` / `false` |
| `VERIHASH_LOG_CONSOLE` | `logging.console` | `true` / `false` |
| `VERIHASH_VT_APIKEY` | `virustotal.apiKey` | `your-api-key` |
| `VERIHASH_VT_ENABLED` | `virustotal.enabled` | `true` / `false` |

---

## Using the Config Functions

### Load Configuration

```powershell
. .\VeriHash.Config.ps1

# Load merged configuration
$config = Get-VeriHashConfig
Write-Host "Log level: $($config.logging.level)"
Write-Host "VT enabled: $($config.virustotal.enabled)"
```

### Track Configuration Sources

```powershell
# Include source tracking to see where each setting came from
$config = Get-VeriHashConfig -IncludeSource

$config._source.'logging.level'      # 'default', 'file', or 'env'
$config._source.'virustotal.apiKey'  # 'default', 'file', or 'env'
```

### Save Configuration

```powershell
$config = Get-VeriHashConfig
$config.logging.level = 'DEBUG'
Set-VeriHashConfig -Config $config
```

### Initialize on First Run

```powershell
# Creates config directory and default config.json if they don't exist
$config = Initialize-VeriHashConfig

# Force overwrite existing config with defaults
$config = Initialize-VeriHashConfig -Force
```

### Get Config Path

```powershell
$configDir = Get-VeriHashConfigPath
# Windows: C:\Users\<user>\AppData\Roaming\VeriHash
# Linux:   /home/<user>/.verihash
```

---

## Integration with VeriHash.ps1

The config module is designed to be dot-sourced into VeriHash.ps1:

```powershell
# In VeriHash.ps1
. "$PSScriptRoot\VeriHash.Config.ps1"

# Initialize config on startup
$script:Config = Initialize-VeriHashConfig

# Use config values
if ($script:Config.virustotal.enabled) {
    # VirusTotal integration code
}
```

---

## Logging in Config Module

The config module logs operations when PSFramework is available:

- **Debug level**: Config loading start, file read, env var application
- **Verbose level**: Config initialization, file creation
- **Warning level**: Invalid values, malformed JSON, validation errors

Example log output:
```
[Debug] Loading VeriHash configuration
[Debug] Loaded configuration from file
[Warning] Invalid log level in config file: INVALID
[Debug] Configuration loaded - LogLevel: INFO, Source: default
```

---

## Testing Configuration

```powershell
# Run config tests
Invoke-Pester -Path './Tests/VeriHash.Config.Tests.ps1'

# Test with custom config directory
$testDir = Join-Path $TestDrive "ConfigTest"
$config = Get-VeriHashConfig -ConfigDirectory $testDir
```

---

## Config Validation

The module validates:

- **Log levels**: Must be one of DEBUG, VERBOSE, INFO, WARNING, ERROR, NONE
- **Boolean values**: Coerced to `$true`/`$false`
- **JSON format**: Malformed JSON falls back to defaults with warning

Invalid values are logged and replaced with defaults.

---

## Related Files

- `VeriHash.Config.ps1` - Configuration module
- `Tests/VeriHash.Config.Tests.ps1` - Configuration tests
- `.agents/context/logging.md` - Logging context (uses config for settings)
