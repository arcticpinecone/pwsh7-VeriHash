# Testing Patterns

**Analysis Date:** 2026-04-17

## Test Framework

**Runner:**
- Pester (PowerShell testing framework)
- Minimum version: Pester 5.x (uses `New-PesterConfiguration` API)
- Config: no `pester.config.ps1` — configuration built inline in `Test-All.ps1`

**Assertion Library:**
- Pester built-in: `Should -Be`, `Should -Not -BeNullOrEmpty`, `Should -Match`, `Should -BeOfType`, `Should -Throw`, `Should -BeLessThan`, `Should -BeGreaterOrEqual`

**Static Analysis:**
- PSScriptAnalyzer with `PSScriptAnalyzerSettings.psd1`

**Run Commands:**
```powershell
# Run all tests + PSScriptAnalyzer + performance profiler
.\Test-All.ps1

# Run all tests only (skip PSScriptAnalyzer and profiler)
.\Test-All.ps1 -SkipAnalyzer -SkipProfiler

# Run PSScriptAnalyzer only
.\Test-All.ps1 -SkipTests -SkipProfiler

# Run in CI mode (exits with error code 1 if failures)
.\Test-All.ps1 -CI

# Run a single test file directly
Invoke-Pester .\Tests\VeriHash.Config.Tests.ps1 -Output Detailed

# Run via Pester configuration (as Test-All.ps1 does)
$config = New-PesterConfiguration
$config.Run.Path = ".\Tests"
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config
```

## TDD Rule (Critical)

**NEVER modify tests to make them pass. Always modify the production code.**

This is an explicit rule for this codebase. If a test fails, fix the implementation — not the test.

## Test File Organization

**Location:** All test files in `Tests\` directory

**Naming:** `VeriHash.[Component].Tests.ps1`

**Structure:**
```
Tests\
├── VeriHash.Tests.ps1          # Core hash operations (VeriHash.ps1 functions)
├── VeriHash.Config.Tests.ps1   # Configuration management (VeriHash.Config.ps1)
├── VeriHash.LogUtils.Tests.ps1 # Log utilities (VeriHash.LogUtils.ps1)
├── VeriHash.Timing.Tests.ps1   # Performance profiler (Profile-VeriHashTiming.ps1)
├── QuickHash.Tests.ps1         # QuickHash tool (QuickHash.ps1)
└── VeriHash_1024.ico           # Binary test fixture (real file for hash verification)
```

## Test Isolation (Mandatory)

**Always set test mode in `BeforeAll`:**

```powershell
BeforeAll {
    # Redirect logs to separate test directory (prevents polluting user's real logs)
    $env:VERIHASH_TEST_MODE = '1'

    # Dot-source the script under test
    . "$PSScriptRoot\..\VeriHash.ps1" -FilePath "dummy" -ErrorAction SilentlyContinue 2>$null

    # Use Pester's $TestDrive for all temp files — auto-cleaned after test run
    $script:TestOutputDir = Join-Path $TestDrive "VeriHashTests"
    New-Item -ItemType Directory -Path $script:TestOutputDir -Force | Out-Null
}
```

**Clean up in `AfterAll`:**

```powershell
AfterAll {
    Remove-Item Env:\VERIHASH_TEST_MODE -ErrorAction SilentlyContinue
}
```

**Clean environment variables between tests (`BeforeEach`):**

```powershell
BeforeEach {
    $env:VERIHASH_LOG_LEVEL   = $null
    $env:VERIHASH_LOG_FILE    = $null
    $env:VERIHASH_LOG_CONSOLE = $null
    $env:VERIHASH_VT_APIKEY   = $null
    $env:VERIHASH_VT_ENABLED  = $null
}
```

**`AfterEach` for file cleanup:**

```powershell
AfterEach {
    Get-ChildItem -Path $script:TestOutputDir -Filter "*.sha256" -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem -Path $script:TestOutputDir -Filter "*.md5"    -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem -Path $script:TestOutputDir -Filter "*.ico"    -ErrorAction SilentlyContinue | Remove-Item -Force
}
```

## Test Structure

**Hierarchy:** `Describe` → `Context` → `It`

```powershell
Describe 'Get-VeriHashConfig' {
    Context 'When no config file exists' {
        It 'Returns default configuration' {
            # Arrange
            $nonExistentPath = Join-Path $script:TestConfigDir "nonexistent"

            # Act
            $result = Get-VeriHashConfig -ConfigDirectory $nonExistentPath

            # Assert
            $result.logging.level | Should -Be 'INFO'
            $result.virustotal.enabled | Should -Be $true
        }
    }
}
```

**Arrange/Act/Assert comments** are used consistently throughout all test files. This is the required pattern for non-trivial tests.

**`It` naming convention:** Descriptive behavior statements that form readable sentences under their `Context`:
- `'Returns default configuration'`
- `'Environment variable overrides config file for log level'`
- `'Detects mismatched hash correctly (GNU coreutils format)'`

## Test Script Loading Patterns

### Dot-Sourcing Module Files (Config, LogUtils)

For pure module files with no script-level side effects:

```powershell
BeforeAll {
    $script:ConfigPath = "$PSScriptRoot\..\VeriHash.Config.ps1"
    . $script:ConfigPath

    $script:TestConfigDir = Join-Path $TestDrive "ConfigTests"
    New-Item -ItemType Directory -Path $script:TestConfigDir -Force | Out-Null
}
```

### Dot-Sourcing Scripts with Side Effects (VeriHash.ps1)

When the script runs on load, suppress errors via dummy parameters:

```powershell
# Pass -FilePath "dummy" and suppress errors — the script will fail gracefully
# Functions are still loaded into scope despite the error
. "$PSScriptRoot\..\VeriHash.ps1" -FilePath "dummy" -ErrorAction SilentlyContinue 2>$null
```

### Extracting Functions from Scripts (QuickHash.ps1)

For scripts with both function definitions and immediate interactive code, extract via regex and load into a temporary module:

```powershell
$scriptContent = Get-Content $script:QuickHashScriptPath -Raw

