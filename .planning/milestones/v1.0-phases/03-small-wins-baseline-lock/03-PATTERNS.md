# Phase 3: Small Wins & Baseline Lock - Pattern Map

**Mapped:** 2026-04-18
**Files analyzed:** 3 (modified)
**Analogs found:** 3 / 3

## File Classification

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `VeriHash.ps1` (line 152) | config/init | request-response | Self — `VeriHash.ps1` lines 152-158 | exact (same call, add params) |
| `VeriHash.Config.ps1` (line 86) | config | CRUD | Self — `VeriHash.Config.ps1` lines 78-91 | exact (same hashtable, flip value) |
| `Tests/VeriHash.Config.Tests.ps1` (lines 100, 127, 180) | test | request-response | Self — `Tests/VeriHash.Config.Tests.ps1` lines 94-103 | exact (same assertions, flip expected) |

## Pattern Assignments

### `VeriHash.ps1` — Add log rotation params (config/init, request-response)

**Analog:** Self — the existing `Set-PSFLoggingProvider` call is the pattern; two parameters are appended.

**Surrounding context** (lines 149-158) — shows the existing call with inline comment style and backtick continuation:
```powershell
    # Configure file logging provider (JSON format for agent/programmatic parsing)
    # Data Minimization: Headers exclude File/ComputerName/Username; -Data paths sanitized
    # Reference: GDPR Article 5(1)(c), OWASP Logging Cheat Sheet, CWE-532
    Set-PSFLoggingProvider -Name 'logfile' -InstanceName 'VeriHash' `
        -FilePath (Join-Path $script:VeriHashLogPath "verihash-%date%.json") `
        -FileType Json `
        -JsonCompress $true `
        -UTC $true `
        -Headers 'FunctionName', 'Level', 'Line', 'Message', 'ModuleName', 'Runspace', 'Tags', 'TargetObject', 'Timestamp', 'Type', 'Data' `
        -Enabled $true
```

**Target state** — insert `-LogRotatePath` and `-LogRetentionTime` after `-UTC $true` (before `-Headers`), maintaining identical formatting:
```powershell
    Set-PSFLoggingProvider -Name 'logfile' -InstanceName 'VeriHash' `
        -FilePath (Join-Path $script:VeriHashLogPath "verihash-%date%.json") `
        -FileType Json `
        -JsonCompress $true `
        -UTC $true `
        -LogRotatePath $script:VeriHashLogPath `
        -LogRetentionTime "30d" `
        -Headers 'FunctionName', 'Level', 'Line', 'Message', 'ModuleName', 'Runspace', 'Tags', 'TargetObject', 'Timestamp', 'Type', 'Data' `
        -Enabled $true
```

**Key conventions to preserve:**
- 8-space indent for continuation lines (4 for the enclosing block + 4 for parameter alignment)
- Backtick line-continuation on every parameter line except the last
- `$script:VeriHashLogPath` variable is already available in scope (set at line 138-142)

**Variable availability** (lines 136-142):
```powershell
    $isTestMode = $env:VERIHASH_TEST_MODE -eq '1'
    $baseLogPath = Get-VeriHashLogPath
    $script:VeriHashLogPath = if ($isTestMode) {
        Join-Path $baseLogPath "test"
    } else {
        $baseLogPath
    }
```

---

### `VeriHash.Config.ps1` — Flip VT default (config, CRUD)

**Analog:** Self — the `Get-VeriHashDefaultConfig` hashtable at lines 78-91.

**Current code** (lines 78-91):
```powershell
    @{
        logging = @{
            level   = 'INFO'
            file    = $true
            console = $true
        }
        virustotal = @{
            apiKey    = ''
            enabled   = $true
            preferApi = $true
            autoOpen  = $false
        }
    }
```

**Change:** Line 86 — `enabled   = $true` → `enabled   = $false` (preserve alignment spacing: 3 spaces before `=`).

**Key conventions to preserve:**
- Alignment: `apiKey    = ''` uses 4 spaces, `enabled   = $true` uses 3 spaces (matching 10-char column)
- Boolean casing: `$true` / `$false` (lowercase, standard PowerShell)

---

### `Tests/VeriHash.Config.Tests.ps1` — Update 3 VT default assertions (test, request-response)

**Analog:** Self — existing Pester test pattern with `# Arrange / # Act / # Assert` comment blocks.

