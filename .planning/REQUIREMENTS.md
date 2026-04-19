# Requirements — Milestone v2.0 Modular Rebuild

**Status:** Active
**Defined:** 2026-04-18
**Total:** 38 requirements across 8 categories

---

## v2.0 Requirements

### Core Module (CORE)

- [x] **CORE-01**: A `VeriHash.Core` PowerShell module (`VeriHash.Core.psd1` + `VeriHash.Core.psm1`) is importable via `Import-Module`; tests load it with `Import-Module` instead of the dot-source-with-dummy-path hack used in v1.
- [x] **CORE-02**: User can compute MD5/SHA256/SHA512 of any file via `Get-VeriHashResult -Path <file>` which returns a result object containing file path, size, algorithm, hash, and elapsed milliseconds.
- [x] **CORE-03**: `Read-ClipboardHash` auto-detects a hash on the user's clipboard in plain-hex form, inferring algorithm from length (32 → MD5, 64 → SHA256, 128 → SHA512).
- [x] **CORE-04**: `Read-ClipboardHash` also recognizes the `<algorithm>:<hex>` prefix form (e.g., `sha256:71792c…`, `md5:abc…`, `sha512:def…`); the explicit prefix overrides length-based inference and lets us trust the user-stated algorithm.
- [x] **CORE-05**: User can verify a file against a sibling sidecar file (`.sha256` / `.sha512` / `.md5`); existing v1.x GNU-format sidecars (`HASH  filename` and `HASH *filename`) continue to verify without modification.
- [x] **CORE-06**: `Format-VeriHashReport` prints filename, size (MB + bytes), algorithm, hash, comparison result (clipboard / sidecar match or mismatch), and elapsed time in the current Write-Host block style; output remains visually compatible with v1.
- [x] **CORE-07**: A built-in plain-text logger (`Write-VeriHashLog`) appends one line per invocation to `~/.verihash/verihash.log` only when the `-Log` flag is passed or `$env:VERIHASH_LOG=1` is set. No external dependency, no rotation, no parser.
- [x] **CORE-08**: Platform detection (Windows / Linux / macOS) is defined exactly once in Core and exported; the duplicate definitions in `VeriHash.Config.ps1` and the per-function re-declarations in `VeriHash.LogUtils.ps1` are eliminated.

### Hot-Path Performance (PERF)

- [x] **PERF-01**: Authenticode signature check is skipped for files whose first two bytes are not `MZ` (i.e., not a Portable Executable). The skipped state is shown clearly in output (`Signature: skipped (not a PE file)`).
- [x] **PERF-02**: Authenticode signature check disables network CRL lookups so unsigned or self-signed files don't pay a network round-trip on every invocation.
- [x] **PERF-03**: For PE files, hash computation and signature verification run in parallel via `Start-ThreadJob`; total wall-clock time is the slower of the two, not the sum.
- [x] **PERF-04**: The output streams progressively — hash result is printed immediately when the hash job completes; signature line appears appended once the signature job completes. The user sees the hash without waiting on signing.
- [x] **PERF-05**: Displayed elapsed time reflects wall-clock duration of the entire invocation, not summed sub-task times.

### Multi-File Loop Mode (MULTI)

- [x] **MULTI-01**: The thin CLI accepts a `[string[]] $FilePath` parameter; Explorer's SendTo passes multiple files in a single invocation.
- [x] **MULTI-02**: When more than one file is passed, output renders one full result block per file followed by a final tally row (e.g., `3/4 matched, 1 mismatch, 0 missing`).
- [x] **MULTI-03**: Loop mode preserves all hot-path features per-file (clipboard compare, sidecar compare, parallel signature for PE files).

### Manifest Mode (MANIFEST)

