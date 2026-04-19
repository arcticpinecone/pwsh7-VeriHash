# Phase 5: Thin CLI + Cleanup & Docs - Context

**Gathered:** 2025-07-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the ~890-line VeriHash.ps1 monolith with a ≤200-line thin CLI dispatcher that parses parameters, imports v2 modules (Core, HotPath, Manifest, Integrations), calls the appropriate entry function, renders output via `Format-VeriHashReport`, and handles centralized pause-at-end. Delete all retired v1 files, rewrite README and CHANGELOG for v2, and archive concepting docs.

Out of scope: module internals (already shipped in Phases 1–4), new features, PSGallery publishing.

</domain>

<decisions>
## Implementation Decisions

### CLI parameter contract
- **D-01:** Clean break from v1 parameter surface. The v2 CLI exposes: `[string[]]$FilePath`, `-Manifest` [switch], `-InstallSendTo` [switch], `-InstallKDE` [switch], `-NoPause` [switch], `-SystemWide` [switch], `-Log` [switch], `-Help` [switch]. Dropped entirely: `-Hash`, `-Algorithm`, `-OnlyVerify`, `-SkipSignatureCheck`, `-LogLevel`, `-Force`. Renamed: `-SendTo` → `-InstallSendTo` (clearer intent).
- **D-02:** `[string[]]$FilePath` is the single file-input parameter for all modes. `-Manifest` flag switches between hash mode (default) and manifest mode. Within manifest mode, extension auto-detect applies: `.sha256`/`.sha512`/`.md5` → verify that manifest; anything else → create a manifest for those files. This carries forward Phase 4 decision D-09/D-10.
- **D-03:** No-args interactive case — when invoked with no FilePath and no piped input, detect interactivity and show a help banner with usage examples, then pause. This replaces the v1 file-picker dialog.
- **D-04:** Pause-at-end auto-detection — when files ARE provided, pause only if there is no parent console (launched from Explorer/SendTo). Terminal sessions skip pause automatically. `-NoPause` remains as an explicit override. The detection heuristic is agent's discretion at implementation time.

### Dead code & config fate
- **D-05:** Delete `VeriHash.Config.ps1` — the v2 architecture has no config system. Logging is controlled by `-Log` switch and `$env:VERIHASH_LOG=1`. VirusTotal was removed in Phase 4. Config file (`config.json`) handling is retired.
- **D-06:** Delete `ConvertTo-SanitizedPath` (in `VeriHash.LogUtils.ps1`) and delete the entire `VeriHash.LogUtils.ps1` file — dead code with no v2 consumer. Phase 4 left it alive pending this decision; the answer is: retire it. Resolves Phase 4 deferred item.
- **D-07:** Delete `VeriHash-OpenWith.bat` — v2 SendTo uses proper `.lnk` shortcuts created by `Install-WindowsSendTo`. The `.bat` was a v1 workaround.
- **D-08:** Delete `Tests/VeriHash.Config.Tests.ps1` and `Tests/VeriHash.Tests.ps1` — they test deleted or completely rewritten code. `Tests/VeriHash.LogUtils.Tests.ps1` is also deleted (tests the deleted LogUtils).

### README & CHANGELOG shape
- **D-09:** Comprehensive README rewrite. Structure: Features, Requirements, Installation, Usage (hash/verify/manifest), OS Integration (SendTo/KDE), Module Architecture (VeriHash.Core + HotPath + Manifest + thin CLI), Speed Benchmarks, "Why PowerShell 7?", PowerShell Profile Integration, Privacy, Contributing, Running Tests, License. Drop the QuickHash section (file deleted). Add Module Architecture section documenting v2 internals.
- **D-10:** Clean v2.0 CHANGELOG entry. Frame as "Modular Rewrite". List key new capabilities (module architecture, manifest support, multi-file loop, prefixed clipboard parsing). Include a "⚠️ Breaking Changes" section listing dropped params and removed features (VT, PSFramework, QuickHash, LogUtils). Move all v1 entries under a collapsed "Version 1.x History" section.
- **D-11:** Move the three concepting docs (`Verihash Logging Concepting.md`, `Verihash Multifile Concepting.md`, `Verihash Multifile Concepting Review.md`) to `.planning/archive/`. Create the archive directory if it doesn't exist.
- **D-12:** Version badge in README header shows `v2.0` with a short tagline (e.g., "Modular Rewrite"). No inline release notes in the header — link to CHANGELOG instead.

