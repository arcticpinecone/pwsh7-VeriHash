---
phase: 02-hot-path-performance-multi-file-loop
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - VeriHash.HotPath/VeriHash.HotPath.psd1
  - VeriHash.HotPath/VeriHash.HotPath.psm1
  - VeriHash.HotPath/Public/Get-VeriHashSignature.ps1
  - VeriHash.HotPath/Private/Test-IsPEFile.ps1
  - VeriHash.HotPath/Private/Invoke-WinVerifyTrust.ps1
  - VeriHash.HotPath/Private/ConvertFrom-WinTrustHResult.ps1
  - Tests/VeriHash.HotPath.Tests.ps1
  - Tests/VeriHash.HotPath.PE.Tests.ps1
  - Tests/VeriHash.HotPath.Sig.Tests.ps1
  - Tests/Fixtures/tiny-pe.bin
  - Tests/Fixtures/tiny-not-pe.bin
autonomous: true
requirements:
  - PERF-01
  - PERF-02
must_haves:
  truths:
    - "Module VeriHash.HotPath imports cleanly on Windows AND Linux."
    - "Get-Command -Module VeriHash.HotPath lists Get-VeriHashSignature (the only Public surface in this plan)."
    - "Test-IsPEFile returns $true iff first two bytes are 0x4D 0x5A; returns $false on <2-byte files, directories, missing files, broken symlinks (no exception)."
    - "Get-VeriHashSignature on Windows for a PE file invokes Invoke-WinVerifyTrust with dwProvFlags containing both 0x10 (WTD_REVOCATION_CHECK_NONE) and 0x1000 (WTD_CACHE_ONLY_URL_RETRIEVAL) AND fdwRevocationChecks=0 (WTD_REVOKE_NONE), and NEVER passes WTD_DISABLE_MD2_MD4."
    - "Get-VeriHashSignature on non-Windows returns Status='skipped', Reason='not supported on this platform' without P/Invoking."
    - "Re-importing the module with -Force does not throw 'type already defined'."
  artifacts:
    - path: "VeriHash.HotPath/VeriHash.HotPath.psd1"
      provides: "Module manifest with FunctionsToExport including Get-VeriHashSignature, PowerShellVersion 7.0, CompatiblePSEditions Core"
    - path: "VeriHash.HotPath/VeriHash.HotPath.psm1"
      provides: "Loader: dot-source Private/*.ps1 then Public/*.ps1"
    - path: "VeriHash.HotPath/Private/Test-IsPEFile.ps1"
      provides: "PE magic-byte predicate"
    - path: "VeriHash.HotPath/Private/Invoke-WinVerifyTrust.ps1"
      provides: "Add-Type P/Invoke shim + verify call returning HRESULT (Windows-only)"
    - path: "VeriHash.HotPath/Private/ConvertFrom-WinTrustHResult.ps1"
      provides: "HRESULT → {Status, Reason} mapping per RESEARCH.md Pitfall 3 table"
    - path: "VeriHash.HotPath/Public/Get-VeriHashSignature.ps1"
      provides: "Platform-gated public wrapper returning {Status, Reason}"
  key_links:
    - from: "Get-VeriHashSignature.ps1"
      to: "Invoke-WinVerifyTrust.ps1"
      via: "private function call inside InModuleScope"
      pattern: "Invoke-WinVerifyTrust -Path"
    - from: "Get-VeriHashSignature.ps1"
      to: "Get-VeriHashPlatform (VeriHash.Core)"
      via: "platform gate at top of function"
      pattern: "Get-VeriHashPlatform"
---

<objective>
Stand up the VeriHash.HotPath module skeleton (manifest, loader, Private/, Public/), add PE magic-byte detection (Test-IsPEFile), and ship the Authenticode signature wrapper Get-VeriHashSignature backed by a WinVerifyTrust P/Invoke shim with NETWORK CRL LOOKUPS DISABLED.

Purpose: Closes PERF-01 (PE-only signature) and PERF-02 (no network CRL on signature checks) and gives Plan 02's orchestrator a working `Get-VeriHashSignature` to compose.

Output: A `VeriHash.HotPath` module that imports on Windows + Linux + macOS, exports `Get-VeriHashSignature`, and passes Tests/VeriHash.HotPath.Tests.ps1 / .PE.Tests.ps1 / .Sig.Tests.ps1.
</objective>

<execution_context>
@~/.copilot/get-shit-done/workflows/execute-plan.md
@~/.copilot/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/REQUIREMENTS.md
@.planning/phases/02-hot-path-performance-multi-file-loop/02-CONTEXT.md
@.planning/phases/02-hot-path-performance-multi-file-loop/02-RESEARCH.md
@.planning/phases/02-hot-path-performance-multi-file-loop/02-PATTERNS.md
@.planning/phases/02-hot-path-performance-multi-file-loop/02-VALIDATION.md
@.planning/phases/01-core-module-foundation/01-01-SUMMARY.md
@.planning/phases/01-core-module-foundation/01-02-SUMMARY.md
@.planning/codebase/CONVENTIONS.md
@.planning/codebase/TESTING.md
@.github/copilot-instructions.md

# Phase 1 surface this plan composes:
@VeriHash.Core/VeriHash.Core.psd1
@VeriHash.Core/VeriHash.Core.psm1
@VeriHash.Core/Public/Get-VeriHashPlatform.ps1
@VeriHash.Core/Public/Read-ClipboardHash.ps1
@VeriHash.Core/Public/Get-VeriHashResult.ps1
@VeriHash.Core/Private/Resolve-VeriHashLogPath.ps1