- [x] **MANIFEST-01**: `New-VeriHashManifest -Path <files...>` creates a GNU `sha256sum`-compatible manifest file in the common parent directory of the inputs using an atomic temp→rename pattern (no partial manifests on Ctrl+C or error).
- [x] **MANIFEST-02**: All inputs must share a single common parent directory; mixed-root inputs produce a clear error (`Selected files span multiple directories. Manifests use relative paths — select files under one root.`).
- [x] **MANIFEST-03**: Files with hash extensions (`.sha256`, `.sha512`, `.sha384`, `.sha1`, `.md5`, `.sha2`, `.sha2_256`) are silently filtered from manifest inputs — you can't hash metadata as content.
- [x] **MANIFEST-04**: `Test-VeriHashManifest -Path <manifest>` parses each line with strict regex (`^([0-9a-fA-F]{hashlen})[ ](\*| )(.+)$`); malformed lines are reported and the run exits with code 3.
- [x] **MANIFEST-05**: Manifest verify resolves each entry relative to the manifest file's directory (not CWD) and rejects any entry whose resolved path escapes that directory (path-traversal guard, hard reject not warning).
- [x] **MANIFEST-06**: Manifest verify exit codes are machine-readable: `0` = all pass, `1` = at least one hash mismatch, `2` = at least one missing/unreadable file (no mismatches), `3` = manifest parse error.
- [x] **MANIFEST-07**: A second SendTo entry (`VeriHash - Manifest.lnk`) installs alongside the regular entry when `-InstallSendTo` runs; right-clicking N files and choosing it creates a manifest, right-clicking a manifest and choosing it verifies.
- [x] **MANIFEST-08**: Manifest output passes `sha256sum -c <manifest>` round-trip on Linux/WSL (Pester test marked Skip when no WSL is detected).

### Integrations (INTEG)

- [x] **INTEG-01**: `VeriHash.Integrations.ps1` is dot-sourced lazily, only when an integration command (`-InstallSendTo`, `-InstallKDE`) is invoked. The hot path does not load it.
- [x] **INTEG-02**: Windows `-InstallSendTo` installs both `VeriHash.lnk` and `VeriHash - Manifest.lnk` in the user's SendTo folder; system-wide install requires elevation (no auto-elevation).
- [x] **INTEG-03**: Linux KDE service-menu installation behavior is preserved from v1 (user-level and `--SystemWide` with root check).

### Config Trim (CFG)

- [x] **CFG-01**: All `virustotal.*` fields, defaults, and `VERIHASH_VT_*` environment variable handling are removed from `VeriHash.Config.ps1`.
- [x] **CFG-02**: All references to VirusTotal in `Tests/VeriHash.Config.Tests.ps1` are removed.
- [x] **CFG-03**: PSFramework is no longer referenced anywhere in production source or tests; the ~33 `if ($script:PSFrameworkAvailable)` guard sites are eliminated along with the optional dependency.

### Thin CLI Dispatcher (CLI)

- [x] **CLI-01**: The new `VeriHash.ps1` is a thin dispatcher (target ≤ ~200 lines): it parses parameters, imports the appropriate module(s), calls the entry function, renders output via `Format-VeriHashReport`, and pauses if interactive.
- [x] **CLI-02**: Pause-at-end behavior (and the `-NoPause` override) is centralized in the CLI; modules do not check `-NoPause` themselves.
- [x] **CLI-03**: A new `Tests/VeriHash.Cli.Tests.ps1` covers the locked v2 contract end-to-end: single-file hash, clipboard match (plain + prefixed forms), sidecar match, sidecar mismatch resolution, multi-file loop, manifest create, manifest verify (pass + fail + missing).

### Cleanup & Docs (CLEAN)

- [x] **CLEAN-01**: `QuickHash.ps1` and `Tests/QuickHash.Tests.ps1` are deleted from the repo.
- [x] **CLEAN-02**: `VeriHash.LogUtils.ps1` and `Tests/VeriHash.LogUtils.Tests.ps1` are deleted from the repo.
- [x] **CLEAN-03**: README is rewritten to document the v2 architecture (modules + thin CLI), the new CLI surface (breaking changes called out), and the simplified install path (no PSFramework needed).
- [x] **CLEAN-04**: CHANGELOG includes a v2.0 entry listing all removals (VT, PSFramework, QuickHash, LogUtils), additions (manifest mode, multi-file loop, prefixed clipboard parsing), and breaking CLI changes.
- [x] **CLEAN-05**: The three concepting markdown files at the repo root (`Verihash Multifile Concepting.md`, `Verihash Multifile Concepting Review.md`, `Verihash Logging Concepting.md`) are moved to `.planning/archive/` — they served their purpose.

---

## Future Requirements (Deferred)

