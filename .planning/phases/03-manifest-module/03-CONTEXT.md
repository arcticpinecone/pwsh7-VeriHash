# Phase 3: Manifest Module - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

`VeriHash.Manifest` PowerShell module that creates and verifies GNU `sha256sum`-compatible manifest files. Supports atomic writes, path-traversal-safe verification, and machine-readable exit codes. Console formatting and SendTo integration are out of scope (Phase 4/5).

</domain>

<decisions>
## Implementation Decisions

### Manifest naming & format
- **D-01:** Manifest filename format is `YYYY-MM-DDTHHMMSSZ_manifest.<algorithm>` (e.g., `2026-04-17T143022Z_manifest.sha256`). UTC always, `Z` suffix, colons removed for Windows compatibility, `_manifest` suffix for at-a-glance identification.
- **D-02:** Collision handling: append `-1`, `-2`, etc. if filename already exists.
- **D-03:** Path separators: always write forward slashes (`/`) in manifest entries. Accept both `/` and `\` when reading/verifying.
- **D-04:** Skip blank lines and `# comment` lines when parsing manifests (matches GNU `sha256sum -c` behavior). This also future-proofs for metadata comments.
- **D-05:** Always binary mode — write `*` prefix before filename in manifest lines (`<hash> *<filename>`).
- **D-06:** UTF-8 encoding, no BOM.
- **D-07:** SHA256-only for Phase 3 MVP. Multi-algorithm support (SHA512, SHA1, MD5) deferred to a future phase.

### Hashing strategy
- **D-08:** Sequential hashing during create — hash files one at a time in input order. No parallelism in Phase 3 MVP. Parallel can be added later if profiling warrants it.
- **D-09:** Reuse `Get-VeriHashResult` from VeriHash.Core for all hashing — extract `.Hash` from the result object. Do not call .NET crypto APIs directly.
- **D-10:** Atomic write: create manifest via temp file → rename pattern. If any file fails to hash during create, abort immediately — no partial manifest written. Clean up the temp file on error.

### Verify output & exit codes
- **D-11:** Exit codes: 0=all pass, 1=at least one mismatch, 2=at least one file missing, 3=parse error or path traversal detected. Highest code wins when multiple failure types occur.
- **D-12:** `Test-VeriHashManifest` returns a `VeriHash.ManifestVerifyResult` object with: `.ManifestPath`, `.Entries` (array of per-file results: path, expected hash, actual hash, status), `.ExitCode`, `.Summary` (total/passed/failed/missing counts).
- **D-13:** Path traversal (`../` or absolute paths in entries) is a hard reject — immediately return exit code 3. Paths are resolved relative to the manifest file's directory.

### Module public surface
- **D-14:** Two public functions: `New-VeriHashManifest` (create) and `Test-VeriHashManifest` (verify).
- **D-15:** Two distinct PSTypeName result objects: `VeriHash.ManifestCreateResult` (returned by New) and `VeriHash.ManifestVerifyResult` (returned by Test).
- **D-16:** Module dependency: declare `RequiredModules = @('VeriHash.Core')` in the `.psd1` manifest. PowerShell auto-loads Core when Manifest is imported.
- **D-17:** No Write-Host or console formatting in Phase 3. Module returns structured objects only. Phase 5 CLI handles all display formatting.

### Hash extension skip rules
- **D-18:** `New-VeriHashManifest` silently filters out files with hash-related extensions: `.sha256`, `.sha512`, `.sha384`, `.sha1`, `.md5`, `.sha2_256`, `.sha2` (per MANIFEST-03). No warning needed — these are noise.

### Agent's Discretion
- Private helper function decomposition (how many private helpers, naming)
- Exact parameter names and aliases for `New-VeriHashManifest` / `Test-VeriHashManifest`
- Internal regex pattern for manifest line parsing
- Temp file naming convention during atomic write
- Exact shape of `VeriHash.ManifestCreateResult` properties (beyond ManifestPath and FileCount)

</decisions>

<specifics>
## Specific Ideas

