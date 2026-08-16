# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — Privacy + Foundation

**Shipped:** 2026-04-18
**Phases:** 3 | **Plans:** 6

### What Was Built

- Privacy-compliant logging: hash truncation + path sanitization across all modules
- GitHub Actions CI pipeline: Pester cross-platform + PSScriptAnalyzer on all 3 files
- PSFramework log rotation with 30-day retention
- VirusTotal default flipped to disabled; logging guide updated to match reality

### What Worked

- **Guide-as-contract approach** — treating the logging concepting doc as the spec and fixing code to match gave clear, auditable acceptance criteria
- **CI before features** — shipping the pipeline in Phase 2 meant Phase 3 changes were auto-validated
- **Grouping LOGC-02 with Phase 1** — shared dot-source reordering avoided a second round of module restructuring
- **Milestone audit before completion** — caught checkbox drift and missing validation artifacts proactively

### What Was Inefficient

- **Checkbox drift** — requirements and roadmap checkboxes weren't ticked as phases completed, requiring a bulk fix at audit time
- **No VERIFICATION.md during execution** — all 3 had to be generated retroactively; should be part of phase completion
- **PSFramework silent skip** — discovered during UAT that tests silently skip when PSFramework absent; this should have been caught earlier in the process

### Patterns Established

- Dot-source order convention: `LogUtils → Config → VeriHash.ps1` (utility-first)
- `ConvertTo-SanitizedPath` as the single sanitization entry point for all log payloads
- `$script:PSFrameworkAvailable` as the canonical guard variable (set once, checked everywhere)
- PSScriptAnalyzer settings: `PSAvoidUsingWriteHost` + `PSAvoidUsingBrokenHashAlgorithms` suppressed project-wide
- CI matrix: `fail-fast: false` + Pester `MaximumVersion 5.99` pinning

### Key Lessons

1. **Tick checkboxes as you go** — waiting until audit creates unnecessary remediation work
2. **Generate VERIFICATION.md during plan execution**, not as a retroactive gap-fill
3. **Optional dependencies need visibility** — PSFramework's graceful degradation is good, but users should know what they're missing (logged as Backlog 999.1)
4. **Single-day milestones are viable** when scope is tight and well-defined — 3 phases, 6 plans, 44 commits in one session

### Cost Observations

- Sessions: 1 (single continuous session)
- Notable: Entire milestone from planning through archival in one session; retroactive audit/validation added ~30% overhead that could be eliminated with inline completion checks

---

## Milestone: v2.0 — Modular Rebuild

**Shipped:** 2026-04-19
**Phases:** 5 | **Plans:** 15 | **Requirements:** 38/38
**Duration:** 2 days (2026-04-18 → 2026-04-19)

### What Was Built

- Three-module architecture: `VeriHash.Core` (hash, clipboard, sidecar, format, log, platform), `VeriHash.HotPath` (parallel PE signature, batch, tally), `VeriHash.Manifest` (GNU sha256sum create/verify)
- 196-line thin CLI dispatcher replacing 1,527-line monolith
- P/Invoke WinVerifyTrust for PE-only Authenticode with ThreadJob parallelism
- Multi-file batch mode with byte-locked tally
- Manifest mode with atomic writes, path-traversal guard, machine-readable exit codes (0/1/2/3)
- Full cleanup: VirusTotal removed, PSFramework removed, QuickHash + LogUtils retired
- README and CHANGELOG rewritten for v2 architecture

### What Worked

- **Coarse phases** — Compressing 9 user-sketched phases into 5 dependency-ordered phases was the right call; each had clear boundaries and the dependency graph prevented integration conflicts
- **TDD caught real bugs** — "Never modify tests to pass" surfaced a real bug in `Format-VeriHashReport` (`.Status` vs `.Sidecar` property name) and clipboard contamination in batch tests
- **Module isolation** — Three separate modules with clean public APIs made testing straightforward; each testable in isolation via `Import-Module`
- **Audit-before-close** — Milestone audit caught 4 tech debt items that would have been embarrassing in the archive

### What Was Inefficient

- **Plan 05-02 checkbox drift** — ROADMAP showed `[ ] 05-02-PLAN.md` despite CLI tests being written and passing; fixed during tech debt pass but shouldn't have been necessary
- **Quick task state tracking** — The `260418-rename-log-jsonl` false positive from `audit-open` shows v1-era quick tasks don't cleanly survive milestone transitions

### Patterns Established

- `Import-Module` loading in all tests (no dot-source hack)
- Plain-text `Write-VeriHashLog` replacing PSFramework logging
- `Get-VeriHashPlatform` as single-source platform detection
- ThreadJob parallelism for hash + signature with explicit cleanup
- GNU sha256sum format validation via WSL round-trip
- `Format.ps1xml` with `FormatsToProcess` in module manifests

### Key Lessons

1. **P/Invoke for Windows APIs is viable** in PowerShell modules — WinVerifyTrust shim was cleaner and faster than `Get-AuthenticodeSignature`
2. **ThreadJob parallelism is easy to add** but clipboard/environment contamination between jobs needs explicit cleanup
3. **GNU sha256sum interop via WSL** is a strong validation for standards compliance
4. **Tick checkboxes as you go** — still not automated; same lesson from v1.0

---

## Milestone: v3.0 — UX Polish & Smart Routing