if ($scriptContent -match '(?s)(function Get-Hash \{.*?\n\})') {
    $tempModule = New-Module -ScriptBlock ([scriptblock]::Create($matches[1]))
    $tempModule | Import-Module -Global
}
```

## Mocking

**Framework:** Pester's built-in `Mock`

**Platform-conditional mocking** — mock only tools that exist on the current platform:

```powershell
if ($IsWindows) {
    Mock Get-Clipboard { return '5d41402abc4b2a76b9719d911017c592' }
} else {
    # Mock Linux clipboard tools conditionally
    if (Get-Command wl-paste -ErrorAction SilentlyContinue) {
        Mock wl-paste { return '5d41402abc4b2a76b9719d911017c592' }
    }
    if (Get-Command xclip -ErrorAction SilentlyContinue) {
        Mock xclip { return '5d41402abc4b2a76b9719d911017c592' }
    }
    if (Get-Command xsel -ErrorAction SilentlyContinue) {
        Mock xsel { return '5d41402abc4b2a76b9719d911017c592' }
    }
}
```

**Function mocking** (used for LogUtils path redirection):

```powershell
Mock Get-VeriHashLogPath { return $script:TestLogDir }
```

**What to Mock:**
- Platform-specific clipboard tools (`Get-Clipboard`, `wl-paste`, `xclip`, `xsel`)
- Functions that return environment-dependent paths (`Get-VeriHashLogPath`)
- External system calls that cannot be reliably controlled in tests

**What NOT to Mock:**
- File system operations — use `$TestDrive` (Pester's sandbox) instead
- Configuration file reads/writes — use `$TestDrive`-based temp directories
- Hash computation (`Get-FileHash`, `[System.Security.Cryptography.*]`) — tests verify real hash values

## Fixtures and Test Data

**Binary fixture:** `Tests\VeriHash_1024.ico` — a real icon file committed to the repo. Used across multiple test files for hash computation tests. Tests copy it to `$TestDrive` before use.

**Known hash constants** defined in `BeforeAll`:

```powershell
# In QuickHash.Tests.ps1
$script:HelloWorldMD5    = '65A8E27D8879283831B664BD8B7F0AD4'
$script:HelloWorldSHA256 = 'DFFD6021BB2BD5B0AF676290809EC3A53191DD81C7F70A4B28688A362182986F'
$script:FoxMD5           = '9E107D9D372BB6826BD81D3542A419D6'
$script:FoxSHA256        = 'D7A8FBB307D7809469CA9ABCB0082E4F8D5651E46D3CDB762D02D0BF37C9E592'
```

**Inline config fixtures** built directly in tests:

```powershell
@{
    logging    = @{ level = 'DEBUG'; file = $false; console = $true }
    virustotal = @{ apiKey = 'test-api-key'; enabled = $false }
} | ConvertTo-Json -Depth 3 | Set-Content $configFile
```

**JSON log fixtures** for LogUtils tests:

```powershell
$sampleEntries = @(
    '{"Timestamp":"2026-01-17T10:00:00.000Z","Level":"Verbose","Message":"Computing hash","FunctionName":"Get-And-SaveHash","Tags":["Hash","Compute"]}'
    '{"Timestamp":"2026-01-17T10:00:02.000Z","Level":"Warning","Message":"File not found","FunctionName":"Test-HashSidecar","Tags":["Verify","Error"]}'
)
$sampleEntries | Set-Content $script:SampleLogFile
```

**Large generated test files** for performance timing tests (`VeriHash.Timing.Tests.ps1`):

```powershell
# Auto-generates a 500MB binary file using seeded Random for reproducibility
$script:LargeFileSizeMB = 500
$buffer = [byte[]]::new(1MB)
$random = [System.Random]::new(42)   # Seeded — reproducible
$stream = [System.IO.File]::Create($script:GeneratedTestFile)
```

User-provided real files can override auto-generation via `$script:UserProvidedTestFiles = @("D:\ISOs\Win11.iso")`.

## Platform-Conditional Test Skipping

```powershell
It 'Returns Windows path on Windows' {
    if (-not ($PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform)) {
        Set-ItResult -Skipped -Because "Not running on Windows"
        return
    }

    $result = Get-VeriHashConfigPath
    $result | Should -Match 'AppData.*VeriHash'
}
```

Use `Set-ItResult -Skipped -Because "reason"` followed by `return` to skip platform-inappropriate tests cleanly. Do not use `if ($IsWindows) { ... }` to wrap assertions — always skip via `Set-ItResult`.

## Output Capture Pattern

For functions that produce console output via `Write-Host`, capture all streams:

```powershell
# Capture all output streams (*>&1) and convert to string for -Match assertions
$output = Test-HashSidecar -SidecarPath $sidecarPath *>&1
$outputString = $output | Out-String
$outputString | Should -Match 'OK.*✅'
$outputString | Should -Match 'FAILED.*🚫'
$outputString | Should -Match 'MISSING.*⚠️'
```

Also used in QuickHash tests:
```powershell
$output = Get-Hash -InputValue $script:TestFile1 -Algorithm "SHA256" *>&1 | Out-String
$output | Should -Match $script:HelloWorldSHA256
$output | Should -Match "Hash of the file"
```

## Data-Driven Tests (`-ForEach`)

Used in `VeriHash.Timing.Tests.ps1` for algorithm iteration:

```powershell
It 'Runs successfully with <Algorithm> algorithm' -ForEach @(
    @{ Algorithm = 'SHA256' }
    @{ Algorithm = 'MD5' }
    @{ Algorithm = 'SHA512' }
) {
    {
        & $script:ProfilerScript -FilePath $script:TestIconFile -Algorithm $Algorithm -Quiet
    } | Should -Not -Throw
}
```

## Performance Optimization in Tests

**Pre-compute expensive results in `BeforeAll`, reuse across all tests. Never repeat expensive operations per-test.**

Pattern from `VeriHash.Timing.Tests.ps1`:

```powershell
BeforeAll {
    # PERFORMANCE: Large files are profiled ONCE per algorithm in BeforeAll,
    # then results are reused across all tests. No redundant hashing.
    $script:IconResult_SHA256  = & $script:ProfilerScript -FilePath $script:TestIconFile -Algorithm SHA256 -Quiet
    $script:LargeResult_MD5    = & $script:ProfilerScript -FilePath $script:LargeTestFile -Algorithm MD5 -Quiet
    $script:LargeResult_SHA256 = & $script:ProfilerScript -FilePath $script:LargeTestFile -Algorithm SHA256 -Quiet
    $script:LargeResult_SHA512 = & $script:ProfilerScript -FilePath $script:LargeTestFile -Algorithm SHA512 -Quiet
}