### CLI test strategy
- **D-13:** `Tests/VeriHash.Cli.Tests.ps1` covers dispatch routing and error paths. Mock the underlying module functions (Core, Manifest, Integrations) — don't re-test their internal logic. Focus: correct param → function mapping, error handling for invalid input, help banner display.
- **D-14:** Pause detection logic extracted into a testable function (`Test-VeriHashInteractive` or similar) so tests can mock it. This satisfies CLI-02 (centralized pause) while keeping it testable.

</decisions>

<specifics>
## Specific Ideas

- The clean parameter break (D-01) was chosen because v2 is a ground-up rewrite — carrying deprecated params as aliases adds complexity with no benefit. Users upgrading from v1 get clear errors rather than silent behavior changes.
- `[string[]]$FilePath` as the universal input (D-02) simplifies the CLI — one param, two modes via `-Manifest` switch. This is more PowerShell-idiomatic than separate `-InputFile` and `-ManifestFile` params.
- Pause auto-detection (D-04) targets the SendTo/Explorer use case where output would flash and disappear. The heuristic can check `[Environment]::UserInteractive`, parent process, or stdin redirection — exact approach is agent discretion during implementation.
- `ConvertTo-SanitizedPath` retirement (D-06) resolves the Phase 4 deferred item. `Write-VeriHashLog` in Core doesn't log full paths, so the sanitizer has no consumer. Git history preserves it if ever needed.
- Comprehensive README (D-09) was chosen over lean because VeriHash is a standalone tool, not a library. Users need benchmarks, profile integration guidance, and architecture docs to understand the v2 module split.
- Dispatch-only CLI tests (D-13) avoid re-testing module logic that already has thorough coverage (Core: 7 test files, Manifest: 5 test files, Integrations: 1 test file). The CLI is glue code — tests verify the glue, not the components.

</specifics>

<canonical_refs>
## Canonical References

| Ref | Location | Relevance |
|-----|----------|-----------|
| CLI-01 | REQUIREMENTS.md | Thin dispatcher ≤200 lines — param parse + module import + dispatch |
| CLI-02 | REQUIREMENTS.md | Pause-at-end centralized in CLI; modules don't check -NoPause |
| CLI-03 | REQUIREMENTS.md | VeriHash.Cli.Tests.ps1 covers locked v2 contract end-to-end |
| CLEAN-01 | REQUIREMENTS.md | Delete QuickHash.ps1 + Tests/QuickHash.Tests.ps1 |
| CLEAN-02 | REQUIREMENTS.md | Delete VeriHash.LogUtils.ps1 + Tests/VeriHash.LogUtils.Tests.ps1 |
| CLEAN-03 | REQUIREMENTS.md | README rewritten for v2 architecture |
| CLEAN-04 | REQUIREMENTS.md | CHANGELOG has v2.0 entry with removals/additions/breaking changes |
| CLEAN-05 | REQUIREMENTS.md | Concepting docs moved to .planning/archive/ |
| Phase 4 D-09 | 04-CONTEXT.md | Manifest auto-detect by extension (carried into D-02) |
| Phase 4 D-10 | 04-CONTEXT.md | -Manifest flag on VeriHash.ps1 (carried into D-02) |
| Phase 4 D-06 | 04-CONTEXT.md | ConvertTo-SanitizedPath left as dead code — now resolved by D-06 |
| Phase 4 D-12 | 04-CONTEXT.md | Phase 4 created shortcuts; Phase 5 wires handler |
| Phase 3 D-17 | 03-CONTEXT.md | No Write-Host in manifest module; CLI handles display |
| Phase 1 D-03 | 01-CONTEXT.md | Get-VeriHashPlatform is the only platform check |
| VeriHash.ps1 | VeriHash.ps1:58-95 | Current v1 param block — to be replaced |
| CONVENTIONS.md | .planning/codebase/ | Function signature, logging, test patterns |

</canonical_refs>

<deferred>
## Deferred Ideas

- **PSGallery module publishing:** Packaging VeriHash.Core as a PSGallery module is a future milestone concern. Phase 5 ships the thin CLI; distribution is out of scope.
- **GNOME/XFCE context-menu support:** The extensible architecture (Phase 4) supports adding desktop environments, but implementation is deferred to a future milestone.
- **Interactive file picker replacement:** v1 had a Windows GUI file picker when no args were given. v2 shows a help banner instead. A future milestone could add `fzf`-style file selection if there's demand.

</deferred>