**Test pattern** (lines 94-103) — the `It` block structure used throughout:
```powershell
        It 'Has correct default virustotal values' {
            # Act
            $result = Get-VeriHashDefaultConfig

            # Assert
            $result.virustotal.apiKey | Should -Be ''
            $result.virustotal.enabled | Should -Be $true
            $result.virustotal.preferApi | Should -Be $true
            $result.virustotal.autoOpen | Should -Be $false
        }
```

**Three assertions to change:**

1. **Line 100** (in `Has correct default virustotal values`):
   ```powershell
   # Before:
               $result.virustotal.enabled | Should -Be $true
   # After:
               $result.virustotal.enabled | Should -Be $false
   ```

2. **Line 127** (in `When no config file exists - Returns default configuration`):
   ```powershell
   # Before:
               $result.virustotal.enabled | Should -Be $true
   # After:
               $result.virustotal.enabled | Should -Be $false
   ```

3. **Line 180** (in `Merges partial config with defaults`):
   ```powershell
   # Before:
               $result.virustotal.enabled | Should -Be $true  # Default
   # After:
               $result.virustotal.enabled | Should -Be $false  # Default
   ```

**Key conventions to preserve:**
- 12-space indent for assertions inside `It` blocks
- `# Default` trailing comment on line 180 (keep it)
- Pester 5.x `Should -Be` syntax (not legacy `Should Be`)

---

## Shared Patterns

### Pester Test Structure
**Source:** `Tests/VeriHash.Config.Tests.ps1` (entire file)
**Apply to:** All test modifications and any new log rotation tests

```powershell
# File-level imports in BeforeAll block (lines 1-13):
BeforeAll {
    $script:LogUtilsPath = "$PSScriptRoot\..\VeriHash.LogUtils.ps1"
    . $script:LogUtilsPath
    $script:ConfigPath = "$PSScriptRoot\..\VeriHash.Config.ps1"
    . $script:ConfigPath
    $script:TestConfigDir = Join-Path $TestDrive "ConfigTests"
    New-Item -ItemType Directory -Path $script:TestConfigDir -Force | Out-Null
}

# Each It block follows Arrange/Act/Assert with comments:
It 'Description' {
    # Arrange
    ...
    # Act
    $result = SomeFunction
    # Assert
    $result.property | Should -Be $expected
}
```

### PSFramework Logging Integration Test Pattern
**Source:** `Tests/VeriHash.Tests.ps1` lines 1001-1050
**Apply to:** Any new log rotation verification test (Wave 0 gap)

```powershell
# PSFramework availability gating (lines 1001-1010):
Describe 'PSFramework Logging Integration' {
    Context 'When PSFramework is available' {
        BeforeAll {
            $script:PSFrameworkInstalled = $null -ne (Get-Module -ListAvailable -Name PSFramework)
        }
        It 'Should have PSFrameworkAvailable variable set correctly' -Skip:(-not $script:PSFrameworkInstalled) {
            $script:PSFrameworkAvailable | Should -BeTrue
        }
    }
}
```

### PowerShell Script Formatting
**Source:** `VeriHash.ps1` lines 152-158
**Apply to:** All PowerShell file modifications

- Backtick line continuation for multi-parameter cmdlet calls
- 4-space base indent within `if`/`else` blocks
- 8-space indent for continuation parameters
- `$script:` scope for module-level variables
- Inline comments referencing compliance standards (GDPR, OWASP, CWE)

---

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| *(none)* | — | — | All 3 files are self-analogous modifications to existing code |

**Note:** If the planner decides to add a new `It` block in `Tests/VeriHash.Tests.ps1` for log rotation parameter verification (Wave 0 gap from RESEARCH.md), the pattern at lines 1001-1038 of that file is the exact analog to follow — it shows how to gate tests on PSFramework availability with `-Skip:(-not $script:PSFrameworkInstalled)`.

## Metadata

**Analog search scope:** Project root (`VeriHash.ps1`, `VeriHash.Config.ps1`, `Tests/`)
**Files scanned:** 5 (VeriHash.ps1, VeriHash.Config.ps1, VeriHash.LogUtils.ps1, Tests/VeriHash.Config.Tests.ps1, Tests/VeriHash.Tests.ps1)
**Pattern extraction date:** 2026-04-18