# Test analogs:
@Tests/VeriHash.Core.Module.Tests.ps1
@Tests/VeriHash.Core.Get-VeriHashResult.Tests.ps1
@Tests/VeriHash.Core.Read-ClipboardHash.Tests.ps1

<interfaces>
<!-- Phase 1 surface this plan calls -->

From VeriHash.Core/Public/Get-VeriHashPlatform.ps1:
```powershell
function Get-VeriHashPlatform { [OutputType([string])] param() }   # returns 'Windows' | 'Linux' | 'macOS'
```

<!-- New surface introduced by this plan -->

VeriHash.HotPath/Public/Get-VeriHashSignature.ps1:
```powershell
function Get-VeriHashSignature {
    [CmdletBinding()] [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [switch] $IsPE
    )
    # returns: [pscustomobject]@{ Status = 'valid'|'invalid'|'unsigned'|'skipped'|'error'; Reason = '<short string>' }
}
```

VeriHash.HotPath/Private/Test-IsPEFile.ps1:
```powershell
function Test-IsPEFile { [OutputType([bool])] param([Parameter(Mandatory)][string]$Path) }
```

VeriHash.HotPath/Private/Invoke-WinVerifyTrust.ps1:
```powershell
function Invoke-WinVerifyTrust { [OutputType([int])] param([Parameter(Mandatory)][string]$Path) }   # returns raw HRESULT (int)
```

