# VeriHash Logging Guide

## Privacy-First Design

VeriHash logging follows **data minimization principles** (GDPR Article 5(1)(c), CWE-532, OWASP guidelines):

- **Paths are sanitized**: `C:\Users\username\...` becomes `%USERPROFILE%\...` (Windows) or `~` (Linux/macOS)
- **Opt-in only**: Logging is disabled by default
- **Note**: PSFramework adds ComputerName/Username metadata that cannot be disabled at the provider level

Path sanitization is the primary privacy protection—file paths often contain usernames and reveal directory structures.

## Log Location

Logs are written to:

- **Windows**: `%APPDATA%\VeriHash\logs\verihash-<date>.json`
- **Linux/macOS**: `~/.verihash/logs/verihash-<date>.json`

The logs use JSON lines format (one JSON object per line).

### Test Mode Logging

When running tests, logs are automatically redirected to a separate directory to avoid polluting production logs:

- **Windows**: `%APPDATA%\VeriHash\logs\test\verihash-<date>.json`
- **Linux/macOS**: `~/.verihash/logs/test/verihash-<date>.json`

Test mode is activated by setting the environment variable `VERIHASH_TEST_MODE=1`. The Pester test files handle this automatically.

## Enabling Logging

Logging requires the [PSFramework](https://psframework.org/) module and is **disabled by default**.

```powershell
# Install PSFramework (one-time)
Install-Module PSFramework -Scope CurrentUser

# Enable verbose logging
.\VeriHash.ps1 -LogLevel Verbose "file.exe"

# Enable debug logging (most detailed)
.\VeriHash.ps1 -LogLevel Debug "file.exe"

# Or set via environment variable (persists for session)
$env:VERIHASH_LOG_LEVEL = 'Verbose'
.\VeriHash.ps1 "file.exe"
```

## Viewing Logs

Use the LogUtils functions to read and analyze logs:

```powershell
# First, dot-source the utilities
. .\VeriHash.LogUtils.ps1

# Get the log path
Get-VeriHashLogPath
# Returns: C:\Users\user\AppData\Roaming\VeriHash\logs (sanitized in logs as %USERPROFILE%\...)

# Read all logs
ConvertFrom-VeriHashLog

# Filter by level or time
ConvertFrom-VeriHashLog -Days 7 -Level Warning

# Filter by tag
ConvertFrom-VeriHashLog -Tag 'Hash'

# Export to CSV for spreadsheet analysis
ConvertFrom-VeriHashLog -ExportCsv "my-logs.csv"

# Get a summary of recent activity
Get-VeriHashLogSummary -Days 30
```

## Working with Sanitized Paths

Logs contain sanitized paths for privacy. To expand them back to full paths (for local debugging only):

```powershell
# Expand a single path
ConvertFrom-SanitizedPath -Path '%USERPROFILE%\Downloads\file.exe'
# Returns: C:\Users\YourName\Downloads\file.exe

# Use with pipeline
$logs = ConvertFrom-VeriHashLog -Days 1
$logs | ForEach-Object {
    $_.FilePath | ConvertFrom-SanitizedPath
}
```

**Note**: Path expansion only works on the same machine where logs were created.

## Example Log Entry

```json
{
  "Timestamp": "2025-01-17T10:30:45.123Z",
  "Level": "Verbose",
  "Message": "Hash computed: ABC123...",
  "FunctionName": "Invoke-ComputeHash",
  "ModuleName": "VeriHash",
  "Tags": ["Hash", "Result"],
  "ComputerName": "DESKTOP-ABC123",
  "Username": "username",
  "Data": {
    "Path": "%USERPROFILE%\\Downloads\\file.exe",
    "Algorithm": "SHA256",
    "DurationMs": 42.5,
    "ThroughputMBs": 190.2
  }
}
```

Notice: Paths in `Data` are sanitized (`%USERPROFILE%`), but PSFramework adds `ComputerName` and `Username` metadata.

## Quick Test

To generate some test logs:

```powershell
. .\VeriHash.ps1
.\VeriHash.ps1 -LogLevel Debug ".\README.md"

# Then view them
. .\VeriHash.LogUtils.ps1
ConvertFrom-VeriHashLog -Days 1
```
