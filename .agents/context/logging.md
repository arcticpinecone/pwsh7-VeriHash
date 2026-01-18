# VeriHash Logging Context

Project-specific logging guidance for VeriHash development using PSFramework.

## VeriHash Logging Architecture

VeriHash uses PSFramework for structured logging, providing:

- Automatic metadata: timestamp, function name, file, line number, callstack
- Multiple output targets (console + file) simultaneously
- Built-in log rotation and retention
- In-memory message retrieval via `Get-PSFMessage` for debugging
- Rich filtering by tags, levels, and modules
- JSON format for agent/programmatic parsing

### Module Dependencies

```powershell
# Install PSFramework (required for logging)
Install-Module PSFramework -Scope CurrentUser
```

### File Locations

```bash
VeriHash/
├── VeriHash.ps1           # Main script (includes logging initialization)
├── VeriHash.LogUtils.ps1  # Log utilities (ConvertFrom-VeriHashLog)
└── Tests/
    ├── VeriHash.Tests.ps1         # Main tests (includes logging tests)
    └── VeriHash.LogUtils.Tests.ps1 # LogUtils tests
```

### Log File Location

- **Windows**: `%APPDATA%\VeriHash\logs\verihash-YYYY-MM-DD.json`
- **Linux/macOS**: `~/.verihash/logs/verihash-YYYY-MM-DD.json`

### Test Mode Logging

When `VERIHASH_TEST_MODE=1` is set, logs go to a separate directory:

- **Windows**: `%APPDATA%\VeriHash\logs\test\verihash-YYYY-MM-DD.json`
- **Linux/macOS**: `~/.verihash/logs/test/verihash-YYYY-MM-DD.json`

This prevents test runs from polluting production logs. The Pester test files set this automatically in `BeforeAll`.

---

## Configuration

### Parameters

```powershell
# LogLevel parameter
.\VeriHash.ps1 -FilePath "file.txt" -LogLevel Verbose
.\VeriHash.ps1 -FilePath "file.txt" -LogLevel Debug
.\VeriHash.ps1 -FilePath "file.txt" -LogLevel None   # Default
```

### Environment Variable Override

```powershell
$env:VERIHASH_LOG_LEVEL = "Debug"  # Overrides -LogLevel parameter
```

---

## Log Levels

VeriHash uses PSFramework message levels:

| PSFramework Level | VeriHash Use For | Console Visibility |
| ----------------- | ---------------- | ------------------ |
| Debug | Detailed flow, internal state, function entry/exit | `-LogLevel Debug` |
| Verbose | Normal operations (hash computed, verification result) | `-LogLevel Verbose` |
| Warning | Unexpected but handled (missing sidecar, permission issues) | Always visible |
| Host | User-facing messages | Always visible |

---

## Log Format

**JSON Lines format** (one JSON object per line):

```json
{"Timestamp":"2026-01-17T09:30:00.000Z","Level":"Verbose","Message":"Computing SHA256 hash","FunctionName":"Get-And-SaveHash","Tags":["Hash","Compute"],"Data":{"Path":"C:\\file.iso","Algorithm":"SHA256","FileSizeBytes":1234567}}
```

### PSFramework JSON Format Notes

PSFramework writes logs with UTF-8 BOM and trailing commas (designed for JSON array concatenation). `ConvertFrom-VeriHashLog` handles this automatically:

- Strips UTF-8 BOM from file start
- Skips standalone comma lines (array format artifacts)
- Strips trailing commas from JSON lines before parsing

This allows seamless reading of logs without manual preprocessing.

### Converting to Human-Readable Format

```powershell
# Using LogUtils
. .\VeriHash.LogUtils.ps1
ConvertFrom-VeriHashLog -ExportCsv "report.csv"

# Quick inline conversion
Get-Content ~/.verihash/logs/verihash-*.json | ConvertFrom-Json | Format-Table
```

---

## Using Write-PSFMessage

### Basic Logging

```powershell
# Always check if PSFramework is available first
if ($script:PSFrameworkAvailable) {
    Write-PSFMessage -Level Verbose -Message "Operation completed" -Tag 'Hash', 'Result'
}
```