VeriHash.HotPath/Private/ConvertFrom-WinTrustHResult.ps1:
```powershell
function ConvertFrom-WinTrustHResult { [OutputType([pscustomobject])] param([Parameter(Mandatory)][int]$HResult) }
# returns { Status; Reason }
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 0 (PRE-WAVE-1 GATE): Pin WINTRUST_DATA struct layout + flag-name distinction</name>
  <read_first>
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-RESEARCH.md (esp. lines 259-300 Pattern 2; lines 360-380 Pitfalls 2 & 3 HRESULT table; lines 533-544 Assumptions A1 + A2; lines 386-389 Pitfall 4 STATEACTION_CLOSE)
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-CONTEXT.md (D-A1-1 locked flag set + forbidden flags)
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-PATTERNS.md (lines 310-345 — "No in-repo analog" notice for Invoke-WinVerifyTrust)
  </read_first>
  <action>
Resolve RESEARCH.md Assumptions A1 and A2 BEFORE any P/Invoke code is written. Produce a single file `.planning/phases/02-hot-path-performance-multi-file-loop/02-01-PINVOKE-PIN.md` containing:

**Section 1 — `WINTRUST_DATA` struct (verbatim from canonical source).** Use `wintrust.h` (Windows 10/11 SDK) OR pinvoke.net's `wintrust/WinVerifyTrust` page OR `learn.microsoft.com/en-us/windows/win32/api/wintrust/ns-wintrust-wintrust_data`. Cite the source URL/SDK header version inline. Lock the C# field list in this exact order (do NOT improvise):

```csharp
[StructLayout(LayoutKind.Sequential)]
public struct WINTRUST_DATA {
    public uint   cbStruct;
    public IntPtr pPolicyCallbackData;
    public IntPtr pSIPClientData;
    public uint   dwUIChoice;             // WTD_UI_NONE = 2
    public uint   fdwRevocationChecks;    // WTD_REVOKE_NONE = 0
    public uint   dwUnionChoice;          // WTD_CHOICE_FILE = 1
    public IntPtr pFile;                  // → WINTRUST_FILE_INFO*
    public uint   dwStateAction;          // WTD_STATEACTION_VERIFY = 1, WTD_STATEACTION_CLOSE = 2
    public IntPtr hWVTStateData;          // populated by VERIFY, freed by CLOSE
    [MarshalAs(UnmanagedType.LPWStr)] public string pwszURLReference;
    public uint   dwProvFlags;            // WTD_REVOCATION_CHECK_NONE (0x00000010) | WTD_CACHE_ONLY_URL_RETRIEVAL (0x00001000)
    public uint   dwUIContext;
    public IntPtr pSignatureSettings;     // Win8+, IntPtr.Zero for our use
}
```

If the canonical source disagrees (e.g., adds/removes a field, renames `pSignatureSettings`), update the layout and document the diff. NEVER ship a struct that doesn't match the source.

**Section 2 — `WINTRUST_FILE_INFO` struct (verbatim):**

```csharp
[StructLayout(LayoutKind.Sequential)]
public struct WINTRUST_FILE_INFO {
    public uint   cbStruct;
    [MarshalAs(UnmanagedType.LPWStr)] public string pcwszFilePath;
    public IntPtr hFile;             // IntPtr.Zero
    public IntPtr pgKnownSubject;    // IntPtr.Zero
}
```

**Section 3 — Action GUID (`WINTRUST_ACTION_GENERIC_VERIFY_V2`):**
`{00AAC56B-CD44-11D0-8CC2-00C04FC295EE}` — confirm from the same source.

**Section 4 — Flag naming clarification (resolves A2):**
Document explicitly that BOTH must be set:
- `fdwRevocationChecks = WTD_REVOKE_NONE = 0` (an `fdwRevocationChecks` value)
- `dwProvFlags |= WTD_REVOCATION_CHECK_NONE = 0x00000010` (a `dwProvFlags` value)
- `dwProvFlags |= WTD_CACHE_ONLY_URL_RETRIEVAL = 0x00001000`
The CONTEXT.md name "WTD_REVOCATION_NONE" refers to the dwProvFlags constant `WTD_REVOCATION_CHECK_NONE` (0x10). They are different fields with different namespaces; both must be set for PERF-02.

**Section 5 — Forbidden flag list (D-A1-1):** `WTD_DISABLE_MD2_MD4` and any other downgrade flag. Hard-coded grep-target for an acceptance criterion.

**Section 6 — HRESULT → Status table (verbatim from RESEARCH.md Pitfall 3):** Reproduce the 8-row table; this is the source of truth for `ConvertFrom-WinTrustHResult.ps1` in Task 2.

This file is read by Task 2; the executor copies the struct/flag/HRESULT lists verbatim from it. No struct invention.
  </action>
  <verify>
    <automated>Test-Path .planning/phases/02-hot-path-performance-multi-file-loop/02-01-PINVOKE-PIN.md -PathType Leaf; Select-String -Path .planning/phases/02-hot-path-performance-multi-file-loop/02-01-PINVOKE-PIN.md -Pattern 'WTD_REVOCATION_CHECK_NONE.*0x00000010|0x10','WTD_CACHE_ONLY_URL_RETRIEVAL.*0x00001000|0x1000','WTD_REVOKE_NONE.*=.*0','WINTRUST_ACTION_GENERIC_VERIFY_V2','00AAC56B-CD44-11D0-8CC2-00C04FC295EE','WTD_DISABLE_MD2_MD4'</automated>
  </verify>
  <acceptance_criteria>
    - File `.planning/phases/02-hot-path-performance-multi-file-loop/02-01-PINVOKE-PIN.md` exists.
    - File contains the literal strings `WTD_REVOCATION_CHECK_NONE` and `0x00000010` (or `0x10`) on the same logical line.
    - File contains `WTD_CACHE_ONLY_URL_RETRIEVAL` and `0x00001000` (or `0x1000`).
    - File contains `WTD_REVOKE_NONE` and a value of `0` for `fdwRevocationChecks`.
    - File contains GUID `00AAC56B-CD44-11D0-8CC2-00C04FC295EE`.
    - File mentions `WTD_DISABLE_MD2_MD4` in a forbidden-flag context (grep returns ≥1 match).
    - File cites at least one canonical source URL (learn.microsoft.com/wintrust, pinvoke.net, or wintrust.h SDK reference).
    - HRESULT table includes all 8 mappings: `S_OK`, `TRUST_E_NOSIGNATURE` (0x800B0100), `TRUST_E_BAD_DIGEST` (0x80096010), `TRUST_E_EXPLICIT_DISTRUST` (0x800B0111), `CERT_E_EXPIRED` (0x800B0101), `CERT_E_REVOKED` (0x80092010), `CERT_E_UNTRUSTEDROOT` (0x800B0109), `CERT_E_CHAINING` (0x800B010A).
  </acceptance_criteria>
  <done>02-01-PINVOKE-PIN.md committed; Task 2 has zero ambiguity about struct layout, flag names+values, action GUID, and HRESULT mapping.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 1 (Wave 0 RED): Create failing tests + module skeleton + binary fixtures</name>
  <read_first>
    - VeriHash.Core/VeriHash.Core.psd1 (analog manifest — copy verbatim, change 4 fields)
    - VeriHash.Core/VeriHash.Core.psm1 (analog loader — copy verbatim)
    - Tests/VeriHash.Core.Module.Tests.ps1 (analog for VeriHash.HotPath.Tests.ps1)
    - Tests/VeriHash.Core.Get-VeriHashResult.Tests.ps1 (analog for fixture-file pattern)
    - Tests/VeriHash.Core.Read-ClipboardHash.Tests.ps1 (analog for Mock pattern)
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-PATTERNS.md (lines 33-86 manifest+loader excerpts; lines 348-420 test patterns; lines 474-481 fixture content)
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-VALIDATION.md (Wave 0 Requirements list)
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-RESEARCH.md (lines 410-414 Pitfall 8 — Mock cannot cross ThreadJob runspaces, so Sig tests run synchronously)
  </read_first>
  <behavior>
    All test files MUST exist and MUST FAIL on first run (no production code yet). After Task 2, they must turn GREEN. Tests cover:
    - Module sanity (import succeeds, exports list, manifest pins PowerShellVersion 7.0 + CompatiblePSEditions Core, re-import-with-Force does not throw).
    - PE-detect: `Test-IsPEFile` against tiny-pe.bin → $true; against tiny-not-pe.bin → $false; against $null/missing/directory path → $false (no throw).
    - Cross-platform: on non-Windows, Get-VeriHashSignature returns Status='skipped', Reason='not supported on this platform', and Invoke-WinVerifyTrust is NEVER called (assert via Mock with -Times 0).
    - PERF-02 flag lock: Get-VeriHashSignature on Windows with -IsPE invokes Invoke-WinVerifyTrust exactly once (Mock returns 0 = S_OK); test asserts Get-VeriHashSignature returned Status='valid'.
    - Forbidden-flag grep: zero occurrences of `WTD_DISABLE_MD2_MD4` anywhere in `VeriHash.HotPath/`.
    - HRESULT mapping: ConvertFrom-WinTrustHResult invoked with each of the 8 HRESULTs from PINVOKE-PIN.md returns the Status enum value listed in the Pitfall 3 table; unknown HRESULT 0xDEADBEEF returns Status='error', Reason='0xDEADBEEF'.
  </behavior>
  <action>
**(a) Module skeleton stubs.** Create the 6 production-code files as EMPTY stubs (function declared, body just `throw 'NOT YET IMPLEMENTED'`):
  - `VeriHash.HotPath/VeriHash.HotPath.psd1` — copy from `VeriHash.Core/VeriHash.Core.psd1`, change ONLY:
      `RootModule = 'VeriHash.HotPath.psm1'`
      `GUID = '<run [guid]::NewGuid() and paste>'`
      `Description = 'Hot-path orchestration: PE-detect, parallel hash+Authenticode, multi-file batch with tally.'`
      `FunctionsToExport = 'Get-VeriHashSignature'`   (more added in Plans 02 + 03)
    Keep `ModuleVersion = '2.0.0'`, `CompatiblePSEditions = 'Core'`, `PowerShellVersion = '7.0'`, `Author`, `CompanyName`, `Copyright` identical to the analog.
  - `VeriHash.HotPath/VeriHash.HotPath.psm1` — copy `VeriHash.Core/VeriHash.Core.psm1` VERBATIM (the dot-source loader is path-relative and already correct).
  - `VeriHash.HotPath/Public/Get-VeriHashSignature.ps1` — function declared with `[CmdletBinding()] [OutputType([pscustomobject])] param([Parameter(Mandatory)][string]$Path,[switch]$IsPE)`, body `throw 'NOT YET IMPLEMENTED'`.
  - `VeriHash.HotPath/Private/Test-IsPEFile.ps1` — function declared with `[CmdletBinding()] [OutputType([bool])] param([Parameter(Mandatory)][string]$Path)`, body `throw 'NOT YET IMPLEMENTED'`.
  - `VeriHash.HotPath/Private/Invoke-WinVerifyTrust.ps1` — function declared with `[CmdletBinding()] [OutputType([int])] param([Parameter(Mandatory)][string]$Path)`, body `throw 'NOT YET IMPLEMENTED'`.
  - `VeriHash.HotPath/Private/ConvertFrom-WinTrustHResult.ps1` — function declared with `[CmdletBinding()] [OutputType([pscustomobject])] param([Parameter(Mandatory)][int]$HResult)`, body `throw 'NOT YET IMPLEMENTED'`.

**(b) Binary fixtures (committed).**
  - `Tests/Fixtures/tiny-pe.bin` — minimum 64 bytes starting with `0x4D 0x5A` (`MZ`). Use a small DOS-stub PE skeleton; document creation in a comment in the .ps1 test that loads it. Generate with PowerShell, e.g.: `[byte[]]$b = @(0x4D,0x5A) + (1..62 | %{[byte](Get-Random -Min 0 -Max 256)}); [IO.File]::WriteAllBytes(...)`. Commit the resulting bytes.
  - `Tests/Fixtures/tiny-not-pe.bin` — 64 bytes whose first two are NOT `0x4D 0x5A`. Suggest: ASCII `not a pe file - VeriHash test fixture\n` padded to 64 bytes.

**(c) Failing test files.**

`Tests/VeriHash.HotPath.Tests.ps1` (module sanity — mirror `Tests/VeriHash.Core.Module.Tests.ps1` analog lines 1–30 verbatim, swap module name):
```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
}
AfterAll  { Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue }

Describe 'VeriHash.HotPath module manifest + exports (Plan 01 surface)' {
    It 'Imports cleanly' { { Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force } | Should -Not -Throw }
    It 'Re-imports with -Force without "type already defined"' {
        { 1..2 | ForEach-Object { Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force } } | Should -Not -Throw
    }
    It 'Exports Get-VeriHashSignature' {
        (Get-Command -Module VeriHash.HotPath).Name | Should -Contain 'Get-VeriHashSignature'
    }
    It 'Manifest pins PowerShellVersion 7.0 and CompatiblePSEditions Core' {
        $m = Test-ModuleManifest "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1"
        $m.PowerShellVersion | Should -Be ([version]'7.0')
        $m.CompatiblePSEditions | Should -Contain 'Core'
    }
    It 'No PSFramework references in VeriHash.HotPath/' {
        (Select-String -Path "$PSScriptRoot/../VeriHash.HotPath/*","$PSScriptRoot/../VeriHash.HotPath/**/*" -Pattern 'PSFramework|Write-PSFMessage' -ErrorAction SilentlyContinue) | Should -BeNullOrEmpty
    }
    It 'No forbidden WTD_DISABLE_MD2_MD4 flag in VeriHash.HotPath/' {
        (Select-String -Path "$PSScriptRoot/../VeriHash.HotPath/*","$PSScriptRoot/../VeriHash.HotPath/**/*" -Pattern 'WTD_DISABLE_MD2_MD4' -ErrorAction SilentlyContinue) | Should -BeNullOrEmpty
    }
}
```

`Tests/VeriHash.HotPath.PE.Tests.ps1` (PE-detect — mirror `Tests/VeriHash.Core.Get-VeriHashResult.Tests.ps1` fixture pattern):
```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
    $script:PEFixture    = Join-Path $PSScriptRoot 'Fixtures/tiny-pe.bin'
    $script:NotPEFixture = Join-Path $PSScriptRoot 'Fixtures/tiny-not-pe.bin'
}
AfterAll { Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue }

Describe 'Test-IsPEFile (PERF-01: content-based PE detection)' {
    It 'Returns $true for a file whose first two bytes are MZ' {
        InModuleScope VeriHash.HotPath { Test-IsPEFile -Path $using:PEFixture } | Should -BeTrue
    }
    It 'Returns $false for a file whose first two bytes are not MZ' {
        InModuleScope VeriHash.HotPath { Test-IsPEFile -Path $using:NotPEFixture } | Should -BeFalse
    }
    It 'Returns $false (no throw) for a missing file' {
        $missing = Join-Path $TestDrive 'does-not-exist.bin'
        InModuleScope VeriHash.HotPath { Test-IsPEFile -Path $using:missing } | Should -BeFalse
    }
    It 'Returns $false (no throw) for a directory path' {
        InModuleScope VeriHash.HotPath { Test-IsPEFile -Path $using:TestDrive } | Should -BeFalse
    }
    It 'Returns $false for a 1-byte file (smaller than MZ)' {
        $oneByte = Join-Path $TestDrive 'one-byte.bin'; [IO.File]::WriteAllBytes($oneByte, [byte[]](0x4D))
        InModuleScope VeriHash.HotPath { Test-IsPEFile -Path $using:oneByte } | Should -BeFalse
    }
}
```

`Tests/VeriHash.HotPath.Sig.Tests.ps1` (signature wrapper + flag-lock + HRESULT mapping — note Pitfall 8: tests are SYNCHRONOUS, never inside ThreadJob):
```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
    $script:PEFixture = Join-Path $PSScriptRoot 'Fixtures/tiny-pe.bin'
}
AfterAll { Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue }

Describe 'Get-VeriHashSignature platform gate (D-A1-1)' {
    It 'On non-Windows returns Status=skipped, Reason=not supported on this platform; never P/Invokes' -Skip:($IsWindows) {
        InModuleScope VeriHash.HotPath {
            Mock Invoke-WinVerifyTrust { return 0 }
            $r = Get-VeriHashSignature -Path $using:PEFixture -IsPE
            $r.Status | Should -Be 'skipped'
            $r.Reason | Should -Be 'not supported on this platform'
            Should -Invoke Invoke-WinVerifyTrust -Times 0
        }
    }
}

Describe 'Get-VeriHashSignature non-PE handling (PERF-01)' {
    It 'Returns Status=skipped, Reason="not a PE file" when -IsPE is $false' -Skip:(-not $IsWindows) {
        InModuleScope VeriHash.HotPath {
            Mock Invoke-WinVerifyTrust { return 0 }
            $r = Get-VeriHashSignature -Path $using:PEFixture        # no -IsPE
            $r.Status | Should -Be 'skipped'
            $r.Reason | Should -Be 'not a PE file'
            Should -Invoke Invoke-WinVerifyTrust -Times 0
        }
    }
}

Describe 'Get-VeriHashSignature HRESULT → Status (PERF-02)' -Skip:(-not $IsWindows) {
    It 'S_OK (0) → valid'                                  { InModuleScope VeriHash.HotPath { Mock Invoke-WinVerifyTrust { return 0 };          (Get-VeriHashSignature -Path $using:PEFixture -IsPE).Status | Should -Be 'valid' } }
    It 'TRUST_E_NOSIGNATURE (0x800B0100) → unsigned'        { InModuleScope VeriHash.HotPath { Mock Invoke-WinVerifyTrust { return -2146762496 };(Get-VeriHashSignature -Path $using:PEFixture -IsPE).Status | Should -Be 'unsigned' } }
    It 'TRUST_E_BAD_DIGEST (0x80096010) → invalid'         { InModuleScope VeriHash.HotPath { Mock Invoke-WinVerifyTrust { return -2146869232 };(Get-VeriHashSignature -Path $using:PEFixture -IsPE).Status | Should -Be 'invalid' } }
    It 'CERT_E_EXPIRED (0x800B0101) → invalid'             { InModuleScope VeriHash.HotPath { Mock Invoke-WinVerifyTrust { return -2146762495 };(Get-VeriHashSignature -Path $using:PEFixture -IsPE).Status | Should -Be 'invalid' } }
    It 'CERT_E_UNTRUSTEDROOT (0x800B0109) → invalid'       { InModuleScope VeriHash.HotPath { Mock Invoke-WinVerifyTrust { return -2146762487 };(Get-VeriHashSignature -Path $using:PEFixture -IsPE).Status | Should -Be 'invalid' } }
    It 'Unknown HRESULT (0xDEADBEEF) → error with hex Reason' {
        InModuleScope VeriHash.HotPath {
            Mock Invoke-WinVerifyTrust { return -559038737 }   # 0xDEADBEEF as int32
            $r = Get-VeriHashSignature -Path $using:PEFixture -IsPE
            $r.Status | Should -Be 'error'
            $r.Reason | Should -Match '0xDEADBEEF'
        }
    }
}
```

The above tests reference `$using:` for variable capture inside `InModuleScope` script blocks. Verify the executor uses Pester 5.x compatible scoping; if `$using:` doesn't propagate inside `InModuleScope`, fall back to `$script:` variables set in `BeforeAll`.

Run the three test files with `Invoke-Pester` and confirm ALL THREE FAIL or have failing tests (RED) — module loads (psd1 valid, psm1 dot-sources stubs) but every behavioral It block fails because the function bodies throw `'NOT YET IMPLEMENTED'`.
  </action>
  <verify>
    <automated>Import-Module .\VeriHash.HotPath\VeriHash.HotPath.psd1 -Force; Get-Command -Module VeriHash.HotPath; Test-Path Tests/Fixtures/tiny-pe.bin,Tests/Fixtures/tiny-not-pe.bin; pwsh -NoProfile -Command "Invoke-Pester -Path Tests/VeriHash.HotPath.Tests.ps1,Tests/VeriHash.HotPath.PE.Tests.ps1,Tests/VeriHash.HotPath.Sig.Tests.ps1 -Output Detailed -PassThru | ForEach-Object { if ($_.FailedCount -lt 1) { throw 'EXPECTED RED — at least one test must fail in Wave 0' } }"</automated>
  </verify>
  <acceptance_criteria>
    - All 6 production stub files exist; each function throws `'NOT YET IMPLEMENTED'` when invoked.
    - `Test-ModuleManifest VeriHash.HotPath/VeriHash.HotPath.psd1` succeeds and reports `ModuleVersion 2.0.0`, `PowerShellVersion 7.0`, `CompatiblePSEditions = Core`.
    - `Get-Command -Module VeriHash.HotPath` lists exactly `Get-VeriHashSignature`.
    - Both fixture binaries exist, are at least 2 bytes; `[IO.File]::ReadAllBytes('Tests/Fixtures/tiny-pe.bin')[0..1]` equals `@(0x4D, 0x5A)`; `Tests/Fixtures/tiny-not-pe.bin`'s first two bytes are NOT `0x4D 0x5A`.
    - The three test files exist (Tests/VeriHash.HotPath.Tests.ps1, .PE.Tests.ps1, .Sig.Tests.ps1).
    - Running the three test files with `Invoke-Pester` produces `FailedCount >= 1` (RED state proves tests are real — they exercise the unimplemented behavior).
    - `Select-String -Path VeriHash.HotPath -Pattern 'WTD_DISABLE_MD2_MD4' -Recurse` returns ZERO matches.
    - `Select-String -Path VeriHash.HotPath -Pattern 'PSFramework|Write-PSFMessage' -Recurse` returns ZERO matches.
    - `Select-String -Path VeriHash.HotPath -Pattern '\$IsWindows|\$RunningOnWindows' -Recurse` returns ZERO matches (carried-forward: only Get-VeriHashPlatform).
  </acceptance_criteria>
  <done>Module skeleton + fixtures + 3 RED test files committed. The next task turns them GREEN by implementing the function bodies.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2 (GREEN): Implement Test-IsPEFile, Invoke-WinVerifyTrust shim, ConvertFrom-WinTrustHResult, Get-VeriHashSignature</name>
  <read_first>
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-01-PINVOKE-PIN.md (CREATED in Task 0 — the canonical struct/flag/HRESULT source)
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-PATTERNS.md (lines 285-345 Test-IsPEFile + Invoke-WinVerifyTrust patterns; lines 248-282 Get-VeriHashSignature pattern)
    - .planning/phases/02-hot-path-performance-multi-file-loop/02-RESEARCH.md (lines 386-389 Pitfall 4 STATEACTION_VERIFY/CLOSE pairing; lines 416-420 Pitfall 9 Add-Type race)
    - VeriHash.HotPath/Private/Test-IsPEFile.ps1 (current stub)
    - VeriHash.HotPath/Private/Invoke-WinVerifyTrust.ps1 (current stub)
    - VeriHash.HotPath/Private/ConvertFrom-WinTrustHResult.ps1 (current stub)
    - VeriHash.HotPath/Public/Get-VeriHashSignature.ps1 (current stub)
    - VeriHash.Core/Public/Get-VeriHashPlatform.ps1 (platform gate to call)
    - VeriHash.Core/Public/Read-ClipboardHash.ps1 (pattern for platform-gated public function)
    - Tests/VeriHash.HotPath.Tests.ps1 + .PE.Tests.ps1 + .Sig.Tests.ps1 (the RED tests this task must turn GREEN — DO NOT modify them per copilot-instructions TDD rule)
  </read_first>
  <action>
**(a) `VeriHash.HotPath/Private/Test-IsPEFile.ps1` — replace stub with verbatim implementation from PATTERNS.md lines 290-306:**

```powershell
function Test-IsPEFile {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string]$Path)
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            $buf  = [byte[]]::new(2)
            $read = $stream.Read($buf, 0, 2)
            return ($read -eq 2 -and $buf[0] -eq 0x4D -and $buf[1] -eq 0x5A)
        } finally { $stream.Dispose() }
    } catch {
        return $false   # any I/O error (missing, dir, broken symlink, ACL) → not-PE
    }
}
```

**(b) `VeriHash.HotPath/Private/Invoke-WinVerifyTrust.ps1` — implement using struct layout COPIED VERBATIM from `02-01-PINVOKE-PIN.md`. Required pieces (do not invent):**

1. **Re-import guard** wrapping the Add-Type call: `if (-not ('VeriHash.WinTrust' -as [type])) { Add-Type -TypeDefinition @' ... '@ }`
2. **C# definitions copied from PINVOKE-PIN.md Sections 1+2** for `WINTRUST_FILE_INFO` and `WINTRUST_DATA` (both with `[StructLayout(LayoutKind.Sequential)]`) and the `WinTrust` static class with `[DllImport("wintrust.dll", CharSet=CharSet.Unicode, SetLastError=false)] public static extern int WinVerifyTrust(IntPtr hwnd, [In] ref Guid pgActionID, [In] ref WINTRUST_DATA pWVTData)`.
3. **Action GUID:** `$actionGuid = [guid]'00AAC56B-CD44-11D0-8CC2-00C04FC295EE'   # WINTRUST_ACTION_GENERIC_VERIFY_V2`
4. **Build WINTRUST_FILE_INFO + WINTRUST_DATA on the managed heap with these EXACT field values** (per PINVOKE-PIN.md Section 4):
   - `WINTRUST_FILE_INFO.cbStruct = [System.Runtime.InteropServices.Marshal]::SizeOf([type][VeriHash.WINTRUST_FILE_INFO])`
   - `WINTRUST_FILE_INFO.pcwszFilePath = $Path`; `hFile = [IntPtr]::Zero`; `pgKnownSubject = [IntPtr]::Zero`
   - Allocate unmanaged buffer with `Marshal.AllocHGlobal` and `Marshal.StructureToPtr(...)` for the file-info, store ptr in `WINTRUST_DATA.pFile`.
   - `WINTRUST_DATA.cbStruct = Marshal.SizeOf([type][VeriHash.WINTRUST_DATA])`
   - `WINTRUST_DATA.dwUIChoice = 2`             (WTD_UI_NONE)
   - `WINTRUST_DATA.fdwRevocationChecks = 0`    (WTD_REVOKE_NONE — disables CRL on the revocation-check axis)
   - `WINTRUST_DATA.dwUnionChoice = 1`          (WTD_CHOICE_FILE)
   - `WINTRUST_DATA.dwStateAction = 1`          (WTD_STATEACTION_VERIFY)
   - `WINTRUST_DATA.dwProvFlags = 0x00000010 -bor 0x00001000`   (WTD_REVOCATION_CHECK_NONE | WTD_CACHE_ONLY_URL_RETRIEVAL — the PERF-02 contract)
   - `WINTRUST_DATA.pPolicyCallbackData = pSIPClientData = hWVTStateData = pSignatureSettings = [IntPtr]::Zero`
   - `WINTRUST_DATA.pwszURLReference = $null`; `dwUIContext = 0`