# Individual tests reference $script:LargeResult_SHA256 — no re-execution
Describe 'Timing Profiler Measurements' {
    It 'Total time equals sum of individual measurements' {
        $result = $script:IconResult_SHA256   # ← reuse cached result
        $sum = ($result.Measurements.Values | Measure-Object -Sum).Sum
        [Math]::Abs($sum - $result.Total) | Should -BeLessThan 0.01
    }
}
```

## PSScriptAnalyzer as a Test

`VeriHash.LogUtils.Tests.ps1` includes an inline PSScriptAnalyzer check as a Pester test:

```powershell
Describe 'Code Quality - PSScriptAnalyzer' {
    It 'VeriHash.LogUtils.ps1 passes PSScriptAnalyzer with no warnings or errors' {
        if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
            Set-ItResult -Skipped -Because "PSScriptAnalyzer module is not installed"
            return
        }

        $results = Invoke-ScriptAnalyzer -Path $script:LogUtilsPath -Severity Warning, Error

        $results | Should -BeNullOrEmpty -Because "PSScriptAnalyzer found issues: $(
            $results | ForEach-Object { "`n  [$($_.Severity)] $($_.RuleName) at line $($_.Line): $($_.Message)" }
        )"
    }
}
```

## Round-Trip Testing Pattern

Config tests verify write→read fidelity:

```powershell
It 'Round-trips configuration correctly' {
    # Arrange
    $config = @{
        logging    = @{ level = 'DEBUG'; file = $false; console = $true }
        virustotal = @{ apiKey = 'roundtrip-key'; enabled = $false; autoOpen = $true }
    }

    # Act
    Set-VeriHashConfig -Config $config -ConfigDirectory $testDir
    $loaded = Get-VeriHashConfig -ConfigDirectory $testDir

    # Assert
    $loaded.logging.level          | Should -Be 'DEBUG'
    $loaded.virustotal.apiKey      | Should -Be 'roundtrip-key'
    $loaded.virustotal.autoOpen    | Should -Be $true
}
```

## Test Variable Scoping

- `$script:` prefix required for variables shared across `BeforeAll`, `AfterAll`, `Describe`, and `It` blocks
- Pester `$TestDrive` is always available as a temp filesystem path, auto-cleaned after the run
- Block-local variables (`$testDir`, `$result`, `$config`) remain unscoped — they are per-`It` locals

## Coverage

**Requirements:** No coverage threshold enforced; no `.coveragerc` or coverage config detected.

**Coverage collection** is not configured in `Test-All.ps1`. Coverage reports require manual Pester config:
```powershell
$config = New-PesterConfiguration
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = @('.\VeriHash.ps1', '.\VeriHash.Config.ps1', '.\VeriHash.LogUtils.ps1')
Invoke-Pester -Configuration $config
```

## Test Types

**Unit Tests:**
- `VeriHash.Config.Tests.ps1` — pure function unit tests; all I/O redirected via `-ConfigDirectory $testDir`
- `VeriHash.LogUtils.Tests.ps1` — unit tests with inline JSON fixture files

**Integration Tests:**
- `VeriHash.Tests.ps1` — tests real hash computation and sidecar file creation against a real binary fixture (`VeriHash_1024.ico`)
- `QuickHash.Tests.ps1` — tests with real files and known hash values

**Performance / Profiling Tests:**
- `VeriHash.Timing.Tests.ps1` — validates timing profiler behavior and measurement accuracy; uses large generated or user-provided files

**E2E Tests:** Not applicable — no browser or network testing. The closest equivalent is `VeriHash.Tests.ps1` which calls functions end-to-end through file creation and verification.

## Common Patterns

**Error / throw testing:**
```powershell
# Expect no throw
{ Test-InputHash -ComputedHash $computedHash -InputHash $inputHash } | Should -Not -Throw

# Expect throw with message
{ Get-Hash -InputValue "" -Algorithm "SHA256" } | Should -Throw -ExpectedMessage "*empty string*"

# Expect throw on invalid input
{
    & $script:ProfilerScript -FilePath "C:\NonExistent\File.txt" -Algorithm SHA256 -Quiet -ErrorAction Stop
} | Should -Throw
```

**Regex assertions on hash values:**
```powershell
$result.Hash | Should -Match '^[A-F0-9]{64}$'
$result.Hash.Length | Should -Be 64
```

**Property existence checks:**
```powershell
$result.PSObject.Properties.Name | Should -Contain "HashOperations"
$result.PSObject.Properties.Name | Should -Contain "VerifyOperations"
```

**Null/empty guards:**
```powershell
$result | Should -Not -BeNullOrEmpty
$result | Should -BeNullOrEmpty
$result | Should -BeOfType [hashtable]
$result | Should -BeOfType [string]
```

---

*Testing analysis: 2026-04-17*