### Logging with Data

```powershell
if ($script:PSFrameworkAvailable) {
    Write-PSFMessage -Level Verbose -Message "Hash computed: $hashValue" -Tag 'Hash', 'Result' -Data @{
        Path = $FilePath
        Algorithm = $Algorithm
        Hash = $hashValue
        DurationMs = $duration.TotalMilliseconds
    }
}
```

### Function Entry/Exit Pattern

```powershell
function Invoke-SomeOperation {
    param($FilePath, $Algorithm)

    # Entry logging
    if ($script:PSFrameworkAvailable) {
        Write-PSFMessage -Level Debug -Message "Invoke-SomeOperation called" -Tag 'Entry' -Data @{
            FilePath = $FilePath
            Algorithm = $Algorithm
        }
    }

    try {
        # ... operation logic ...

        # Success logging
        if ($script:PSFrameworkAvailable) {
            Write-PSFMessage -Level Verbose -Message "Operation completed successfully" -Tag 'Success'
        }
        return $result
    }
    catch {
        # Error logging
        if ($script:PSFrameworkAvailable) {
            Write-PSFMessage -Level Warning -Message "Operation failed" -Tag 'Error' -ErrorRecord $_
        }
        throw
    }
}
```

---

## What to Log in VeriHash

### Always Log (Verbose level)

- **Hash computations:** File path, algorithm, size, duration, throughput
- **Verification outcomes:** Pass/fail/missing, summary stats
- **Installation operations:** Paths, success/failure
- **Errors:** Full context including inputs and exception details

### Log at Debug Level

- Function entry/exit with parameters
- Internal state changes
- Clipboard detection attempts
- Decision points (which code path was taken)

### Don't Log

- **Secrets:** Never log full hashes being compared (truncate to first 16 chars)
- **Full file contents:** Only log metadata (path, size)
- **Redundant info:** Don't repeat stack traces in message

---

## Standard Tags

Use consistent tags for filtering:

| Tag | Use For |
| --- | ------- |
| `Hash` | Hash computation operations |
| `Verify` | Verification operations |
| `Compute` | Computing a hash |
| `Result` | Operation result |
| `Entry` | Function entry |
| `Success` | Successful operation |
| `Error` | Error condition |
| `Install` | Installation operations |
| `Windows` | Windows-specific |
| `Linux` | Linux-specific |
| `KDE` | KDE-specific |
| `Clipboard` | Clipboard operations |

---

## Troubleshooting with Logs

### View Recent Logs

```powershell
# Import utilities
. .\VeriHash.LogUtils.ps1

# View all logs
ConvertFrom-VeriHashLog | Format-Table Timestamp, Level, Message -AutoSize

# Filter by level
ConvertFrom-VeriHashLog -Level Warning

# Filter by tag
ConvertFrom-VeriHashLog -Tag "Error"

# Last 7 days only
ConvertFrom-VeriHashLog -Days 7
```

### In-Memory Messages (PSFramework)

```powershell
# View recent messages in memory
Get-PSFMessage | Select-Object -Last 20

# Filter errors
Get-PSFMessage -Errors
```

### Get Summary

```powershell
. .\VeriHash.LogUtils.ps1
Get-VeriHashLogSummary -Days 30
```

---

## Testing Logging

```powershell
Describe "Logging" {
    It "Should not throw when logging is enabled" {
        { .\VeriHash.ps1 -FilePath "test.txt" -LogLevel Verbose } | Should -Not -Throw
    }

    It "Should create log directory" {
        .\VeriHash.ps1 -FilePath "test.txt" -LogLevel Debug
        Test-Path "~/.verihash/logs" | Should -BeTrue
    }
}
```

---

## Log File Management

**Rotation:** Daily files (`verihash-YYYY-MM-DD.json`)

**Retention:** PSFramework default retention (configurable)

**Location:**

- Windows: `$env:APPDATA\VeriHash\logs\`
- Linux/macOS: `~/.verihash/logs/`