5. **Call sequence wrapped in `try { VERIFY } finally { CLOSE + free }`** per Pitfall 4:
   ```powershell
   try {
       $hresult = [VeriHash.WinTrust]::WinVerifyTrust([IntPtr]::Zero, [ref]$actionGuid, [ref]$wtd)
       return [int]$hresult
   } finally {
       # MUST call CLOSE so Windows frees hWVTStateData
       $wtd.dwStateAction = 2     # WTD_STATEACTION_CLOSE
       [void][VeriHash.WinTrust]::WinVerifyTrust([IntPtr]::Zero, [ref]$actionGuid, [ref]$wtd)
       if ($filePtr -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::FreeHGlobal($filePtr) }
   }
   ```
6. **Defensive platform guard at top:** `if ((Get-VeriHashPlatform) -ne 'Windows') { throw 'Invoke-WinVerifyTrust is Windows-only' }` — Get-VeriHashSignature must filter first; this is belt-and-suspenders.

**(c) `VeriHash.HotPath/Private/ConvertFrom-WinTrustHResult.ps1` — implement using the 8-row table from PINVOKE-PIN.md Section 6 / RESEARCH.md Pitfall 3. Use signed int32 representations (PowerShell receives the HRESULT as int):**

```powershell
function ConvertFrom-WinTrustHResult {
    [CmdletBinding()] [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][int]$HResult)
    $hex = '0x{0:X8}' -f ([uint32]$HResult)
    switch ($HResult) {
        0           { return [pscustomobject]@{ Status='valid';    Reason='' } }
        -2146762496 { return [pscustomobject]@{ Status='unsigned'; Reason='not signed' } }              # 0x800B0100 TRUST_E_NOSIGNATURE
        -2146869232 { return [pscustomobject]@{ Status='invalid';  Reason='bad digest' } }              # 0x80096010 TRUST_E_BAD_DIGEST
        -2146762479 { return [pscustomobject]@{ Status='invalid';  Reason='explicit distrust' } }       # 0x800B0111 TRUST_E_EXPLICIT_DISTRUST
        -2146762495 { return [pscustomobject]@{ Status='invalid';  Reason='cert expired' } }            # 0x800B0101 CERT_E_EXPIRED
        -2146885616 { return [pscustomobject]@{ Status='invalid';  Reason='cert revoked' } }            # 0x80092010 CERT_E_REVOKED
        -2146762487 { return [pscustomobject]@{ Status='invalid';  Reason='untrusted root' } }          # 0x800B0109 CERT_E_UNTRUSTEDROOT
        -2146762486 { return [pscustomobject]@{ Status='invalid';  Reason='chain build failed' } }      # 0x800B010A CERT_E_CHAINING
        default     { return [pscustomobject]@{ Status='error';    Reason=$hex } }
    }
}
```

