# Phase 1: Core Module Foundation — Research

**Researched:** 2026-04-18
**Domain:** PowerShell 7+ module authoring (script module, manifest, dot-sourced public/private layout) + Pester 5 module-import test patterns + plain-text append-only logging
**Confidence:** HIGH (the domain is well-known, the local stack is already pinned, and CONTEXT.md has locked all major design choices)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

1. **Module internal layout — `Public/` + `Private/` folders dot-sourced from `.psm1`.** `VeriHash.Core.psm1` is a thin (~20-line) loader that dot-sources every `.ps1` under `Public/` and `Private/`, then runs `Export-ModuleMember -Function (Get-ChildItem $PSScriptRoot/Public/*.ps1).BaseName`. One function per file. Folder layout:
   ```
   VeriHash.Core/
   ├── VeriHash.Core.psd1
   ├── VeriHash.Core.psm1
   ├── Public/
   │   ├── Get-VeriHashResult.ps1
   │   ├── Read-ClipboardHash.ps1
   │   ├── Test-VeriHashSidecar.ps1
   │   ├── Format-VeriHashReport.ps1
   │   ├── Write-VeriHashLog.ps1
   │   └── Get-VeriHashPlatform.ps1
   └── Private/
       └── (internal helpers — to be identified during planning/research)
   ```

2. **Result object type — `[pscustomobject]` with `PSTypeName = 'VeriHash.Result'`.** Shape:
   ```powershell
   [pscustomobject]@{
       PSTypeName = 'VeriHash.Result'
       FilePath   = $path
       Size       = $size      # bytes (long)
       Algorithm  = $algo      # 'MD5' | 'SHA256' | 'SHA512'
       Hash       = $hash      # lowercase hex string
       ElapsedMs  = $ms        # int
   }
   ```
   No PowerShell `class` (cold-start cost). `PSTypeName` keeps `Format.ps1xml` open as a future option.

3. **Platform helper — `Get-VeriHashPlatform` returns a string.** Single exported function returning `'Windows' | 'Linux' | 'macOS'`. No predicates, no exported variable. CORE-08 requires this to be defined exactly once across the v2 codebase.

4. **Plain-text log line format (locked for v2 lifetime — no parser, no rotation):**
   ```
   <ISO8601-UTC> <op> <algo> <hash> <bytes> <elapsed_ms> <result> <path>
   ```
   - `<op>` ∈ `hash | verify`
   - `<result>` ∈ `ok | mismatch | missing | error | n/a`
   - `<path>` is **always last** so spaces in paths cannot break splitting on the first 7 columns
   - Single space separator; UTC ISO 8601 timestamp (e.g., `2026-04-18T13:05:42Z`)
   - **Trigger (CORE-07):** `-Log` flag OR `$env:VERIHASH_LOG=1`. One line per invocation. Append-only.
   - **Log file path:** Default `~/.verihash/verihash.log`. Overridable via `$env:VERIHASH_LOG_PATH` (env > default) for test isolation.

5. **Clipboard on Linux/macOS — graceful no-op.** `Read-ClipboardHash` returns `$null` on non-Windows with `Write-Verbose`. v1 was Windows-only here too. Cross-platform clipboard (xclip/wl-paste/pbpaste) is **deferred**.

6. **Sidecar precedence — strongest wins.** When multiple sidecars exist for one target, `Test-VeriHashSidecar` picks: `.sha512` → `.sha256` → `.md5`. Only the chosen sidecar is verified (one hash computation). Output line names the chosen sidecar, e.g. `Sidecar: matched (foo.iso.sha512)`.

7. **Module folder location — repo root.** `./VeriHash.Core/` lives at the repository root, not under `src/` or `modules/`. Phase 3's `./VeriHash.Manifest/` will mirror this. Tests load via `Import-Module "$PSScriptRoot\..\VeriHash.Core\VeriHash.Core.psd1"`.

### the agent's Discretion

From CONTEXT.md `<open_questions_for_planner>` — explicitly delegated to the planner:

- **Internal helper inventory** (Private/ contents). Likely: hash-algorithm-from-extension lookup, sidecar-line parser, ISO 8601 timestamp formatter — final list driven by research below.
- **Golden-text fixture capture mechanism** (test fixture file vs inline here-string). Either is fine; pick what's easiest to regenerate when format intentionally changes.
- **Pester test file split** — one `*.Tests.ps1` per public function, or grouped by concern. Match existing `Tests/` discoverability.
- **Module manifest (`.psd1`) metadata** — version, `RequiredModules`, `CompatiblePSEditions`, `FunctionsToExport`. "Do it correctly" — no extra decisions needed.

### Deferred Ideas (OUT OF SCOPE)

- **Cross-platform clipboard support** for `Read-ClipboardHash` (wl-paste/xclip/xsel/pbpaste) — own phase in v2.x backlog.
- **`Format.ps1xml` for `VeriHash.Result`** — PSTypeName enables it later; not Phase 1 scope.
- **`-VerifyAll` CLI flag** — verify every present sidecar; belongs in Phase 5 if there's user demand. Do not build into Core.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CORE-01 | `VeriHash.Core` module importable via `Import-Module`; tests use `Import-Module` (no dot-source hack) | Standard Stack §Module Manifest; Architecture Patterns §1 (psm1 loader), §2 (manifest authoring) |
| CORE-02 | `Get-VeriHashResult -Path <file>` returns `FilePath/Size/Algorithm/Hash/ElapsedMs` for MD5/SHA256/SHA512 | Architecture Patterns §3 (PSCustomObject result + Stopwatch); Don't-Hand-Roll (`Get-FileHash`) |
| CORE-03 | `Read-ClipboardHash` length-based inference (32→MD5, 64→SHA256, 128→SHA512) | Existing v1 logic (`VeriHash.ps1:739-773`); Pattern §6 (regex + length switch) |
| CORE-04 | `Read-ClipboardHash` `<algo>:<hex>` prefix form, prefix overrides length | Pattern §6 (parser order: prefix-first, then length); Pitfall §3 |
| CORE-05 | Sidecar verify, v1-compatible `HASH  filename` and `HASH *filename` | Existing parser regex `^([A-Fa-f0-9]+)\s+\*?(.+)$` (`VeriHash.ps1:1447`); Pattern §5 |
| CORE-06 | `Format-VeriHashReport` v1-visually-compatible | Pattern §7 (golden-text test); Existing format in `Invoke-HashFile` (`VeriHash.ps1:1085-1161`) |
| CORE-07 | `Write-VeriHashLog` plain-text, append-only, gated on `-Log`/`$env:VERIHASH_LOG=1` | Pattern §4 (atomic append + ISO 8601); Don't-Hand-Roll (use `Add-Content` not custom file writer) |
| CORE-08 | Platform detection defined once, exported by Core, zero duplicates elsewhere | Pattern §8; existing duplicates at `VeriHash.ps1:96`, `VeriHash.LogUtils.ps1`, `VeriHash.Config.ps1` (must be removed in this phase) |
</phase_requirements>

## Summary

This phase is well-bounded: extract six known-good behaviors from the 1527-line `VeriHash.ps1` monolith into a real script module (`.psd1` + `.psm1`) using the de-facto PowerShell convention of `Public/` + `Private/` folders dot-sourced from a thin loader. Every locked decision in CONTEXT.md aligns with how Microsoft, the PowerShell community, and Pester 5 documentation say to build a script module today — there are no architectural surprises.

The four implementation areas that need the most planner attention are: (a) the **module manifest** (must use a literal array for `FunctionsToExport`, never `'*'`, or it breaks autoloading and explicit-export discipline); (b) the **plain-text logger's gating + atomicity** (the tiny replacement for PSFramework — must use `Add-Content -Encoding utf8` on a single line and create the parent directory on demand); (c) the **golden-text fixture for `Format-VeriHashReport`** (capture the exact `Write-Host` byte stream from a v1 run *before* refactoring, store it under `Tests/Fixtures/`, diff against it via `*>&1 | Out-String`); and (d) **eliminating the duplicate platform-detection blocks** in `VeriHash.Config.ps1` and `VeriHash.LogUtils.ps1` (CORE-08's "zero duplicate definitions" criterion is observable by `Select-String`, not just compilation success).