- Manifest `_manifest` suffix was a user request — makes the file's purpose obvious at a glance in file listings.
- User explicitly chose "stop on first error" over "continue and record failures" for create mode — this is a clean contract: either a complete manifest or nothing.
- Comment/blank line skipping enables future metadata: `# comments` at the bottom of manifests could carry VeriHash-specific metadata without breaking GNU compatibility.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Manifest requirements
- `.planning/REQUIREMENTS.md` §MANIFEST — MANIFEST-01 through MANIFEST-08 define all 8 requirements for this phase
- `.planning/ROADMAP.md` §Phase 3 — Phase definition, success criteria, dependency on Phase 1

### Manifest design
- `Verihash Multifile Concepting.md` — Detailed manifest feature design: format spec, create/verify flows, CLI interface, skip rules, security model, behavior contracts. Note: Some decisions in this doc are overridden by CONTEXT.md decisions (e.g., error handling during create is now "stop on first error" not "continue").

### Prior phase decisions
- `.planning/phases/01-core-module-foundation/01-CONTEXT.md` — Module layout (Public/Private), result object pattern (PSTypeName), Get-VeriHashPlatform, Write-VeriHashLog, module at repo root
- `.planning/phases/02-hot-path-performance-multi-file-loop/02-CONTEXT.md` — HotPath module pattern, batch result objects

### Codebase conventions
- `.planning/codebase/CONVENTIONS.md` — Function signatures, CmdletBinding, comment-based help, error handling patterns
- `.planning/codebase/STRUCTURE.md` — Repo layout, where to add new module code

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Get-VeriHashResult` (VeriHash.Core/Public): Core hashing function — call with file path, returns `VeriHash.Result` with `.Hash` (lowercase hex), `.Algorithm`, `.FilePath`. This is the hashing engine for manifest create.
- `ConvertTo-VeriHashAlgorithm` (VeriHash.Core/Private): Algorithm name normalization — may not be needed for SHA256-only MVP but available.
- `Write-VeriHashLog` (VeriHash.Core/Public): Plain-text logging, opt-in via `-Log` switch or `$env:VERIHASH_LOG=1`.
- `Get-VeriHashPlatform` (VeriHash.Core/Public): Platform detection if any OS-specific behavior is needed.

### Established Patterns
- Module structure: `VeriHash.<Name>/Public/` + `VeriHash.<Name>/Private/` dot-sourced from `.psm1` (see VeriHash.Core and VeriHash.HotPath)
- Result objects: `[pscustomobject]` with `PSTypeName` property (e.g., `VeriHash.Result`)
- Test isolation: `$env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')` in BeforeAll
- Module manifest: `.psd1` with `RequiredModules`, `FunctionsToExport`, `ModuleVersion`

### Integration Points
- VeriHash.Core must be importable via `RequiredModules` — Phase 3 module sits alongside Core at `./VeriHash.Manifest/`
- Phase 5 CLI will call `New-VeriHashManifest` and `Test-VeriHashManifest`, format the result objects for display
- MANIFEST-08 requires `sha256sum -c` round-trip test — the manifest file written by `New-VeriHashManifest` must be parseable by GNU `sha256sum`

</code_context>

<deferred>
## Deferred Ideas

- **Multi-algorithm support** (SHA512, SHA384, SHA1, MD5 via `-Algorithm` parameter) — future phase after SHA256 MVP proves out
- **Parallel hashing** during manifest create (ThrottleLimit 2+) — add if profiling shows sequential is a bottleneck
- **Metadata comments** at bottom of manifest files (`# VeriHash v2.0`, timestamps, etc.) — enabled by D-04's comment-skipping but not implemented in Phase 3
- **SendTo integration** (`VeriHash - Manifest.lnk`) — Phase 4 INTEG-02, not Phase 3
- **Console output formatting** (✅❌⚠️ emoji indicators, summary lines, progress) — Phase 5 CLI layer

</deferred>

---

*Phase: 03-manifest-module*
*Context gathered: 2026-04-18*