VERIFY each int constant by computing `[int]([uint32]0x800B0100)` etc. in pwsh before committing — sign conversion is the most common bug here.

**(d) `VeriHash.HotPath/Public/Get-VeriHashSignature.ps1` — implement per PATTERNS.md lines 252-279:**

```powershell
function Get-VeriHashSignature {
    <#
    .SYNOPSIS
        Returns Authenticode signature status for a file via WinVerifyTrust (Windows) or skipped elsewhere.
    .DESCRIPTION
        On Windows, calls Invoke-WinVerifyTrust with WTD_REVOCATION_CHECK_NONE | WTD_CACHE_ONLY_URL_RETRIEVAL
        (no network CRL — PERF-02), maps the HRESULT via ConvertFrom-WinTrustHResult, and returns
        a {Status, Reason} object. On non-Windows, returns Status='skipped' without P/Invoking.
    .PARAMETER Path
        Absolute or resolvable path to the file to verify.
    .PARAMETER IsPE
        Pre-computed PE-detect result; when $false, returns Status='skipped', Reason='not a PE file'
        without P/Invoking. The caller (Invoke-VeriHashHotPath) runs Test-IsPEFile once on the main
        thread and passes the result here so the sig ThreadJob doesn't re-open the file.
    .OUTPUTS
        [pscustomobject] @{ Status; Reason } -- Status in valid|invalid|unsigned|skipped|error
    #>
    [CmdletBinding()] [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [switch] $IsPE
    )
    if ((Get-VeriHashPlatform) -ne 'Windows') {
        return [pscustomobject]@{ Status='skipped'; Reason='not supported on this platform' }
    }
    if (-not $IsPE) {
        return [pscustomobject]@{ Status='skipped'; Reason='not a PE file' }
    }
    $hresult = Invoke-WinVerifyTrust -Path $Path
    return ConvertFrom-WinTrustHResult -HResult $hresult
}
```