**Primary recommendation:** Build the module skeleton + manifest + thin loader first (Wave 0), capture the v1 golden-text fixture before any refactor touches output formatting, then port behaviors function-by-function with one Pester file per public function. Resist the urge to "improve" output strings during the port — CORE-06 explicitly pins v1 visual layout.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| File hash computation (MD5/SHA256/SHA512) | Core module (`Get-VeriHashResult`) | — | Pure function over a path; no UI, no I/O beyond `Get-FileHash` and `Get-Item` |
| Clipboard hash parsing | Core module (`Read-ClipboardHash`) | — | Reads OS clipboard (Windows only in Phase 1), returns parsed result; no UI rendering |
| Sidecar verification | Core module (`Test-VeriHashSidecar`) | — | Pure file-in/file-out: read sidecar, compute hash, compare. No UI. |
| Output rendering (Write-Host blocks) | Core module (`Format-VeriHashReport`) | CLI (Phase 5) | Renders a `VeriHash.Result` to console. Phase 5's thin CLI calls it; Core owns the format. |
| Plain-text logging | Core module (`Write-VeriHashLog`) | — | Single-line append to `~/.verihash/verihash.log`; gated on `-Log`/env var. No external dep. |
| Platform detection | Core module (`Get-VeriHashPlatform`) | All other modules (consumers) | CORE-08: defined once in Core, every other module calls it; zero re-implementations. |
| Interactive prompts (Select-File, "Press any key", overwrite confirms) | **NOT Core** — CLI (Phase 5) only | — | Core functions must be non-interactive so they're scriptable and testable. |
| Authenticode signature checks | **NOT Core** — Phase 2 | — | PE-only, parallel via `Start-ThreadJob`; explicitly Phase 2 territory. |

**Why this matters:** v1's `Invoke-HashFile` mixes hashing, formatting, prompting, signature checking, and orchestration in one ~370-line function. Phase 1 splits the *pure* concerns (hash, parse, verify, format, log, detect) from the *interactive/orchestration* concerns (prompt, pause, dispatch). Anything interactive belongs to Phase 5's CLI; anything Authenticode/parallel belongs to Phase 2.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| PowerShell | 7.0+ (verified `pwsh --version` → 7.6.0 locally) | Cross-platform runtime | Project non-negotiable; `CompatiblePSEditions = 'Core'` in manifest |
| Pester | 5.x (5.7.1 verified locally; CI pins `<= 5.99`) | Test framework | Already in repo + CI; tests use `Import-Module` cleanly |
| PSScriptAnalyzer | 1.x (1.25.0 verified locally) | Linter | Already wired into CI on the three `.ps1` files; will lint `VeriHash.Core/**/*.ps1` after Phase 1 |

### Built-in (no install needed)

| API | Purpose | When to Use |
|-----|---------|-------------|
| `Get-FileHash` | Compute MD5/SHA256/SHA512 | Inside `Get-VeriHashResult` — never hand-roll a hash loop |
| `[System.Diagnostics.Stopwatch]` | High-resolution `ElapsedMs` | Inside `Get-VeriHashResult` — `[int]$sw.ElapsedMilliseconds` |
| `Get-Clipboard` | Windows clipboard read | Inside `Read-ClipboardHash` Windows branch |
| `Add-Content` | Append a single line to log file | Inside `Write-VeriHashLog`; `-Encoding utf8` (no BOM in pwsh 7) |
| `New-ModuleManifest` | Generate `.psd1` once, hand-edit thereafter | One-time scaffolding; commit the result |
| `Export-ModuleMember` | Explicit export list inside `.psm1` | Belt-and-suspenders alongside `FunctionsToExport` in `.psd1` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `[pscustomobject]` with `PSTypeName` | PowerShell `class VeriHashResult { ... }` | `class` adds compile cost on every `Import-Module` (matters for Phase 2 hot path); rejected by CONTEXT.md decision #2 |
| `Add-Content` for log append | `[System.IO.File]::AppendAllLines($path, @($line), [Text.UTF8Encoding]::new($false))` | Slightly faster, slightly more atomic on POSIX. **Use this** if `Add-Content` shows BOM or locking issues during testing — see Pitfall §4. Both are acceptable. |
| Folder-per-function (`Public/Get-VeriHashResult.ps1`) | Single big `.psm1` with all functions inline | Convention #1 in PowerShell community (RamblingCookieMonster's "Building a PowerShell Module" template); locked by CONTEXT.md decision #1 |
| `Write-Output` of result + caller pipes to formatter | Result function calls formatter internally | CONTEXT.md keeps them separate (`Get-VeriHashResult` returns object, `Format-VeriHashReport` renders it). This is the correct PowerShell idiom — never mix data and presentation. |

**No new packages to install.** Everything is built into pwsh 7 or already in the repo's CI lockstep.

**Version verification commands** (run once in Wave 0):
```powershell
pwsh --version                                                # → 7.6.0 (local)
(Get-Module -ListAvailable Pester | Sort Version -Desc)[0]    # → 5.7.1 (local)
(Get-Module -ListAvailable PSScriptAnalyzer | Sort Version -Desc)[0]  # → 1.25.0
```

## Architecture Patterns

### System Architecture Diagram

```
                 Phase 5 thin CLI (VeriHash.ps1)
                         │
                         │ Import-Module .\VeriHash.Core\VeriHash.Core.psd1
                         ▼
   ┌──────────────────── VeriHash.Core (script module) ───────────────────┐
   │                                                                      │
   │  Public/Get-VeriHashPlatform.ps1 ◄──── consumed by every function    │
   │                                                                      │
   │  Public/Get-VeriHashResult.ps1 ──► [pscustomobject @{                │
   │     │  Get-Item, Get-FileHash, Stopwatch                             │
   │     │                              PSTypeName='VeriHash.Result'      │
   │     │                              FilePath/Size/Algorithm/Hash/     │
   │     ▼                              ElapsedMs }]                      │
   │                                                                      │
   │  Public/Read-ClipboardHash.ps1                                       │
   │     ├─ Windows: Get-Clipboard ──► Private/Parse-HashString.ps1       │
   │     │                              (1) try 'algo:hex' prefix         │
   │     │                              (2) fall back to length inference │
   │     └─ Linux/macOS: return $null + Write-Verbose                     │
   │                                                                      │
   │  Public/Test-VeriHashSidecar.ps1                                     │
   │     ├─ Private/Get-PreferredSidecar.ps1 (sha512 > sha256 > md5)      │
   │     ├─ Private/Read-SidecarLine.ps1 (regex parse, infer alg)         │
   │     └─ Get-VeriHashResult ──► compare ──► result line                │
   │                                                                      │
   │  Public/Format-VeriHashReport.ps1                                    │
   │     └─ Write-Host blocks pinned to v1 layout (golden-text test)      │
   │                                                                      │
   │  Public/Write-VeriHashLog.ps1                                        │
   │     ├─ gate: -Log OR $env:VERIHASH_LOG=1   (else early return)       │
   │     ├─ resolve path: $env:VERIHASH_LOG_PATH ?? ~/.verihash/...       │
   │     ├─ ensure parent dir exists                                      │
   │     ├─ Private/Format-VeriHashLogLine.ps1 (ISO8601 + 7 fields)       │
   │     └─ Add-Content -Encoding utf8 (single line, append-only)         │
   │                                                                      │
   └──────────────────────────────────────────────────────────────────────┘
                         ▲
                         │ Import-Module
                         │
            Tests/VeriHash.Core.*.Tests.ps1  (Pester 5)
```

Data flow from CLI: parse params → `Import-Module` → call `Get-VeriHashResult` → optionally `Read-ClipboardHash` for compare → optionally `Test-VeriHashSidecar` → `Format-VeriHashReport` → optionally `Write-VeriHashLog` → exit.

### Recommended Project Structure