**Shipped:** 2026-08-16
**Phases:** 3 of 4 (Phase 8 deferred) | **Requirements:** 32/32 in scope, 5 deferred

### What Was Built

- Sidecar auto-detect: right-clicking a `.sha256`/`.sha512`/`.md5` verifies the companion file rather than hashing the sidecar text
- Console redesign: reversed-video verdict banner, stacked 8-char-group comparison with divergence highlighting, four-row checklist, truecolor with `NO_COLOR` and ASCII fallbacks
- Comparator correctness: one owner for comparator selection, clipboard-driven algorithm, SHA256 companion for weak primaries, `UNVERIFIED` as a fourth verdict
- SHA1 support and tolerant clipboard parsing (vendor labels, `sha256sum` lines, grouped hex)
- Relicensed AGPL-3.0 → MIT

### What Worked

- **A pasted hash is a question, not a comparator** — framing it that way resolved a whole family of bugs at once. Once "the user asked something we cannot answer" became a representable state (`unusable` → `UNVERIFIED`), the silent sidecar fallback stopped being tempting
- **One owner for a rule** — collapsing comparator selection into `Resolve-VeriHashComparator` fixed a real defect where two call sites had drifted apart, one guarded and one not
- **Writing the reason into the code** — the codebase explains *why* at the point of decision, not just what. That is why the fail-green defects were findable: the comments stated intentions the code could then be checked against
- **CMP-14 as a named pattern** — "a value outside a closed set never resolves to a silent fallback" was written down mid-milestone, and then correctly predicted three more instances of the same bug

### What Was Inefficient

- **Checkbox drift, for the third milestone running.** Every `SIDE-*` and `FMT-*` requirement sat unticked for months after shipping. STATE.md reported 67% complete when one feature remained. This exact lesson is recorded in both the v1.0 and v2.0 retrospectives and was still not applied
- **Phase 9 shipped with no plan documents** — driven straight from an exploration note. The note was thorough and commits atomic, so no work was lost, but phase status became unreadable from the planning directory, which is the proximate cause of the drift above
- **A phase added mid-milestone was never added to the roadmap** — Phase 9 and its 19 requirements were invisible in ROADMAP.md and the traceability table until the audit
- **Percent-complete measured over phase counts** — distorts badly when phases differ in size, and it did

### Patterns Established

- Sidecars are always `.sha256` (or `.sha512` under explicit SHA512); `.md5`/`.sha1` are never written, so a weak digest can never become a trusted comparator later
- Machine-readable seams stay byte-locked while display changes freely (`BatchResult.TallyLine`)
- Counts are derived by a single pass that increments exactly one bucket, with an unmapped value throwing — never by independent queries that can drift from the total
- Weakness attaches to the vendor's algorithm choice, shown on the clipboard row, and never to the verdict banner — a signal that can never go green is wallpaper

### Key Lessons

1. **A quality gate must be tested like anything else.** `Test-All.ps1` could never report a failure for its entire existence, because `Invoke-Pester` was called without `PassThru` and the null result compared as passing. Nothing above it could have noticed
2. **Pin tooling to what developers actually run.** CI pinned Pester ≤5.99 while everyone ran 6.1, so a green CI was not evidence about the suite anyone executes — in either direction. Note that this pin was recorded as an *established pattern* in the v1.0 retrospective; patterns need expiry dates
3. **The same lesson recorded three times is a process problem, not a discipline problem.** "Tick checkboxes as you go" has now failed in v1.0, v2.0, and v3.0. It needs a mechanism — a phase-close step that fails loudly — not another reminder
4. **Deferring is cheaper than it feels.** Phase 8 was five specified requirements with zero code. Deferring it shipped finished correctness work months earlier and cost nothing but a heading move

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
| --------- | -------- | ------ | ---------- |
| v1.0 | 1 | 3 | Established GSD workflow, CI pipeline, privacy compliance |
| v2.0 | 1 | 5 | Full modular rebuild, three-module architecture, monolith eliminated |
| v3.0 | several | 3 (+1 deferred) | Correctness focus; first milestone to defer a phase deliberately and to relicense |

### Cumulative Quality

| Milestone | Tests | Skipped | Prod LOC | Test LOC |
| --------- | ----- | ------- | -------- | -------- |
| v1.0 | 133 | 8 | ~2,000 (monolith) | ~1,200 |
| v2.0 | 176 | 5 | 2,039 (3 modules) | 1,817 |
| v3.0 | 371 | 5 | 3,130 (3 modules) | 4,456 |

### Top Lessons (Verified Across Milestones)

1. Treat documentation as spec — fix code to match, not the other way around
2. Ship CI early — automated validation saves manual re-checking on every subsequent change
3. Tick checkboxes as you go — waiting creates unnecessary remediation at audit time (**repeated v1.0 → v2.0 → v3.0**; three occurrences means this needs a mechanism, not another reminder)
4. Module isolation pays off — clean APIs make testing straightforward and integration predictable
5. Verify the verifier — `Test-All.ps1` reported success on every run for its entire existence because a null Pester result compared as passing. Tooling that reports on correctness is not exempt from being checked for correctness (v3.0)
6. Established patterns need expiry dates — the Pester `MaximumVersion 5.99` pin was recorded as a *good pattern* in the v1.0 retrospective and had become a liability by v3.0, with CI testing a runner nobody used (v3.0)