- **Recursive folder hashing for manifests** — Manifest MVP is flat-files-only; recursion adds symlink/permission/enumeration complexity. Add when a real use case appears.
- **`-Update` / `-Compare` for manifests** — Power-user features; users can recreate a manifest cheaply for now.
- **Save-location dialog for manifest create** — MVP writes to common parent directory; predictable and scriptable.
- **macOS context-menu integration** — No demand; would need its own integration module entry.
- **Module signing / PSGallery publish** — Only relevant if distributed beyond this repo.
- **`-Json` machine-readable output** — Plain-text log is enough for human use; add when a consumer exists.

---

## Out of Scope (Explicit Exclusions)

- **VirusTotal integration** — Cut entirely from project scope, not just deferred. Reason: scope creep risk, focus on the core "hash + sign" promise. Re-evaluate as a separate tool if ever desired.
- **PSFramework dependency** — Replaced with a tiny built-in plain-text logger. No path back unless a structured-log consumer materializes.
- **CLI backwards compatibility with v1.x** — v2 is a clean break; the README documents the breaking changes. The single user (project author) drives this.
- **`QuickHash.ps1` as a separate tool** — The lean v2 hot path replaces its purpose. Removed, not preserved as a wrapper.
- **`VeriHash.LogUtils.ps1` log parser** — No machine consumer of the log file is in scope; built-in `Select-String` is enough.

---

## Traceability

*Filled by `gsd-roadmapper` on 2026-04-18.*

| REQ-ID | Phase |
|--------|-------|
| CORE-01 | Phase 1: Core Module Foundation |
| CORE-02 | Phase 1: Core Module Foundation |
| CORE-03 | Phase 1: Core Module Foundation |
| CORE-04 | Phase 1: Core Module Foundation |
| CORE-05 | Phase 1: Core Module Foundation |
| CORE-06 | Phase 1: Core Module Foundation |
| CORE-07 | Phase 1: Core Module Foundation |
| CORE-08 | Phase 1: Core Module Foundation |
| PERF-01 | Phase 2: Hot-Path Performance + Multi-File Loop |
| PERF-02 | Phase 2: Hot-Path Performance + Multi-File Loop |
| PERF-03 | Phase 2: Hot-Path Performance + Multi-File Loop |
| PERF-04 | Phase 2: Hot-Path Performance + Multi-File Loop |
| PERF-05 | Phase 2: Hot-Path Performance + Multi-File Loop |
| MULTI-01 | Phase 2: Hot-Path Performance + Multi-File Loop |
| MULTI-02 | Phase 2: Hot-Path Performance + Multi-File Loop |
| MULTI-03 | Phase 2: Hot-Path Performance + Multi-File Loop |
| MANIFEST-01 | Phase 3: Manifest Module |
| MANIFEST-02 | Phase 3: Manifest Module |
| MANIFEST-03 | Phase 3: Manifest Module |
| MANIFEST-04 | Phase 3: Manifest Module |
| MANIFEST-05 | Phase 3: Manifest Module |
| MANIFEST-06 | Phase 3: Manifest Module |
| MANIFEST-07 | Phase 3: Manifest Module |
| MANIFEST-08 | Phase 3: Manifest Module |
| INTEG-01 | Phase 4: Integrations + Config Trim |
| INTEG-02 | Phase 4: Integrations + Config Trim |
| INTEG-03 | Phase 4: Integrations + Config Trim |
| CFG-01 | Phase 4: Integrations + Config Trim |
| CFG-02 | Phase 4: Integrations + Config Trim |
| CFG-03 | Phase 4: Integrations + Config Trim |
| CLI-01 | Phase 5: Thin CLI + Cleanup & Docs |
| CLI-02 | Phase 5: Thin CLI + Cleanup & Docs |
| CLI-03 | Phase 5: Thin CLI + Cleanup & Docs |
| CLEAN-01 | Phase 5: Thin CLI + Cleanup & Docs |
| CLEAN-02 | Phase 5: Thin CLI + Cleanup & Docs |
| CLEAN-03 | Phase 5: Thin CLI + Cleanup & Docs |
| CLEAN-04 | Phase 5: Thin CLI + Cleanup & Docs |
| CLEAN-05 | Phase 5: Thin CLI + Cleanup & Docs |
