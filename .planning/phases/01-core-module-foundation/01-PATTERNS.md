# Phase 1: Core Module Foundation — Pattern Map

**Mapped:** 2026-04-18
**Files analyzed:** 14 new + 3 modified (existing duplicates pruned)
**Analogs found:** 13 / 14 in-repo; 1 new-shape (`.psm1` loader) has no analog yet

## File Classification

All "new" files live under `./VeriHash.Core/` per CONTEXT.md decision #7 (repo-root sibling of `VeriHash.ps1`). All test files live flat under `Tests/` per existing convention.

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `VeriHash.Core/VeriHash.Core.psd1` | config (manifest) | static metadata | *(none — no manifest exists yet)* | none — use `New-ModuleManifest` scaffold from RESEARCH §Pattern 2 |
| `VeriHash.Core/VeriHash.Core.psm1` | module loader | dot-source / fan-out | *(none)* | none — copy verbatim from RESEARCH §Pattern 1 |
| `VeriHash.Core/Public/Get-VeriHashPlatform.ps1` | utility (public function) | pure (no I/O) | `VeriHash.ps1:96-97`, `VeriHash.Config.ps1:22-26`, `VeriHash.LogUtils.ps1:35` | exact (3 duplicate definitions to consolidate) |
| `VeriHash.Core/Public/Get-VeriHashResult.ps1` | service (public function) | file-I/O → pure object | `VeriHash.ps1:780-820` (`Get-And-SaveHash`) | role-match (analog mixes hashing + sidecar I/O; new fn is pure-hash) |
| `VeriHash.Core/Public/Read-ClipboardHash.ps1` | service (public function) | OS-clipboard → pure object | `VeriHash.ps1:665-774` (`Get-ClipboardHash`) | exact role + data flow (length inference); needs new `algo:hex` prefix branch (CORE-04) |
| `VeriHash.Core/Public/Test-VeriHashSidecar.ps1` | service (public function) | file-I/O (sidecar + target) → pure object | `VeriHash.ps1:1444-1490` (sidecar parse loop in `Test-HashSidecar`) | exact (extract single-file path, drop multi-line loop) |
| `VeriHash.Core/Public/Format-VeriHashReport.ps1` | view / formatter | object → console (Write-Host) | `VeriHash.ps1:1085-1161` (Write-Host blocks inside `Invoke-HashFile`) | exact format; role-shift (extract from orchestrator into pure formatter) |
| `VeriHash.Core/Public/Write-VeriHashLog.ps1` | utility (public function) | object → file-append | `VeriHash.ps1:108-187` + `VeriHash.LogUtils.ps1:18-42` | role-match only — the analog uses PSFramework JSONL; the new fn is plain-text `Add-Content` (PSFramework deliberately retired) |
| `VeriHash.Core/Private/ConvertTo-VeriHashAlgorithm.ps1` | utility (private helper) | string-length → enum | `VeriHash.ps1:1177-1181` and `VeriHash.ps1:1452-1460` (length switch) | exact (used in 2 places in v1, deduplicated here) |
| `VeriHash.Core/Private/Read-SidecarLine.ps1` | utility (private helper) | line → parsed record | `VeriHash.ps1:1447-1449` (regex parse) | exact (port verbatim) |
| `VeriHash.Core/Private/Get-PreferredSidecar.ps1` | utility (private helper) | target path → sidecar path | *(none — new behavior per CORE-05 / decision #6)* | none — implement fresh: try `.sha512` → `.sha256` → `.md5` |
| `VeriHash.Core/Private/Format-VeriHashLogLine.ps1` | utility (private helper) | object → string | *(none)* | none — implement per RESEARCH §Pattern 4 (`yyyy-MM-ddTHH:mm:ssZ`) |
| `VeriHash.Core/Private/Resolve-VeriHashLogPath.ps1` | utility (private helper) | env-var → path | `VeriHash.LogUtils.ps1:18-42` (`Get-VeriHashLogPath`) | role-match (different default location; new fn honors `$env:VERIHASH_LOG_PATH`) |
| `Tests/VeriHash.Core.Module.Tests.ps1` | test (manifest sanity) | Pester | `Tests/VeriHash.LogUtils.Tests.ps1:1-13` | role-match (BeforeAll shape); needs `Import-Module -Force` not dot-source |
| `Tests/VeriHash.Core.<Function>.Tests.ps1` (×6) | test (per-public-fn) | Pester | `Tests/VeriHash.Tests.ps1:1-23` (BeforeAll/AfterAll), `Tests/VeriHash.LogUtils.Tests.ps1:14-54` (Describe shape) | role-match (split per-function rather than monolithic) |
| `Tests/Fixtures/format-report-golden-*.txt` | fixture | static text | *(none — fixture files don't exist)* | none — capture per RESEARCH §Pattern 7 procedure |
| `Tests/Fixtures/sidecar-{twospace,asterisk}.sha256` | fixture | static text | *(none)* | none — synthesize from regex spec |
| **MODIFIED** `VeriHash.Config.ps1` | config (existing) | — | self | **delete lines 22-26 + line 52 substitution** — replace `$script:RunningOnWindows` with `(Get-VeriHashPlatform) -eq 'Windows'` once Core is loaded |
| **MODIFIED** `VeriHash.LogUtils.ps1` | utility (existing) | — | self | **delete lines 35, 74, 116** (3 inline `$RunningOnWindows = ...`) and use `Get-VeriHashPlatform` from Core |
| **MODIFIED** `VeriHash.ps1` | CLI (existing) | — | self | **delete lines 96-97** — Phase 5 will fully thin this; Phase 1 only kills the duplicate platform block (CORE-08) |

## Pattern Assignments

### `VeriHash.Core/VeriHash.Core.psm1` (module loader, dot-source)

**Analog:** none in repo. Copy verbatim from RESEARCH §Pattern 1 (`01-RESEARCH.md:243-257`).

**Critical contract** (RESEARCH Pitfall 6):
- Private `.ps1` files MUST be dot-sourced **before** Public so Public functions can call Private helpers at runtime.
- `Export-ModuleMember -Function $publicFiles.BaseName` is belt-and-suspenders alongside the manifest's `FunctionsToExport`.

---

### `VeriHash.Core/VeriHash.Core.psd1` (manifest)

**Analog:** none. Use `New-ModuleManifest` from RESEARCH §Pattern 2 (`01-RESEARCH.md:267-287`) **once**, commit, then hand-edit. Never re-run.

**Critical contract** (RESEARCH Pitfall 1):
- `FunctionsToExport` MUST be a literal array of the 6 public function names — never `'*'`.
- `CmdletsToExport`, `VariablesToExport`, `AliasesToExport` MUST all be `@()`.
- `PowerShellVersion = '7.0'` + `CompatiblePSEditions = @('Core')`.

---

### `VeriHash.Core/Public/Get-VeriHashPlatform.ps1` (utility, pure)

**Analog A — duplicate to eliminate** (`VeriHash.ps1:96-97`):
```powershell
$RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT'
$RunningOnLinux = $PSVersionTable.Platform -eq 'Unix' -and $PSVersionTable.OS -match 'Linux'
```

**Analog B — duplicate to eliminate** (`VeriHash.Config.ps1:22-26`):
```powershell
#region Platform Detection
$script:RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform
$script:RunningOnLinux = $PSVersionTable.Platform -eq 'Unix' -and $PSVersionTable.OS -match 'Linux'
$script:RunningOnMacOS = $PSVersionTable.Platform -eq 'Unix' -and $PSVersionTable.OS -match 'Darwin'
#endregion Platform Detection
```

**Analog C — duplicate to eliminate** (`VeriHash.LogUtils.ps1:35`, `74`, `116`):
```powershell
$RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT'
```

**New canonical implementation** — copy from RESEARCH §Pattern 8 (`01-RESEARCH.md:511-521`). Returns string `'Windows' | 'Linux' | 'macOS'`.

**Consumer-call replacement pattern:**
```powershell
# Before:
if ($script:RunningOnWindows) { Join-Path $env:APPDATA "VeriHash" }
# After:
if ((Get-VeriHashPlatform) -eq 'Windows') { Join-Path $env:APPDATA "VeriHash" }
```

---

### `VeriHash.Core/Public/Get-VeriHashResult.ps1` (service, file-I/O → object)

**Analog:** `VeriHash.ps1:780-820` (`Get-And-SaveHash`).

**Hash-computation excerpt** (`VeriHash.ps1:801-809`):
```powershell
$hashStartTime = Get-Date
$fileHash = Get-FileHash -Path $PathToFile -Algorithm $Algorithm
$hashValue = $fileHash.Hash.ToUpper()
$hashEndTime = Get-Date
$hashDuration = $hashEndTime - $hashStartTime
```

**Patterns to change vs analog:**
1. **Replace `Get-Date` subtraction with `[System.Diagnostics.Stopwatch]`** — see RESEARCH "Don't Hand-Roll" + Pattern §3 (`01-RESEARCH.md:298-322`). Stopwatch is monotonic; subtraction can return negatives if the system clock is adjusted.
2. **Replace `.ToUpper()` with `.ToLowerInvariant()`** — CONTEXT.md decision #2 + RESEARCH Pitfall 2. v2 contract is lowercase hex.
3. **Use `-LiteralPath` everywhere a user filename touches `Resolve-Path`/`Get-Item`/`Get-FileHash`** — RESEARCH §Pattern 3 rationale.
4. **Strip ALL `Write-PSFMessage` calls** — Phase 1 carries forward "no PSFramework in Core."
5. **Return shape:** `[pscustomobject]` with `PSTypeName='VeriHash.Result'` and exactly 5 fields: `FilePath, Size, Algorithm, Hash, ElapsedMs` (CONTEXT.md decision #2). The analog returns 12+ fields including `Sidecar*`/`InputHash*` — those concerns split into `Test-VeriHashSidecar` and the formatter.

**Final shape** — copy from RESEARCH §Pattern 3 (`01-RESEARCH.md:298-322`).

---

### `VeriHash.Core/Public/Read-ClipboardHash.ps1` (service, OS → object)

**Analog:** `VeriHash.ps1:665-774` (`Get-ClipboardHash`).

**Length-inference excerpt to port** (`VeriHash.ps1:739-767`):
```powershell
$md5Pattern    = '^[A-Fa-f0-9]{32}$'
$sha256Pattern = '^[A-Fa-f0-9]{64}$'
$sha512Pattern = '^[A-Fa-f0-9]{128}$'

if ($clipboard -match $md5Pattern) {
    return [pscustomobject]@{ Algorithm = 'MD5';    Hash = $clipboard.ToUpper() }
} elseif ($clipboard -match $sha256Pattern) {
    return [pscustomobject]@{ Algorithm = 'SHA256'; Hash = $clipboard.ToUpper() }
} elseif ($clipboard -match $sha512Pattern) {
    return [pscustomobject]@{ Algorithm = 'SHA512'; Hash = $clipboard.ToUpper() }
}
```

**Windows-branch excerpt to port** (`VeriHash.ps1:676-684`):
```powershell
if ($RunningOnWindows) {
    try { $clipboard = Get-Clipboard -ErrorAction Stop }
    catch { return $null }
}
```

**Patterns to change vs analog:**
1. **Drop the Linux `wl-paste`/`xclip`/`xsel` branch** (`VeriHash.ps1:686-723`) — CONTEXT.md decision #5 explicitly defers cross-platform clipboard. Replace the entire non-Windows block with:
   ```powershell
   if ((Get-VeriHashPlatform) -ne 'Windows') {
       Write-Verbose 'Clipboard reading not supported on this platform yet.'
       return $null
   }
   ```
2. **Add the `<algo>:<hex>` prefix branch FIRST** (CORE-04, RESEARCH Pitfall 3) before length inference — see RESEARCH §Pattern 6 lines 446-454 for the regex `^(?<algo>md5|sha256|sha512):(?<hash>[A-Fa-f0-9]+)$`.
3. **`.ToLowerInvariant()` not `.ToUpper()`** — same v2 contract change as `Get-VeriHashResult`.
4. **Strip ALL `Write-PSFMessage` calls** at lines 669-672, 745-746, 753-754, 761-762, 769-770.

**Final shape** — copy from RESEARCH §Pattern 6 (`01-RESEARCH.md:432-467`).

---

### `VeriHash.Core/Public/Test-VeriHashSidecar.ps1` (service, file-I/O → object)

**Analog:** `VeriHash.ps1:1444-1490` (sidecar-line loop inside `Test-HashSidecar`).

**Sidecar regex + length-switch excerpt to port verbatim** (`VeriHash.ps1:1447-1460`):
```powershell
if ($line -match '^([A-Fa-f0-9]+)\s+\*?(.+)$') {
    $inputHash = $matches[1].ToUpper()
    $referencedFilename = $matches[2].Trim()
    switch ($inputHash.Length) {
        32  { $algorithm = 'MD5'    }
        64  { $algorithm = 'SHA256' }
        128 { $algorithm = 'SHA512' }
        default {
            Write-Warning "Unrecognized hash length '$($inputHash.Length)' for '$referencedFilename'. Skipping."
            continue
        }
    }
    ...
}
```

**Hash-compare excerpt** (`VeriHash.ps1:1473-1485`):
```powershell
$computedHash = (Get-FileHash -Algorithm $algorithm -Path $fileToCheck).Hash.ToUpper()
if ($computedHash -eq $inputHash) { ... } else { ... }
```

**Patterns to change vs analog:**
1. **Single sidecar, not multi-line loop.** v1 iterates every line in a `*.sha256` file (GNU `sha256sum`-style multi-target manifests). Phase 1 v2 reads one sidecar = one target, single line — see CONTEXT.md decision #6 ("only the chosen sidecar is verified, single hash computation"). Use `Get-Content -LiteralPath $sidecar -TotalCount 1`.
2. **Compute target path differently.** Analog parameter is the *sidecar* path; Phase 1 parameter is the *target* path. Sidecar is discovered via `Get-PreferredSidecar` (sha512 > sha256 > md5).
3. **Move regex to `Private/Read-SidecarLine.ps1`.**
4. **Move length switch to `Private/ConvertTo-VeriHashAlgorithm.ps1`** (DRY — also used by `Read-ClipboardHash` length fallback if extracted).
5. **`.ToLowerInvariant()` on both sides** of the comparison; case-insensitive equality.
6. **Delegate hash compute to `Get-VeriHashResult`** — don't call `Get-FileHash` directly.
7. **Return a `VeriHash.Result`-shaped object** plus an attached `Sidecar` field naming which sidecar was chosen, e.g. `"matched (foo.iso.sha512)"`.

**Final shape** — RESEARCH §Pattern 5 (`01-RESEARCH.md:388-415`).

---

### `VeriHash.Core/Public/Format-VeriHashReport.ps1` (formatter, object → console)

**Analog:** `VeriHash.ps1:1085-1161` (Write-Host blocks inside `Invoke-HashFile`'s try block).

**Format excerpt to preserve byte-exact** (`VeriHash.ps1:1105-1122`):
```powershell
Write-Host ("File selected:    " + $fileInfo.Name) -ForegroundColor Green
Write-Host "---" -ForegroundColor Cyan
Write-Host "[Metadata]" -ForegroundColor White
Write-Host ("File Path:    " + $fileInfo.FullName) -ForegroundColor Cyan

$formattedBytes = $fileInfo.Length.ToString("N0").Replace(",", " ")
Write-Host ("File Size:    " + "{0:N2}" -f ($fileInfo.Length / 1MB) + " MB  (" + "$formattedBytes bytes" + ")") -ForegroundColor Yellow

$createdTime  = $fileInfo.CreationTimeUtc
$modifiedTime = $fileInfo.LastWriteTimeUtc
Write-Host "Created:      " -NoNewline -ForegroundColor Yellow
Write-Host ($createdTime.ToLocalTime().ToString("MMMM dd, yyyy") + " | " + $createdTime.ToLocalTime().ToString("HH:mm:ss")) -ForegroundColor Cyan
Write-Host "Modified:     " -NoNewline -ForegroundColor Yellow
Write-Host ($modifiedTime.ToLocalTime().ToString("MMMM dd, yyyy") + " | " + $modifiedTime.ToLocalTime().ToString("HH:mm:ss")) -ForegroundColor Cyan
Write-Host "---" -ForegroundColor Cyan
```

**Timestamp banner excerpt** (`VeriHash.ps1:1083-1086`):
```powershell
$currentUTC = Get-Date -AsUTC
Write-Host "Start UTC:    $($currentUTC.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))" -ForegroundColor Cyan
Write-Host "---" -ForegroundColor Cyan
```

**Patterns to change vs analog:**
1. **Pure formatter** — input is a `VeriHash.Result` object, NOT a `FileInfo` + side-channel state. The formatter must NOT call `Get-Item`, `Get-AuthenticodeSignature`, `Get-FileHash`, or anything I/O-bound. All data must already be on the result object.
2. **Lowercase hash rendering** — the result already carries lowercase; render it as-is. RESEARCH Pitfall 2 + Assumption A3: capture golden-text fixture against lowercase v2 contract, NOT v1's mixed casing.
3. **Strip non-deterministic lines from the golden-text fixture** — timestamps, "Start UTC", elapsed time become `<TIMESTAMP>`/`<ELAPSED>` placeholders that the test substitutes before comparison (RESEARCH §Pattern 7 capture procedure step 3).
4. **Strip Authenticode block** (`VeriHash.ps1:1124-1161`) — Authenticode is Phase 2 territory per RESEARCH "Architectural Responsibility Map." Format only the fields present on `VeriHash.Result`.

**Test wrapper** — copy from RESEARCH §Pattern 7 (`01-RESEARCH.md:475-496`).

---

### `VeriHash.Core/Public/Write-VeriHashLog.ps1` (utility, object → file-append)

**Analog A (existing logger — being retired):** `VeriHash.ps1:108-187` (PSFramework JSONL bootstrap) and `VeriHash.LogUtils.ps1:18-42` (`Get-VeriHashLogPath`).

**Path-resolution excerpt to learn from** (`VeriHash.LogUtils.ps1:35-42`):
```powershell
$RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT'
if ($RunningOnWindows) {
    Join-Path $env:APPDATA "VeriHash\logs"
} else {
    Join-Path $HOME ".verihash/logs"
}
```

**Patterns to change vs analog (this is essentially a rewrite, not a port):**
1. **No PSFramework, no JSONL, no rotation, no Headers config, no Set-PSFLoggingProvider.** Plain text only.
2. **No platform-specific log path** — use `~/.verihash/verihash.log` on every OS (CONTEXT.md decision #4). The Windows `$env:APPDATA\VeriHash\logs` path from the analog is replaced by the universal `$HOME/.verihash/verihash.log`.
3. **Honor `$env:VERIHASH_LOG_PATH` override** for test isolation — same precedent as the existing `$env:VERIHASH_TEST_MODE = '1'` pattern at `Tests/VeriHash.Tests.ps1:3` and `VeriHash.ps1:136`.
4. **Gate on `-Log` switch OR `$env:VERIHASH_LOG=1`.** Early-return if neither is set.
5. **Use `Add-Content -LiteralPath $logPath -Value $line -Encoding utf8`** — RESEARCH "Don't Hand-Roll" table + Pitfall 5 (no BOM in pwsh 7).
6. **Single line per invocation** in the locked format `<ISO8601-UTC> <op> <algo> <hash> <bytes> <elapsed_ms> <result> <path>` — path always last.

**Final shape** — copy from RESEARCH §Pattern 4 (`01-RESEARCH.md:333-371`).

---

### `VeriHash.Core/Private/ConvertTo-VeriHashAlgorithm.ps1` (private helper)

**Analog A — duplicate length-switch in v1** (`VeriHash.ps1:1177-1181`):
```powershell
switch ($InputHash.Length) {
    32  { $detectedAlgorithm = 'MD5'    }
    64  { $detectedAlgorithm = 'SHA256' }
    128 { $detectedAlgorithm = 'SHA512' }
}
```

**Analog B — same switch repeated** (`VeriHash.ps1:1452-1460`): identical body inside `Test-HashSidecar`.

**Pattern:** consolidate both into one helper. Should also accept the `algo:hex` prefix form so `Read-ClipboardHash` can delegate (RESEARCH Pitfall 3 — prefix wins, length is fallback).

---

### `VeriHash.Private/Read-SidecarLine.ps1` (private helper)

**Analog:** `VeriHash.ps1:1447-1449` — port the regex verbatim, no changes:
```powershell
'^([A-Fa-f0-9]+)\s+\*?(.+)$'
# group 1 = hash hex; optional '*' = binary marker; group 2 = filename (may contain spaces)
```

Return `@{ Hash = $matches[1].ToLowerInvariant(); Filename = $matches[2].Trim() }` or `$null` on no match. Note: lowercase here, NOT `.ToUpper()` like v1 line 1448.

---

### `VeriHash.Core/Private/Get-PreferredSidecar.ps1` (private helper)

**Analog:** none — this is new behavior introduced by CONTEXT.md decision #6.

**Implementation:**
```powershell
$candidates = '.sha512', '.sha256', '.md5'
$algoMap = @{ '.sha512' = 'SHA512'; '.sha256' = 'SHA256'; '.md5' = 'MD5' }
foreach ($ext in $candidates) {
    $sidecarPath = "$TargetPath$ext"
    if (Test-Path -LiteralPath $sidecarPath) {
        return [pscustomobject]@{ Path = $sidecarPath; Algorithm = $algoMap[$ext] }
    }
}
return $null
```

---

### `VeriHash.Core/Private/Format-VeriHashLogLine.ps1` (private helper)

**Analog:** none in repo. Copy timestamp + concatenation from RESEARCH §Pattern 4 (`01-RESEARCH.md:365-368`):
```powershell
$ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$line = "$ts $Op $Algorithm $Hash $Bytes $ElapsedMs $Result $Path"
```

**Critical** (RESEARCH Pitfall 7): use the explicit format string, NOT `Get-Date -Format 'o' -AsUTC` — `'o'` produces sub-second precision and `+00:00` offset, neither of which match the locked `Z` format.

---

### `VeriHash.Core/Private/Resolve-VeriHashLogPath.ps1` (private helper)

**Analog:** `VeriHash.LogUtils.ps1:18-42` (`Get-VeriHashLogPath`) — but the new function differs significantly:

| | Analog | New |
|---|---|---|
| Default path | `$env:APPDATA\VeriHash\logs` (Win) / `~/.verihash/logs` (Unix) — directory | `~/.verihash/verihash.log` everywhere — file |
| Env override | none | `$env:VERIHASH_LOG_PATH` wins |
| Platform-conditional | yes | no |

**Implementation:**
```powershell
if ($env:VERIHASH_LOG_PATH) { return $env:VERIHASH_LOG_PATH }
return (Join-Path $HOME '.verihash/verihash.log')
```

---

### `Tests/VeriHash.Core.Module.Tests.ps1` (test, manifest sanity — CORE-01)

**Analog:** `Tests/VeriHash.LogUtils.Tests.ps1:1-13` (BeforeAll shape).

**Existing BeforeAll pattern to LEARN-FROM-AND-CHANGE:**
```powershell
BeforeAll {
    $script:LogUtilsPath = "$PSScriptRoot\..\VeriHash.LogUtils.ps1"
    . $script:LogUtilsPath        # ← v1: dot-source
}
```

**New BeforeAll pattern (RESEARCH Pitfall 8):**
```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
}
AfterAll {
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}
```

**Body** — copy from RESEARCH "Module-Level Sanity Test (CORE-01)" (`01-RESEARCH.md:662-684`).

---

### `Tests/VeriHash.Core.<Function>.Tests.ps1` (×6 — one per public function)

**Analog A — BeforeAll/AfterAll env-var isolation** (`Tests/VeriHash.Tests.ps1:1-23`):
```powershell
BeforeAll {
    $env:VERIHASH_TEST_MODE = '1'
    . "$PSScriptRoot\..\VeriHash.ps1" -FilePath "dummy" -ErrorAction SilentlyContinue 2>$null
    $script:TestIconFile = Join-Path $PSScriptRoot "VeriHash_1024.ico"
    $script:TestOutputDir = Join-Path $TestDrive "VeriHashTests"
    New-Item -ItemType Directory -Path $script:TestOutputDir -Force | Out-Null
}
AfterAll {
    Remove-Item Env:\VERIHASH_TEST_MODE -ErrorAction SilentlyContinue
}
```

**Patterns to change vs analog:**
1. **Replace dot-source-with-dummy-path** with `Import-Module ... -Force` (CORE-01).
2. **Replace `$env:VERIHASH_TEST_MODE`** with `$env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')` for `Write-VeriHashLog` tests — same precedent (env-var isolation), new contract (logger-specific path override).
3. **Move fixture file** from `Tests/VeriHash_1024.ico` → `Tests/Fixtures/VeriHash_1024.ico` (RESEARCH "Recommended Project Structure") and update `$script:TestIconFile` accordingly.

**Per-function test body** — copy from RESEARCH "Module Test Skeleton" (`01-RESEARCH.md:632-657`).

**CORE-08 enforcement test** — include in `Get-VeriHashPlatform.Tests.ps1` per RESEARCH §Pattern 8 (`01-RESEARCH.md:528-535`):
```powershell
It 'Has zero duplicate platform-detection definitions outside Core' {
    $matches = Select-String -Path "$PSScriptRoot/../**/*.ps1" `
        -Pattern '\$script:RunningOn(Windows|Linux|MacOS)' `
        -Exclude '*Get-VeriHashPlatform.ps1','*Tests.ps1' -ErrorAction SilentlyContinue
    $matches | Should -BeNullOrEmpty
}
```

---

## Shared Patterns

### Path-handling: always `-LiteralPath`
**Source:** RESEARCH §Pattern 3 rationale + Pitfall (filenames containing `[`, `]`, `*`, `?`).
**Apply to:** `Get-VeriHashResult`, `Test-VeriHashSidecar`, `Get-PreferredSidecar`, `Read-SidecarLine`, `Write-VeriHashLog`, `Resolve-VeriHashLogPath`.
**Rule:** Every PowerShell cmdlet that takes a user-supplied filesystem path uses `-LiteralPath`, never `-Path`. The v1 monolith uses `-Path` in many places (e.g., `VeriHash.ps1:804`, `1473`); do NOT carry that habit forward.

### Hash casing: always `.ToLowerInvariant()` at the boundary
**Source:** CONTEXT.md decision #2 + RESEARCH Pitfall 2 + Assumption A3.
**Apply to:** `Get-VeriHashResult` (line where `Get-FileHash`'s uppercase output is captured), `Read-ClipboardHash` (both prefix and length branches), `Read-SidecarLine` (parsed hash), `Test-VeriHashSidecar` (both sides of compare), `Format-VeriHashReport` (renders as-is, lowercase).
**Rule:** The v2 contract is lowercase hex everywhere; v1's `.ToUpper()` calls (`VeriHash.ps1:750, 758, 766, 805, 1448, 1473`) are NOT carried forward.

### No PSFramework anywhere in Core
**Source:** PROJECT.md non-negotiable + CONTEXT.md "Carried Forward" + RESEARCH "Deprecated/outdated for THIS phase."
**Apply to:** every `VeriHash.Core/**/*.ps1` file.
**Rule:** Zero `Write-PSFMessage`, zero `Set-PSFLoggingProvider`, zero `$script:PSFrameworkAvailable` guards, zero `Import-Module PSFramework`. v1 sprinkles these at lines 100, 126, 132-187, 669, 745, 753, 761, 769, 789, 812, 1433. None survive into Core. Use `Write-Verbose` for diagnostics instead.

### Platform branching: `(Get-VeriHashPlatform) -eq 'Windows'`
**Source:** CORE-08 + CONTEXT.md decision #3.
**Apply to:** every consumer that previously used `$RunningOnWindows`/`$IsWindows`/`$script:RunningOnWindows`.
**Rule:** No new `$IsWindows` references outside `Get-VeriHashPlatform.ps1`. The CORE-08 enforcement test (above) makes this observable.

### Test isolation: env-var override pattern
**Source:** existing precedent at `Tests/VeriHash.Tests.ps1:3` (`$env:VERIHASH_TEST_MODE = '1'`) + RESEARCH user-constraints §4.
**Apply to:** `Tests/VeriHash.Core.Write-VeriHashLog.Tests.ps1` (set `$env:VERIHASH_LOG_PATH` to `$TestDrive`-relative path in `BeforeAll`, clear in `AfterAll`).
**Rule:** Tests never write to a real user log file. Path is always redirected via env var.

### Test module-import: `Import-Module ... -Force`
**Source:** RESEARCH Pitfall 8 + CORE-01.
**Apply to:** every `Tests/VeriHash.Core.*.Tests.ps1`.
**Rule:** `BeforeAll` always uses `Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force`. Never dot-source. The `-Force` flag is required (picks up source changes mid-session).

---

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md patterns instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `VeriHash.Core/VeriHash.Core.psd1` | manifest | static | Repo has never had a `.psd1` — use `New-ModuleManifest` per RESEARCH §Pattern 2 |
| `VeriHash.Core/VeriHash.Core.psm1` | module loader | dot-source | No script module in repo — copy verbatim from RESEARCH §Pattern 1 |
| `VeriHash.Core/Private/Get-PreferredSidecar.ps1` | helper | path → path | Sidecar precedence (`.sha512` > `.sha256` > `.md5`) is new behavior per CONTEXT.md decision #6 |
| `VeriHash.Core/Private/Format-VeriHashLogLine.ps1` | formatter | object → string | New plain-text logger format — RESEARCH §Pattern 4 |
| `Tests/Fixtures/format-report-golden-*.txt` | fixture | static | Capture procedure in RESEARCH §Pattern 7 (steps 1-4) |
| `Tests/Fixtures/sidecar-*.sha256` | fixture | static | Synthesize from `^([A-Fa-f0-9]+)\s+\*?(.+)$` regex spec |

---

## Metadata

**Analog search scope:**
- `./VeriHash.ps1` (1527-line monolith — primary source for all behavioral patterns)
- `./VeriHash.Config.ps1`, `./VeriHash.LogUtils.ps1` (existing dot-sourced helpers — primary source for platform-detection duplicates to eliminate)
- `./Tests/*.Tests.ps1` (existing Pester 5 tests — source for BeforeAll/AfterAll/env-var-isolation shape)

**Files scanned:** 14 (`.ps1`, `.psm1`, `.psd1` under repo root + Tests, excluding `.planning/` and `tmp/`).

**Pattern extraction date:** 2026-04-18.

---

## PATTERN MAPPING COMPLETE

**Phase:** 01 — core-module-foundation
**Files classified:** 17 net (14 new under `VeriHash.Core/` + Tests; 3 modified to remove platform-detection duplicates)
**Analogs found:** 13 / 14 in-repo; 1 shape (`.psm1` loader / `.psd1` manifest) drawn from RESEARCH templates

### Coverage
- Files with exact analog: 9 (platform fn, hash fn, clipboard fn, sidecar parse, format block, length switch, sidecar regex, log path resolver, test BeforeAll skeleton)
- Files with role-match analog: 4 (logger — PSFramework→plain; result fn — strip multi-concern; module/per-fn tests — dot-source→Import-Module; consumer modifications)
- Files with no analog: 6 (`.psd1`, `.psm1`, sidecar precedence helper, log-line formatter, golden-text fixtures, sidecar fixtures)

### Key Patterns Identified
- **Platform detection consolidates 3 duplicates → 1 exported function** (`VeriHash.ps1:96-97`, `VeriHash.Config.ps1:22-26`, `VeriHash.LogUtils.ps1:35,74,116` — all replaced by `Get-VeriHashPlatform`).
- **Hash casing flips: v1 `.ToUpper()` everywhere → v2 `.ToLowerInvariant()` at the I/O boundary** — affects 6 call sites in v1; the contract change must be reflected in golden-text fixtures (capture from v2 prototype, NOT from v1 run).
- **Tests transition: dot-source-with-dummy-path → `Import-Module ... -Force`** — kills the v1 hack at `Tests/VeriHash.Tests.ps1:7` and makes CORE-01 ("`Get-Command -Module VeriHash.Core` lists the 6 functions") observable.
- **PSFramework excised from Core** — every `Write-PSFMessage`/`$script:PSFrameworkAvailable` reference in v1 (≥10 sites) is dropped, not ported. Plain-text `Add-Content` logger is the only logging in Core.
- **Sidecar verify reshape: multi-line GNU-style loop → single sidecar / single target** — v1's `Test-HashSidecar` iterates every line in the sidecar; v2's `Test-VeriHashSidecar` accepts the *target* path, picks the strongest sidecar via `Get-PreferredSidecar`, reads exactly one line, computes one hash. This keeps Phase 2's hot path fast.

### File Created
`.planning/phases/01-core-module-foundation/01-PATTERNS.md`

### Ready for Planning
Pattern mapping complete. Planner can now reference analog file paths + line numbers + concrete excerpts in PLAN.md action sections.