```
VeriHash.Core/                              # NEW — repo root sibling of VeriHash.ps1
├── VeriHash.Core.psd1                      # manifest (hand-curated after one-time New-ModuleManifest)
├── VeriHash.Core.psm1                      # ~20-line loader (see Pattern §1)
├── Public/                                  # one function per file; basename = function name
│   ├── Get-VeriHashPlatform.ps1
│   ├── Get-VeriHashResult.ps1
│   ├── Read-ClipboardHash.ps1
│   ├── Test-VeriHashSidecar.ps1
│   ├── Format-VeriHashReport.ps1
│   └── Write-VeriHashLog.ps1
└── Private/                                 # internal helpers; NOT exported
    ├── Format-VeriHashLogLine.ps1          # ISO8601 + 7-field formatter
    ├── Resolve-VeriHashLogPath.ps1         # $env:VERIHASH_LOG_PATH ?? default
    ├── Get-PreferredSidecar.ps1            # sha512 > sha256 > md5 picker
    ├── Read-SidecarLine.ps1                # regex parse: ^([A-Fa-f0-9]+)\s+\*?(.+)$
    └── ConvertTo-VeriHashAlgorithm.ps1     # length → 'MD5'|'SHA256'|'SHA512' OR 'algo:' prefix → algo

Tests/                                       # existing flat layout — keep
├── VeriHash.Core.Get-VeriHashResult.Tests.ps1
├── VeriHash.Core.Read-ClipboardHash.Tests.ps1
├── VeriHash.Core.Test-VeriHashSidecar.Tests.ps1
├── VeriHash.Core.Format-VeriHashReport.Tests.ps1
├── VeriHash.Core.Write-VeriHashLog.Tests.ps1
├── VeriHash.Core.Get-VeriHashPlatform.Tests.ps1
├── VeriHash.Core.Module.Tests.ps1          # CORE-01: import + Get-Command listing + manifest sanity
└── Fixtures/
    ├── VeriHash_1024.ico                   # MOVED from Tests/ — keeps fixtures separate
    ├── format-report-golden-md5.txt        # golden text for Format-VeriHashReport
    ├── format-report-golden-sha256.txt
    ├── format-report-golden-sha512.txt
    ├── sidecar-twospace.sha256             # "HASH  filename" form
    └── sidecar-asterisk.sha256             # "HASH *filename" form
```

`[CITED: copilot-instructions.md, CONVENTIONS.md]` Tests live in flat `Tests/` directory; one `*.Tests.ps1` per unit. The proposed split (one Pester file per public function) matches that convention.

### Pattern 1: Thin `.psm1` Loader (locked by CONTEXT.md decision #1)

```powershell
# VeriHash.Core.psm1
$ErrorActionPreference = 'Stop'

# Dot-source private helpers FIRST (public functions depend on them)
Get-ChildItem -Path "$PSScriptRoot/Private" -Filter '*.ps1' -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }

# Then dot-source public functions
$publicFiles = Get-ChildItem -Path "$PSScriptRoot/Public" -Filter '*.ps1'
foreach ($f in $publicFiles) { . $f.FullName }

# Export only public function basenames (belt + suspenders alongside .psd1's FunctionsToExport)
Export-ModuleMember -Function $publicFiles.BaseName
```

`[CITED: learn.microsoft.com — about_Modules / Writing a Windows PowerShell Module]` This pattern (Public/Private folders + thin loader) is the de-facto community standard codified by Warren Frame's PowerShell module template (RamblingCookieMonster) and used by virtually every modern community module (PowerShellForGitHub, Posh-Git, dbatools).

**Why the order matters:** Private functions must be in scope when Public functions are dot-sourced, otherwise the dot-source itself succeeds but the first call to a Public function that references a Private helper fails at runtime. `[VERIFIED: PowerShell scoping behavior — dot-sourced files share the parent scope]`

### Pattern 2: Module Manifest (`.psd1`) Authoring

Generate once, hand-edit thereafter. **Never let `New-ModuleManifest` regenerate over your edits — it strips comments and reorders keys.**

```powershell
# One-time scaffold (run once, then commit and edit by hand):
New-ModuleManifest -Path .\VeriHash.Core\VeriHash.Core.psd1 `
    -RootModule 'VeriHash.Core.psm1' `
    -ModuleVersion '2.0.0' `
    -Author 'arcticpinecone' `
    -Description 'Core hashing, clipboard, sidecar, formatting, logging, and platform detection for VeriHash.' `
    -PowerShellVersion '7.0' `
    -CompatiblePSEditions 'Core' `
    -FunctionsToExport @(
        'Get-VeriHashResult'
        'Read-ClipboardHash'
        'Test-VeriHashSidecar'
        'Format-VeriHashReport'
        'Write-VeriHashLog'
        'Get-VeriHashPlatform'
    ) `
    -CmdletsToExport @() `
    -VariablesToExport @() `
    -AliasesToExport @()
```

**Critical rules** `[VERIFIED: learn.microsoft.com/en-us/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest]`:

1. **`FunctionsToExport` MUST be a literal array, never `'*'`.** Wildcards defeat module autoloading (PowerShell can't index function-name → module-name mappings) and break `Get-Command -Module` discoverability — which is success criterion #1.
2. **`CmdletsToExport`, `VariablesToExport`, `AliasesToExport` MUST also be `@()` (empty array), not `'*'`.** Same reason.
3. **`PowerShellVersion = '7.0'` + `CompatiblePSEditions = 'Core'`** — together these prevent the module from loading in Windows PowerShell 5.1, which lacks `Get-Date -AsUTC` and other 7-only features VeriHash uses.
4. **`RootModule` is the `.psm1` filename** (relative, not absolute path).

### Pattern 3: Result Object + Stopwatch

```powershell
function Get-VeriHashResult {
    [CmdletBinding()]
    [OutputType('VeriHash.Result')]
    param(
        [Parameter(Mandatory)][string]$Path,
        [ValidateSet('MD5','SHA256','SHA512')][string]$Algorithm = 'SHA256'
    )

    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $info = Get-Item -LiteralPath $resolved

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $hash = (Get-FileHash -LiteralPath $resolved -Algorithm $Algorithm).Hash.ToLowerInvariant()
    $sw.Stop()

    [pscustomobject]@{
        PSTypeName = 'VeriHash.Result'
        FilePath   = $resolved
        Size       = [long]$info.Length
        Algorithm  = $Algorithm
        Hash       = $hash
        ElapsedMs  = [int]$sw.ElapsedMilliseconds
    }
}
```

**Why `.ToLowerInvariant()`:** CONTEXT.md decision #2 says "lowercase hex string." v1 used `.ToUpper()` in several places (`VeriHash.ps1:750, 1448, 1473`) — this is a deliberate v2 change. **The planner must explicitly verify Format-VeriHashReport's golden-text fixture either accepts lowercase or normalizes case at the format boundary.** This is an open question the planner needs to resolve before the golden capture.

**Why `LiteralPath`:** filenames containing `[`, `]`, `*`, or `?` (legal on every supported OS) break `-Path`'s wildcard interpretation. Always `LiteralPath` for user-supplied filesystem paths.

`[VERIFIED: PowerShell built-in `Get-FileHash` returns uppercase hex by default — confirmed in pwsh 7.6.0 locally]`

### Pattern 4: Atomic Single-Line Log Append

```powershell
function Write-VeriHashLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('hash','verify')][string]$Op,
        [ValidateSet('MD5','SHA256','SHA512')][string]$Algorithm = 'SHA256',
        [string]$Hash = '-',
        [long]$Bytes = 0,
        [int]$ElapsedMs = 0,
        [Parameter(Mandatory)][ValidateSet('ok','mismatch','missing','error','n/a')][string]$Result,
        [Parameter(Mandatory)][string]$Path,
        [switch]$Log    # caller passes through their own -Log switch
    )

    # Gate: -Log switch OR $env:VERIHASH_LOG=1
    $gateActive = $Log.IsPresent -or $env:VERIHASH_LOG -eq '1'
    if (-not $gateActive) { return }

    # Resolve log path (env var wins over default)
    $logPath = if ($env:VERIHASH_LOG_PATH) {
        $env:VERIHASH_LOG_PATH
    } else {
        Join-Path $HOME '.verihash/verihash.log'
    }

    # Ensure parent dir exists (one-time per process is fine — idempotent)
    $parent = Split-Path -Parent $logPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    # ISO 8601 UTC, second precision (matches CONTEXT.md example "2026-04-18T13:05:42Z")
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    # Path is LAST so spaces don't break field splitting on the first 7 columns
    $line = "$ts $Op $Algorithm $Hash $Bytes $ElapsedMs $Result $Path"

    Add-Content -LiteralPath $logPath -Value $line -Encoding utf8
}
```

**Why `(Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")` and not `Get-Date -Format 'o' -AsUTC`:**

- `-Format 'o'` produces sub-second precision and a `+00:00` offset, e.g. `2026-04-18T13:05:42.1234567+00:00` — does NOT match the locked format example `2026-04-18T13:05:42Z`.
- The literal `Z` suffix is what the locked format requires; the explicit `ssZ` format string produces it. `[VERIFIED: .NET DateTime.ToString format strings — "Z" is treated as a literal character in custom format strings, which is exactly what we want here.]`

**Why `Add-Content -Encoding utf8` and not `Out-File`:**

- `Out-File` defaults to overwriting unless `-Append` is specified; one accidentally missed flag wipes the log.
- In pwsh 7, `Add-Content -Encoding utf8` produces UTF-8 **without BOM** (this changed from Windows PowerShell 5.1, where `utf8` meant with-BOM). `[VERIFIED: PowerShell 7 default encoding is UTF8NoBOM — `learn.microsoft.com/en-us/powershell/scripting/whats-new/migrating-from-windows-powershell-51-to-powershell-7#encoding`]`
- For true cross-process atomicity on multi-line writes you'd need a mutex, but **this logger writes exactly one line per invocation and the OS guarantees a single `WriteFile`/`write(2)` of <PIPE_BUF bytes is atomic**. A single 100-200 byte log line easily fits. `[VERIFIED: POSIX write(2) atomicity below PIPE_BUF (4096 bytes typical); Windows NTFS single-write append is atomic for small buffers]`

### Pattern 5: Sidecar Verify (v1-format compatible)

```powershell
function Test-VeriHashSidecar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path     # path to TARGET file (not the sidecar)
    )

    # Pick strongest sidecar present (sha512 > sha256 > md5)
    $sidecar = Get-PreferredSidecar -TargetPath $Path
    if (-not $sidecar) { return $null }   # no sidecar present

    # Read the (only) line — v1 sidecars are single-file
    $line = Get-Content -LiteralPath $sidecar.Path -TotalCount 1
    $parsed = Read-SidecarLine -Line $line   # returns @{ Hash; Filename } or $null
    if (-not $parsed) {
        # malformed line — log + return error result
        return [pscustomobject]@{
            PSTypeName = 'VeriHash.Result'
            FilePath = $Path; Size = 0; Algorithm = $sidecar.Algorithm
            Hash = ''; ElapsedMs = 0
            Sidecar = "error ($($sidecar.Path | Split-Path -Leaf))"
        }
    }

    $expected = $parsed.Hash.ToLowerInvariant()
    $actual = Get-VeriHashResult -Path $Path -Algorithm $sidecar.Algorithm
    $matched = $actual.Hash -eq $expected
    # ... attach sidecar/match info to result and return
}
```

**Sidecar line regex** `[VERIFIED: existing v1 parser at VeriHash.ps1:1447]`:

```powershell
'^([A-Fa-f0-9]+)\s+\*?(.+)$'
# group 1 = hash hex
# optional '*' = binary marker (sha256sum/md5sum --binary)
# group 2 = filename (may contain spaces — greedy match to end of line is fine, sidecars have one line)
```

This regex already correctly handles both v1 forms (`HASH  filename` two-space and `HASH *filename` asterisk). Port verbatim into `Private/Read-SidecarLine.ps1`.

### Pattern 6: Clipboard Hash Parser (length + prefix forms, prefix wins)

```powershell
function Read-ClipboardHash {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    if ((Get-VeriHashPlatform) -ne 'Windows') {
        Write-Verbose 'Clipboard reading not supported on this platform yet.'
        return $null
    }

    $raw = (Get-Clipboard -ErrorAction SilentlyContinue)
    if (-not $raw) { return $null }
    $text = $raw.Trim()

    # CORE-04: prefix form WINS over length inference.
    # Pattern: <algo>:<hex>  (case-insensitive algo, hex must be exact length for the algo)
    if ($text -match '^(?<algo>md5|sha256|sha512):(?<hash>[A-Fa-f0-9]+)$') {
        $algo = $matches.algo.ToUpperInvariant()
        $hex  = $matches.hash.ToLowerInvariant()
        $expectedLen = @{ MD5 = 32; SHA256 = 64; SHA512 = 128 }[$algo]
        if ($hex.Length -ne $expectedLen) { return $null }   # prefix says one alg, length says another → reject
        return [pscustomobject]@{ Algorithm = $algo; Hash = $hex }
    }

    # CORE-03: length inference fallback
    if ($text -match '^[A-Fa-f0-9]+$') {
        $algo = switch ($text.Length) {
            32  { 'MD5' }
            64  { 'SHA256' }
            128 { 'SHA512' }
            default { $null }
        }
        if ($algo) { return [pscustomobject]@{ Algorithm = $algo; Hash = $text.ToLowerInvariant() } }
    }
    return $null
}
```

**Order matters:** prefix form must be tried first (CORE-04 explicitly states "the explicit prefix overrides length-based inference"). A stray `sha256:` followed by 64 hex chars is 71 chars total — would fail length inference anyway, but the order makes the intent explicit and survives future format additions.

### Pattern 7: Golden-Text Test for `Format-VeriHashReport`

```powershell
# Tests/VeriHash.Core.Format-VeriHashReport.Tests.ps1
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    $script:Fixture = "$PSScriptRoot/Fixtures/format-report-golden-sha256.txt"
}

Describe 'Format-VeriHashReport' {
    It 'Renders v1-compatible output for a SHA256 result' {
        $result = [pscustomobject]@{
            PSTypeName = 'VeriHash.Result'
            FilePath = '/fixtures/sample.bin'
            Size = 1024
            Algorithm = 'SHA256'
            Hash = '0' * 64
            ElapsedMs = 12
        }
        # Capture all streams, normalize line endings
        $actual = (Format-VeriHashReport $result *>&1 | Out-String) -replace "`r`n","`n"
        $expected = (Get-Content -Raw $script:Fixture) -replace "`r`n","`n"
        $actual | Should -BeExactly $expected
    }
}
```

**Capture procedure (do this BEFORE any refactor):**

1. Build a deterministic input file (size, hash → known values).
2. Run the v1 monolith with that file: `& .\VeriHash.ps1 -FilePath .\sample.bin -SkipSignatureCheck -NoPause -Force *>&1 | Out-String > Tests/Fixtures/format-report-golden-sha256.txt`
3. Strip non-deterministic lines (timestamps, "Start UTC", elapsed time) — replace with placeholder tokens like `<TIMESTAMP>` and have the test substitute them in `$actual` before comparison.
4. Commit the fixture in the same commit as the test.

`[VERIFIED: existing test pattern — Tests/VeriHash.Tests.ps1:142-148 already uses *>&1 capture]`

### Pattern 8: Platform Detection (single source of truth)

```powershell
function Get-VeriHashPlatform {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    if ($IsWindows) { return 'Windows' }
    if ($IsLinux)   { return 'Linux'   }
    if ($IsMacOS)   { return 'macOS'   }
    # Fallback for very old Windows PowerShell where $IsWindows is undefined
    if ($null -eq $PSVersionTable.Platform -or $PSVersionTable.Platform -eq 'Win32NT') { return 'Windows' }
    throw "Unable to detect platform: PSVersionTable.Platform=$($PSVersionTable.Platform), OS=$($PSVersionTable.OS)"
}
```

`[VERIFIED: $IsWindows / $IsLinux / $IsMacOS are pwsh 6+ automatic variables — `learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables`]` Since the manifest pins `PowerShellVersion = '7.0'`, these are always defined — the Win32NT fallback is just defensive belt-and-suspenders.

**CORE-08 enforcement (success criterion #5 — "zero duplicate definitions"):** Add a Pester test that greps the entire repo for `RunningOnWindows|RunningOnLinux|RunningOnMacOS|\$IsWindows.*=` and asserts the only matches are inside `VeriHash.Core/Public/Get-VeriHashPlatform.ps1`. This is observable, not just "it compiles":

```powershell
It 'Has zero duplicate platform-detection definitions outside Core' {
    $matches = Select-String -Path "$PSScriptRoot/../**/*.ps1" `
        -Pattern '\$script:RunningOn(Windows|Linux|MacOS)' `
        -Exclude '*Get-VeriHashPlatform.ps1','*Tests.ps1' -ErrorAction SilentlyContinue
    $matches | Should -BeNullOrEmpty
}
```

### Anti-Patterns to Avoid

- **`FunctionsToExport = '*'` in the manifest.** Breaks autoloading + `Get-Command -Module` discoverability. Always literal array.
- **Putting `Export-ModuleMember` inside individual function files.** Only the `.psm1` should call `Export-ModuleMember` (or rely solely on the `.psd1`'s `FunctionsToExport`). Per-file exports create scope confusion.
- **Letting `New-ModuleManifest` regenerate the `.psd1` on every edit.** It strips comments and reorders keys. Generate once, then hand-edit.
- **Using `Out-File -Append`** instead of `Add-Content` for the log. `Out-File` has a different default encoding history and more flag surface area to get wrong.
- **Capturing output with `4>&1` or `2>&1` only** for the golden-text test. Use `*>&1` to merge ALL streams (Write-Host, Verbose, Error, Information) — the v1 monolith uses `Write-Host` heavily and any future migration to `Write-Information` should still be captured.
- **Using `[void]` to discard `New-Item` output.** `New-Item ... | Out-Null` is conventional in this repo (see existing tests).
- **Hand-rolling a stopwatch with `(Get-Date) - $start`.** `[System.Diagnostics.Stopwatch]` is monotonic; subtraction of `Get-Date` values can return negative deltas if the system clock is adjusted mid-run.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| MD5/SHA256/SHA512 hashing | `[System.Security.Cryptography.SHA256]::Create()` + manual stream loop | `Get-FileHash -Algorithm <X>` | Built-in, optimized, supported, returns same hex format you need |
| High-resolution elapsed time | `(Get-Date) - $start` | `[System.Diagnostics.Stopwatch]::StartNew()` | Monotonic; immune to clock adjustment; nanosecond precision |
| ISO 8601 UTC timestamp | Manual string concat | `(Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")` | One line, format-string-pinned, matches CONTEXT.md exactly |
| Single-line log file append | `[IO.StreamWriter]` with manual flush/dispose | `Add-Content -Encoding utf8` | Atomic for <PIPE_BUF bytes; UTF-8 no-BOM by default in pwsh 7 |
| Module manifest scaffold | Hand-write `@{ ... }` from memory | `New-ModuleManifest` once, then commit + edit by hand | Avoids missing required keys; gets GUID right |
| Platform detection | Custom registry-of-platforms hashtable | `$IsWindows / $IsLinux / $IsMacOS` automatic variables | Built into pwsh 7+; CORE-08 says "exactly once" |
| Sidecar line regex | Custom split + trim | Existing v1 regex `^([A-Fa-f0-9]+)\s+\*?(.+)$` | Already battle-tested against v1 user files; CORE-05 requires v1 compatibility |
| Cross-platform clipboard fallback (Linux/macOS) | Shell out to xclip/wl-paste/pbpaste | **Don't** — return `$null`, deferred to v2.x | CONTEXT.md decision #5 explicitly defers; out of scope |

**Key insight:** Phase 1 is a *port + restructure*, not a new domain. Almost every behavior already exists in `VeriHash.ps1` and works correctly on user files. The high-leverage activity is moving code into the right shape (module + Public/Private layout + manifest + tests-via-Import-Module) — NOT re-inventing primitives that pwsh already provides.

## Runtime State Inventory

This phase is a refactor (extract Core module from monolith) — runtime state inventory applies.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| **Stored data** | None — VeriHash has no databases. Sidecar files (`*.sha256` etc.) are user-owned data and must continue to verify against the new Core (CORE-05). v1 sidecar formats are byte-identical to GNU `sha256sum` output. | None for the data itself. **Test action:** include both `HASH  filename` and `HASH *filename` fixtures in `Tests/Fixtures/` to prove v1 files still verify. |
| **Live service config** | None — VeriHash is a CLI tool with no daemon, no service, no remote config. | None. |
| **OS-registered state** | Windows SendTo `.lnk` shortcut and Linux KDE `.desktop` service-menu entry installed by `-SendTo` and `Install-KDEContextMenu`. **These point at `VeriHash.ps1` (which Phase 5 keeps as the entry point).** Phase 1 does NOT touch the entry-point script. | None for Phase 1. Will be revisited in Phase 4 (Integrations) and Phase 5 (CLI). |
| **Secrets/env vars** | New env vars introduced by Phase 1: `$env:VERIHASH_LOG=1` (CORE-07 trigger), `$env:VERIHASH_LOG_PATH` (test isolation override). Existing `$env:VERIHASH_TEST_MODE=1` continues to be honored (carried-forward from v1 — though Phase 1 may stop reading it since PSFramework is going away). | **Planner decision:** does Phase 1's logger honor `VERIHASH_TEST_MODE=1` for backward compatibility, or only `VERIHASH_LOG_PATH`? Recommend: only `VERIHASH_LOG_PATH` (cleaner contract; tests that need isolation set the explicit path). |
| **Build artifacts / installed packages** | None — no compiled binaries, no `pip install -e`, no pip egg-info. PowerShell modules are dot-sourced at runtime. **However:** if a developer has previously run `Import-Module .\VeriHash.Core` interactively before the module exists, `Remove-Module VeriHash.Core` may be needed to clear PowerShell's per-session module cache during iteration. | Add a one-liner to README or to `Test-All.ps1`: `Remove-Module VeriHash.Core -ErrorAction SilentlyContinue` before re-importing in a long-lived session. Pester's `-Force` on `Import-Module` (use `Import-Module ... -Force` in `BeforeAll`) handles this for tests. |

**The canonical question — "After every file in the repo is updated, what runtime systems still have the old string cached, stored, or registered?"** Answer for Phase 1: **nothing.** This is a pure code reshuffle with new module surface; no external runtime state references the old function names (`Invoke-HashFile`, `Get-And-SaveHash`, `Get-ClipboardHash`, `Test-HashSidecar`) outside the repo itself.

## Common Pitfalls

### Pitfall 1: `FunctionsToExport = '*'` (or omitted from manifest)
**What goes wrong:** `Get-Command -Module VeriHash.Core` returns nothing or returns Private helpers; module autoloading silently breaks.
**Why it happens:** `New-ModuleManifest` defaults to wildcard if you don't pass `-FunctionsToExport`; many older blog posts show `'*'` as the example.
**How to avoid:** Pass an explicit array to `New-ModuleManifest`; review the generated `.psd1` and confirm all four export keys are arrays (functions, cmdlets, variables, aliases).
**Warning signs:** Phase 1 success criterion #1 (`Get-Command -Module VeriHash.Core` lists exactly the six public functions) will fail if this is wrong. Make this the FIRST test you write.

### Pitfall 2: `Get-FileHash` returns UPPERCASE; CONTEXT.md says lowercase
**What goes wrong:** Hash mismatches between `Get-VeriHashResult.Hash` and a sidecar that stores lowercase hex (or vice versa); golden-text test for `Format-VeriHashReport` may fail intermittently depending on which path was tested.
**Why it happens:** `Get-FileHash` has always returned uppercase hex in pwsh; the v1 monolith called `.ToUpper()` in several places, masking this. CONTEXT.md decision #2 changes the contract to lowercase.
**How to avoid:** Always `.ToLowerInvariant()` immediately at the boundary in `Get-VeriHashResult`. Compare hashes case-insensitively in `Test-VeriHashSidecar` (lowercase both sides). For `Format-VeriHashReport`'s golden-text fixture, decide explicitly: render lowercase to match the contract. Document this in PATTERNS.md.
**Warning signs:** `[VERIFIED]` test that asserts `(Get-VeriHashResult ./fixture.ico).Hash -cmatch '^[a-f0-9]+$'` (case-sensitive lowercase regex).

### Pitfall 3: `Read-ClipboardHash` order — length-first hides prefix bugs
**What goes wrong:** A 64-char string `sha256:abc...` (71 chars total) doesn't match length-32/64/128, so it falls through. But a malicious or careless `md5:0000...0000` (32-hex `0000...0000` after `md5:`, total 36 chars) — fine. The bug emerges if someone writes `sha256:` followed by exactly 64 hex chars padded — depends on parser order. **Try prefix FIRST**, then length inference.
**Why it happens:** Code-by-accretion tendency to add the new branch (prefix form) at the end.
**How to avoid:** Pattern §6 above puts prefix-match first. Test both orders in CORE-04 unit tests.
**Warning signs:** Test must include: `Mock Get-Clipboard { 'md5:5d41402abc4b2a76b9719d911017c592' }` → expect Algorithm = MD5; AND a length-inference fallback case for plain hex.

### Pitfall 4: `Add-Content` and concurrent writes
**What goes wrong:** If two `pwsh` processes invoke `Write-VeriHashLog` simultaneously and the line is large (>4KB on POSIX, varies on Windows), bytes interleave.
**Why it happens:** No file locking by default; OS atomicity guarantees only apply below `PIPE_BUF`.
**How to avoid:** Keep log lines short (the locked format is ~150-250 bytes — well under any concern). Don't add multi-line log entries to the format. If a future need for multi-line arises, switch to `[System.IO.File]::AppendAllText` inside a try/finally with a named mutex — but Phase 1 doesn't need this.
**Warning signs:** Anyone proposing to log a stack trace or multi-line error to this logger. The contract is one line per invocation, full stop.

### Pitfall 5: BOM in log file (Windows PowerShell habits)
**What goes wrong:** `Get-Content` on a BOM-prefixed log file returns clean strings (PowerShell strips BOM); `cat`/`grep`/`tail` on Linux show `\ufeff` at the start of every line — which makes log lines unparseable by `awk`/`cut` users.
**Why it happens:** Windows PowerShell 5.1's `Add-Content -Encoding utf8` writes a BOM. Pwsh 7's `utf8` is BOM-less. Code copy-pasted from older guides may explicitly request `utf8BOM`.
**How to avoid:** Always `Add-Content -Encoding utf8` (or explicitly `utf8NoBOM` to be belt-and-suspenders). Test: `(Get-Content $logPath -AsByteStream)[0..2]` should not be `0xEF, 0xBB, 0xBF`.
**Warning signs:** A user reports their `grep "ok " ~/.verihash/verihash.log` returns matches with weird leading characters.

### Pitfall 6: Dot-sourcing scope when `Public` references `Private`
**What goes wrong:** Public function calls a Private helper that "isn't defined" at runtime — even though the file exists.
**Why it happens:** `.psm1` dot-sources Public files BEFORE Private files; or one of the Public files dot-sources another file using `$PSScriptRoot` from inside a function body (which resolves to the *function file's* directory, but only at module-import time — not always intuitive).
**How to avoid:** Pattern §1 above sources Private FIRST, then Public. Functions never dot-source other files at runtime — only the `.psm1` loader does.
**Warning signs:** Test fails with `The term 'Format-VeriHashLogLine' is not recognized as a name of a cmdlet, function, script file, or executable program.`

### Pitfall 7: `Get-Date -AsUTC -Format 'o'` produces wrong format
**What goes wrong:** Log lines look like `2026-04-18T13:05:42.1234567+00:00 hash sha256 ...` instead of the locked `2026-04-18T13:05:42Z hash sha256 ...`. Field-splitting on the first 7 columns still works (path is last), but downstream tooling that pattern-matches on `Z$` for timestamp fields breaks.
**Why it happens:** `-Format 'o'` is the "round-trippable" format — fully precise, includes offset.
**How to avoid:** Use the explicit format string `"yyyy-MM-ddTHH:mm:ssZ"` after `.ToUniversalTime()`. The `Z` in the format string is treated as a literal character. Test the literal output, not just regex match.
**Warning signs:** `[VERIFIED]` test: `Write-VeriHashLog` produces a line whose timestamp matches `^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$` exactly (no fractional seconds, no offset).

### Pitfall 8: Tests that dot-source instead of `Import-Module`
**What goes wrong:** CORE-01 success criterion #1 requires `Import-Module` works. If tests dot-source the .psm1 directly, the module never actually exercises its manifest, `Get-Command -Module` returns nothing, and the criterion is silently violated.
**Why it happens:** Habit from v1 (`. "$PSScriptRoot\..\VeriHash.ps1" -FilePath "dummy"` pattern).
**How to avoid:** Every Phase 1 test's `BeforeAll` must use `Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force`. The `-Force` flag is essential — it reloads the module if a previous test imported it, picking up source changes mid-session.
**Warning signs:** A test passes locally but fails in CI because the developer had the module loaded interactively. `Get-Command -Module VeriHash.Core` returning empty is the smoking gun.

## Code Examples

All examples above (Patterns §1–§8) are the canonical templates. Two more snippets the planner will reuse verbatim:

### Module Test Skeleton (per public function)

```powershell
# Tests/VeriHash.Core.Get-VeriHashResult.Tests.ps1
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    $script:Fixture = Join-Path $PSScriptRoot 'Fixtures/VeriHash_1024.ico'
}

AfterAll {
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}

Describe 'Get-VeriHashResult' {
    Context 'When given a real file' {
        It 'Returns a VeriHash.Result for SHA256' {
            $r = Get-VeriHashResult -Path $script:Fixture -Algorithm SHA256
            $r.PSObject.TypeNames | Should -Contain 'VeriHash.Result'
            $r.FilePath | Should -Be (Resolve-Path $script:Fixture).Path
            $r.Algorithm | Should -Be 'SHA256'
            $r.Hash | Should -Match '^[a-f0-9]{64}$'   # lowercase, 64 hex
            $r.Size | Should -BeOfType [long]
            $r.ElapsedMs | Should -BeGreaterOrEqual 0
        }
        It 'Returns 32-hex for MD5'    { (Get-VeriHashResult -Path $script:Fixture -Algorithm MD5).Hash    | Should -Match '^[a-f0-9]{32}$'  }
        It 'Returns 128-hex for SHA512'{ (Get-VeriHashResult -Path $script:Fixture -Algorithm SHA512).Hash | Should -Match '^[a-f0-9]{128}$' }
    }
}
```

### Module-Level Sanity Test (CORE-01)

```powershell
# Tests/VeriHash.Core.Module.Tests.ps1
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
}

Describe 'VeriHash.Core module' {
    It 'Imports cleanly via .psd1' {
        Get-Module VeriHash.Core | Should -Not -BeNullOrEmpty
    }
    It 'Exports exactly the six locked public functions' {
        $expected = 'Get-VeriHashResult','Read-ClipboardHash','Test-VeriHashSidecar',
                    'Format-VeriHashReport','Write-VeriHashLog','Get-VeriHashPlatform'
        $actual = (Get-Command -Module VeriHash.Core).Name | Sort-Object
        $actual | Should -Be ($expected | Sort-Object)
    }
    It 'Manifest pins PowerShell 7+ and Core edition' {
        $m = Test-ModuleManifest "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1"
        $m.PowerShellVersion | Should -Be ([version]'7.0')
        $m.CompatiblePSEditions | Should -Contain 'Core'
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Dot-sourced `.ps1` files at repo root + monolith | `.psd1` + `.psm1` script module with `Public/Private/` folders | PowerShell 5.0 introduced full script-module support; community standardized 2017+ | Phase 1 adopts standard layout; tests use real `Import-Module` |
| `Write-PSFMessage` (PSFramework JSONL) | Built-in `Add-Content` plain-text logger | v2.0 milestone decision (CONTEXT.md decision #4) | No external dep; trivially greppable with `grep`/`Select-String`; one-line-per-invocation contract |
| `$script:RunningOnWindows / Linux / MacOS` triple defined in 3 files | Single `Get-VeriHashPlatform` exported by Core | CORE-08 requirement | Eliminates drift between three identical-but-separate definitions |
| `Get-Date -AsUTC -Format 'o'` (with sub-second + offset) | `(Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")` | Format pinned in CONTEXT.md | Stable, parseable, second-precision-only timestamps |
| Test dot-source hack (`. .\VeriHash.ps1 -FilePath "dummy"`) | `Import-Module .\VeriHash.Core\VeriHash.Core.psd1 -Force` | CORE-01 | No more dummy filepath; tests load the module the way users will |

**Deprecated/outdated for THIS phase:**

- **`Write-PSFMessage` and `$script:PSFrameworkAvailable` guards** — do NOT introduce in any new Core file. Phase 4 will excise existing usage from the rest of the codebase.
- **PowerShell `class` for result types** — rejected per CONTEXT.md decision #2 (cold-start cost matters for Phase 2 hot path).
- **`Get-FileHash` uppercase output** — normalize to lowercase at the boundary; v1's `.ToUpper()` is a casing flip that v2 reverses.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Add-Content -Encoding utf8` in pwsh 7 produces UTF-8 *without* BOM (changed from Windows PS 5.1) | Pattern §4, Pitfall §5 | If wrong, log lines start with `\ufeff` and break grep/awk for users. Mitigate by adding a Pester test that asserts the first 3 bytes of the log file are NOT BOM. `[VERIFIED via Microsoft docs link, but worth a one-line confirming test]` |
| A2 | Single-line `Add-Content` writes <PIPE_BUF bytes are atomic on Linux/macOS and atomic-enough on Windows NTFS for concurrent appends | Pattern §4, Pitfall §4 | If wrong, concurrent VeriHash invocations could interleave bytes. Realistic risk: very low (same user, same shell, sequential invocations dominant). Mitigate only if a real concurrent use case appears. |
| A3 | The planner will treat the `.ToLowerInvariant()` change for hash output as breaking from v1 and capture the golden-text fixture against the *new* lowercase contract, not v1's uppercase output in some places | Pattern §3, Pitfall §2 | If wrong, golden-text test will be brittle: rendering lowercase but fixture has uppercase. Resolution: planner explicitly chooses lowercase (matches CONTEXT.md decision #2) and regenerates fixture from a controlled v2 prototype, NOT a v1 capture. |
| A4 | `$env:VERIHASH_TEST_MODE=1` no longer needs to gate logging behavior (it was a PSFramework-routing flag); the new contract is `$env:VERIHASH_LOG_PATH` for redirection | Runtime State Inventory | If tests still set `VERIHASH_TEST_MODE` and expect log redirection, they'll write to the user's real `~/.verihash/verihash.log`. Mitigate by making this an explicit decision item for the planner — see Notes for the Planner. |
| A5 | The Phase 1 module does NOT need to keep `ConvertTo-SanitizedPath` privacy redaction in the new logger — the locked log format records the full `$path` as the last field. Privacy redaction was a v1 PSFramework concern. | Pattern §4 | If the user's intent is "still sanitize paths in the new plain-text log," then `Path` field would need redaction before write. CONTEXT.md format example shows `<path>` last — implies full path. Worth confirming with the planner; flag for discuss-phase if uncertain. |

## Open Questions

1. **Golden-text fixture: capture from v1 verbatim, or generate fresh against v2 lowercase contract?**
   - What we know: CONTEXT.md says "visually compatible with v1." v1 used uppercase hex in some output paths.
   - What's unclear: Is "visually compatible" strict (byte-identical) or visual layout only (column positions, labels, colors)?
   - Recommendation: **Visual layout only.** Hash values render in lowercase per CONTEXT.md decision #2. Capture a v1 baseline for layout reference but let the v2 fixture be generated against the v2 contract. Otherwise CORE-06 and decision #2 collide.

2. **Does `Write-VeriHashLog` redact the path, or write it verbatim?**
   - What we know: Locked format places `<path>` last and uses single-space separators (suggests verbatim — and "spaces in paths cannot break splitting on the first 7 columns" wording).
   - What's unclear: v1 had aggressive privacy redaction via `ConvertTo-SanitizedPath`; CONTEXT.md doesn't say whether that's preserved.
   - Recommendation: **Verbatim path**, no redaction. The log is opt-in (`-Log` / env var); the user explicitly asked for it. If redaction is desired later, it's a wrapping concern, not a Core concern.

3. **Should `VERIHASH_TEST_MODE=1` still do anything in Phase 1?**
   - What we know: v1 used it to route PSFramework logs to `logs/test/`. PSFramework is being removed.
   - What's unclear: Whether tests still rely on this env var to mean "don't pollute prod logs."
   - Recommendation: **Phase 1 ignores `VERIHASH_TEST_MODE`.** Tests use `$env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')` for redirection — cleaner, more explicit, and `TestDrive`-scoped (auto-cleaned by Pester).

4. **`Format-VeriHashReport` input contract: takes a single result, or a result + comparison context?**
   - What we know: v1's `Invoke-HashFile` mixes "render the file metadata block" with "render the verification result."
   - What's unclear: Does `Format-VeriHashReport` accept just a `VeriHash.Result`, or also a `-CompareTo` (clipboard hash) and `-Sidecar` (sidecar info)?
   - Recommendation: **Accept the result by pipeline + optional `-CompareTo` and `-SidecarInfo` parameters.** Test golden text with all three combinations: no-compare, with-clipboard-compare, with-sidecar-compare.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PowerShell 7+ (`pwsh`) | All Core code (manifest pins `7.0`) | ✓ | 7.6.0 (verified locally) | None — non-negotiable |
| Pester | All Phase 1 tests | ✓ | 5.7.1 (verified locally; CI pins `<= 5.99`) | None — required |
| PSScriptAnalyzer | Lint of `VeriHash.Core/**/*.ps1` (extends existing CI lint) | ✓ | 1.25.0 (verified locally) | None — required |
| `Get-Clipboard` (built-in pwsh 7 on Windows) | `Read-ClipboardHash` Windows path | ✓ on Windows | built-in | Linux/macOS: graceful `$null` (CONTEXT.md decision #5) |
| `~/.verihash/` directory | `Write-VeriHashLog` default path | Will be created on demand | — | `$env:VERIHASH_LOG_PATH` overrides |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** `Get-Clipboard` on Linux/macOS (planned: return `$null`, not an error).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Pester 5.7.1 (CI pinned to `Install-Module Pester -MaximumVersion '5.99' -Scope CurrentUser -Force`) |
| Config file | None — config is built inline via `New-PesterConfiguration` in `Test-All.ps1` and `.github/workflows/ci.yml` |
| Quick run command | `Invoke-Pester -Path 'Tests/VeriHash.Core.*.Tests.ps1' -Output Detailed` |
| Full suite command | `.\Test-All.ps1` (Pester + PSScriptAnalyzer + profiler) |
| CI invocation | `.\Test-All.ps1 -CI` (sets `$config.Run.Exit = $true`) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| CORE-01 | Module imports via `.psd1`; `Get-Command -Module VeriHash.Core` lists 6 functions | unit (module sanity) | `Invoke-Pester -Path Tests/VeriHash.Core.Module.Tests.ps1` | ❌ Wave 0 |
| CORE-02 | `Get-VeriHashResult` returns shaped object for MD5/SHA256/SHA512 | unit | `Invoke-Pester -Path Tests/VeriHash.Core.Get-VeriHashResult.Tests.ps1` | ❌ Wave 0 |
| CORE-03 | `Read-ClipboardHash` length inference (32/64/128 → MD5/SHA256/SHA512) | unit (with `Mock Get-Clipboard`) | `Invoke-Pester -Path Tests/VeriHash.Core.Read-ClipboardHash.Tests.ps1` | ❌ Wave 0 |
| CORE-04 | `Read-ClipboardHash` prefix form (`md5:`/`sha256:`/`sha512:`) overrides length | unit (with `Mock Get-Clipboard`) | same file as CORE-03 | ❌ Wave 0 |
| CORE-05 | Sidecar verify against v1 `HASH  filename` AND `HASH *filename`; sha512>sha256>md5 precedence | integration (uses real fixture files) | `Invoke-Pester -Path Tests/VeriHash.Core.Test-VeriHashSidecar.Tests.ps1` | ❌ Wave 0 |
| CORE-06 | `Format-VeriHashReport` golden-text matches v1 visual layout (lowercase hash) | golden-text (capture+compare) | `Invoke-Pester -Path Tests/VeriHash.Core.Format-VeriHashReport.Tests.ps1` | ❌ Wave 0 (fixture also Wave 0) |
| CORE-07 | `Write-VeriHashLog` writes exactly one line when gated; respects `$env:VERIHASH_LOG_PATH`; no-op when ungated | unit (uses `$TestDrive` for log path) | `Invoke-Pester -Path Tests/VeriHash.Core.Write-VeriHashLog.Tests.ps1` | ❌ Wave 0 |
| CORE-08 | `Get-VeriHashPlatform` returns string; zero duplicate platform-detection definitions in repo | unit + repo-grep assertion | `Invoke-Pester -Path Tests/VeriHash.Core.Get-VeriHashPlatform.Tests.ps1` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `Invoke-Pester -Path 'Tests/VeriHash.Core.*.Tests.ps1' -Output Detailed` (~3-10 seconds)
- **Per wave merge:** `.\Test-All.ps1 -SkipProfiler` (full Pester + lint, ~30 seconds)
- **Phase gate:** `.\Test-All.ps1 -CI` green on both Windows and Linux runners before `/gsd-verify-work`. CORE-01 and CORE-08 must pass on both OS.

### Wave 0 Gaps

All test infrastructure for Phase 1 is new. Wave 0 must establish:

- [ ] `Tests/VeriHash.Core.Module.Tests.ps1` — covers CORE-01 (import + Get-Command + manifest sanity)
- [ ] `Tests/VeriHash.Core.Get-VeriHashResult.Tests.ps1` — covers CORE-02
- [ ] `Tests/VeriHash.Core.Read-ClipboardHash.Tests.ps1` — covers CORE-03 + CORE-04 (with `Mock Get-Clipboard`)
- [ ] `Tests/VeriHash.Core.Test-VeriHashSidecar.Tests.ps1` — covers CORE-05
- [ ] `Tests/VeriHash.Core.Format-VeriHashReport.Tests.ps1` — covers CORE-06 (depends on golden-text fixture)
- [ ] `Tests/VeriHash.Core.Write-VeriHashLog.Tests.ps1` — covers CORE-07 (uses `$TestDrive` + `$env:VERIHASH_LOG_PATH`)
- [ ] `Tests/VeriHash.Core.Get-VeriHashPlatform.Tests.ps1` — covers CORE-08 (function + repo-grep assertion)
- [ ] `Tests/Fixtures/format-report-golden-{md5,sha256,sha512}.txt` — golden-text fixtures for CORE-06
- [ ] `Tests/Fixtures/sidecar-twospace.sha256` and `Tests/Fixtures/sidecar-asterisk.sha256` — v1-format sidecar fixtures for CORE-05
- [ ] *(Optional)* Move `Tests/VeriHash_1024.ico` to `Tests/Fixtures/VeriHash_1024.ico` and update existing v1 tests that reference the old path. **Decision deferred to planner** — may be cleaner to leave the icon at its current location to avoid touching v1 tests in this phase.

Framework install (Wave 0 — likely already done locally; required for CI):
```powershell
Install-Module Pester -MaximumVersion '5.99' -Scope CurrentUser -Force
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
```

### Why this is enough sampling (Nyquist)

Each CORE-NN requirement has at minimum one dedicated `It` block with a deterministic input → expected-output assertion. Risk-weighted areas (CORE-04 prefix-vs-length precedence; CORE-05 two-format sidecar parsing; CORE-06 golden-text byte equality) get multiple `It` blocks per scenario. Cross-platform coverage (CORE-01, CORE-08) is sampled in CI matrix (Windows + Linux jobs). Runtime is fast enough (~3-10s for the Phase 1 subset) to run per-task-commit without slowing iteration.

## Sources

### Primary (HIGH confidence)

- **CONTEXT.md** (`.planning/phases/01-core-module-foundation/01-CONTEXT.md`) — all locked decisions, requirement coverage, deferred ideas
- **REQUIREMENTS.md** (`.planning/REQUIREMENTS.md`) — CORE-01..CORE-08 verbatim
- **ROADMAP.md** (`.planning/ROADMAP.md` Phase 1 section) — five success criteria
- **Existing v1 monolith** (`VeriHash.ps1` lines 650-774, 780-1023, 1024-1391, 1392-1517) — proven behavior to port
- **`.planning/codebase/CONVENTIONS.md`** — function/file/variable naming, comment-based-help requirements, error-handling pattern, platform-detection idioms
- **`.planning/codebase/TESTING.md`** — Pester 5.x patterns, `BeforeAll`/`AfterAll` skeleton, mocking conventions, TDD rule
- **`.planning/codebase/STRUCTURE.md`** — repo layout, where tests live (`Tests/` flat directory)
- **`.github/copilot-instructions.md`** — build/test/lint commands; TDD rule; non-interactive test invocations
- **Microsoft Learn — `about_Modules`** (`learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_modules`) — script module concepts
- **Microsoft Learn — Module Manifest** (`learn.microsoft.com/en-us/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest`) — `.psd1` keys, `FunctionsToExport` rules
- **Microsoft Learn — pwsh 7 migration / encoding** (`learn.microsoft.com/en-us/powershell/scripting/whats-new/migrating-from-windows-powershell-51-to-powershell-7#encoding`) — pwsh 7 default encoding is UTF8NoBOM
- **Microsoft Learn — `about_Automatic_Variables`** (`learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables`) — `$IsWindows / $IsLinux / $IsMacOS` semantics in pwsh 6+

### Secondary (MEDIUM confidence — community convention, widely adopted but not formal spec)

- **Public/Private folder layout with thin `.psm1` loader** — RamblingCookieMonster's "Building a PowerShell Module" template; codified in PowerShellForGitHub, dbatools, Posh-Git, Pester itself
- **`[pscustomobject]` + `PSTypeName` over `class`** — community guidance for cold-start-sensitive modules; Bruce Payette's *PowerShell in Action* discusses class compile cost

### Tertiary (LOW confidence — none used)

None. All claims either map to verified Microsoft documentation, the repo's own CONTEXT/REQUIREMENTS/codebase docs, or the existing battle-tested v1 source code.

## Metadata

**Confidence breakdown:**

- Standard stack: **HIGH** — pwsh 7.6.0, Pester 5.7.1, PSScriptAnalyzer 1.25.0 all verified locally; CI already pins versions; no new external deps proposed
- Architecture: **HIGH** — every pattern is either Microsoft-documented or already proven in v1 source; CONTEXT.md has locked the contentious decisions
- Pitfalls: **HIGH (5 of 8) / MEDIUM (3 of 8)** — Pitfalls 1, 2, 5, 7, 8 are documented PowerShell behaviors; Pitfalls 3, 4, 6 are pattern-based ("here's how to avoid foot-gun X") and based on standard practice rather than a specific cited authority
- Validation architecture: **HIGH** — direct map from each CORE-NN requirement to an automated Pester assertion; Wave 0 gaps explicitly enumerated

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (30 days — stack is stable; pwsh, Pester, and PSScriptAnalyzer release on slow cadences and the locked patterns don't depend on bleeding-edge features)

## RESEARCH COMPLETE