**(e) Run all three test files. Confirm GREEN:**
```powershell
Invoke-Pester -Path Tests/VeriHash.HotPath.Tests.ps1,Tests/VeriHash.HotPath.PE.Tests.ps1,Tests/VeriHash.HotPath.Sig.Tests.ps1 -Output Detailed
```

If any test fails, fix the CODE — do NOT modify the test (copilot-instructions TDD rule).
  </action>
  <verify>
    <automated>pwsh -NoProfile -Command "$r = Invoke-Pester -Path Tests/VeriHash.HotPath.Tests.ps1,Tests/VeriHash.HotPath.PE.Tests.ps1,Tests/VeriHash.HotPath.Sig.Tests.ps1 -Output Detailed -PassThru; if ($r.FailedCount -gt 0) { throw \"GREEN gate failed: $($r.FailedCount) tests failed\" }; if ($r.PassedCount -lt 10) { throw \"Too few tests ran ($($r.PassedCount)) — RED tests from Task 1 may not all be present\" }"; Select-String -Path VeriHash.HotPath -Pattern 'WTD_DISABLE_MD2_MD4' -Recurse; Invoke-ScriptAnalyzer -Path VeriHash.HotPath -Recurse -Settings PSScriptAnalyzerSettings.psd1</automated>
  </verify>
  <acceptance_criteria>
    - All tests in Tests/VeriHash.HotPath.Tests.ps1, Tests/VeriHash.HotPath.PE.Tests.ps1, Tests/VeriHash.HotPath.Sig.Tests.ps1 pass (`Invoke-Pester ... -PassThru` reports `FailedCount = 0` and `PassedCount >= 10`).
    - The test files have NOT been modified since Task 1 (TDD rule). `git diff` between Task 1 commit and Task 2 commit shows ZERO changes under `Tests/VeriHash.HotPath.*Tests.ps1`.
    - `Select-String -Path VeriHash.HotPath -Pattern 'WTD_DISABLE_MD2_MD4' -Recurse` returns 0 matches.
    - `Select-String -Path VeriHash.HotPath -Pattern '0x00000010|0x10\b' VeriHash.HotPath/Private/Invoke-WinVerifyTrust.ps1` returns ≥1 match (WTD_REVOCATION_CHECK_NONE flag present).
    - `Select-String -Path VeriHash.HotPath/Private/Invoke-WinVerifyTrust.ps1 -Pattern '0x00001000|0x1000\b'` returns ≥1 match (WTD_CACHE_ONLY_URL_RETRIEVAL flag present).
    - `Select-String -Path VeriHash.HotPath/Private/Invoke-WinVerifyTrust.ps1 -Pattern 'WTD_STATEACTION_CLOSE|dwStateAction\s*=\s*2'` returns ≥1 match (handle leak prevented per Pitfall 4).
    - `Select-String -Path VeriHash.HotPath/Private/Invoke-WinVerifyTrust.ps1 -Pattern "if \(-not \('VeriHash\.WinTrust' -as \[type\]\)\)"` returns ≥1 match (Add-Type re-import guard present per Pitfall 9).
    - `Invoke-ScriptAnalyzer -Path VeriHash.HotPath -Recurse -Settings PSScriptAnalyzerSettings.psd1` returns 0 errors (warnings allowed if matching repo's existing baseline).
    - `Get-Command -Module VeriHash.HotPath` returns exactly `Get-VeriHashSignature` (no extra accidental exports).
  </acceptance_criteria>
  <done>PERF-01 (PE-only sig) + PERF-02 (no network CRL) closed. Get-VeriHashSignature is the consumable surface for Plan 02's hot-path orchestrator.</done>
</task>

</tasks>

<verification>
Plan-level gate (run before declaring complete):

```powershell
# 1. Lint
Invoke-ScriptAnalyzer -Path VeriHash.HotPath -Recurse -Settings PSScriptAnalyzerSettings.psd1

# 2. Tests
Invoke-Pester -Path Tests/VeriHash.HotPath.Tests.ps1,Tests/VeriHash.HotPath.PE.Tests.ps1,Tests/VeriHash.HotPath.Sig.Tests.ps1 -Output Detailed

# 3. Forbidden-flag + PSFramework + redundant platform check audit
Select-String -Path VeriHash.HotPath -Pattern 'WTD_DISABLE_MD2_MD4|PSFramework|Write-PSFMessage|\$IsWindows|\$RunningOnWindows' -Recurse
# Expect: zero matches

# 4. Cross-platform smoke (run on Linux runner / WSL)
Import-Module ./VeriHash.HotPath/VeriHash.HotPath.psd1 -Force
(Get-VeriHashSignature -Path /etc/hostname -IsPE).Status   # Expect: 'skipped'
```
</verification>

<success_criteria>
- 3 Pester test files green (FailedCount=0).
- VeriHash.HotPath module imports cleanly on Windows + Linux + macOS.
- PERF-01 and PERF-02 success-criterion tests pass per the Behavior → Test map in 02-RESEARCH.md.
- Zero PSFramework / forbidden-flag / redundant-platform-check matches in `VeriHash.HotPath/`.
- 02-01-PINVOKE-PIN.md committed and serves as the canonical struct/flag/HRESULT reference for any future revisitation.
</success_criteria>

<output>
After completion, create `.planning/phases/02-hot-path-performance-multi-file-loop/02-01-SUMMARY.md` with:
- Files added/modified
- Test counts (passed/failed/skipped)
- HRESULT mapping table (copy from PINVOKE-PIN.md Section 6 — for downstream consumers)
- Confirmation that PERF-01 + PERF-02 success criteria are met
- Open follow-ups for Plan 02 (consumes Get-VeriHashSignature inside the sig ThreadJob)
</output>
