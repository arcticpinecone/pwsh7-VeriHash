# Phase 3: Manifest Module - Discussion Log

**Date:** 2026-04-18
**Mode:** Interactive (standard)
**Areas discussed:** 4 of 4

---

## Area 1: Manifest Naming & Format

**Gray area:** Filename format, algorithm scope, comment handling, path separators.

**Discussion:**
- User confirmed timestamp-based naming (`YYYY-MM-DDTHHMMSSZ`) but requested adding `_manifest` suffix for at-a-glance identification → `YYYY-MM-DDTHHMMSSZ_manifest.sha256`
- SHA256-only for Phase 3 MVP — multi-algorithm deferred
- Skip blank lines and `#` comments when parsing — user noted this enables future metadata comments at bottom of manifest files
- Forward slashes when writing, accept both when reading — confirmed as proposed

**Decisions:** D-01 through D-07

---

## Area 2: Hashing Strategy

**Gray area:** Sequential vs parallel hashing, Core reuse, error handling during create.

**Discussion:**
- Sequential hashing chosen — simple, predictable, disk I/O is the real bottleneck
- Reuse `Get-VeriHashResult` from Core — no direct .NET crypto calls
- **Key override of concepting doc:** User chose "stop on first error" during create instead of "continue and record failures." No partial manifests written. Temp file cleaned up on abort.

**Decisions:** D-08 through D-10

---

## Area 3: Verify Output & Exit Codes

**Gray area:** Exit code mapping, result object shape, path traversal handling.

**Discussion:**
- Exit codes 0/1/2/3 confirmed as proposed, highest code wins on mixed failures
- Structured `VeriHash.ManifestVerifyResult` object returned (not Write-Host)
- Path traversal is hard reject with exit code 3 — confirmed per MANIFEST-05

**Decisions:** D-11 through D-13

---

## Area 4: Module Public Surface

**Gray area:** Function naming, module dependency, return types, CLI scope.

**Discussion:**
- `New-VeriHashManifest` + `Test-VeriHashManifest` — standard PowerShell verbs
- `RequiredModules = @('VeriHash.Core')` in psd1 — idiomatic PowerShell dependency
- Two distinct PSTypeName result objects: `VeriHash.ManifestCreateResult` and `VeriHash.ManifestVerifyResult`
- No Write-Host in Phase 3 — module returns objects, Phase 5 CLI formats output

**Decisions:** D-14 through D-18

---

## Scope Redirects

- SendTo integration (MANIFEST-07) → Phase 4 INTEG-02
- Console formatting → Phase 5 CLI layer
- Multi-algorithm → future phase (backlog)
- Parallel hashing → future optimization if needed
- Metadata comments → deferred idea (enabled by D-04)
