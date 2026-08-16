---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: UX Polish & Smart Routing
status: ready_to_ship
last_updated: "2026-08-16T00:00:00.000Z"
last_activity: 2026-08-16
progress:
  total_phases: 3
  completed_phases: 3
  total_plans: 7
  completed_plans: 7
  percent: 100
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-04-19 for v3.0)

**Core value:** Trustworthy file integrity verification — fast, scriptable, privacy-respecting.
**Current focus:** v3.0 — UX Polish & Smart Routing → scope closed, ready to ship

## Current Position

**Milestone:** v3.0 — UX Polish & Smart Routing
**Phase:** all three shipped — 6 (Sidecar Auto-Detect), 7 (Output Formatting), 9 (Comparator Correctness)
**Plan:** 7 of 7 complete
**Status:** Scope closed 2026-08-16. 371 tests pass, PSScriptAnalyzer clean. Phase 8
(Manifest Spot-Check) deferred to a later milestone — see REQUIREMENTS.md → Future
Requirements for the reasoning.
**Last activity:** 2026-08-16 — 09-02 executed (CMP-10 unsupported-hex reporting), manifest
summary undercount fixed, and `Test-All.ps1`'s fail-green quality gate repaired

Progress: [██████████] 100%

**Before shipping:** the milestone still wants an audit pass and a retrospective, the way
v2.0 got one (see `.planning/milestones/`). Everything in scope is built and green; what is
missing is the archive, not the work.

### Shipped Milestones

| Version | Name | Phases | Plans | Requirements | Shipped |
| ------- | ---- | ------ | ----- | ------------ | ------- |
| v2.0 | Modular Rebuild | 5 | 15 | 38/38 | 2026-04-19 |
| v1.0 | Privacy + Foundation | 3 | 6 | 11/11 | 2026-04-18 |

See `.planning/MILESTONES.md` for full archive.

## Accumulated Context

### Decisions

- Phase structure decided: 3 phases (6=sidecar auto-detect, 7=output formatting, 8=manifest spot-check)
- Phase 7 depends on Phase 6 (routing must be solid before reformatting output)
- Phase 8 depends on Phase 6 (manifest routing must be solid)
- SIDE-06: Sidecar auto-detect intercepts BEFORE manifest/hash branching — identical with/without -Manifest
- FMT: renderer waits for both hot-path ThreadJobs so the checklist is one block; parallelism is unaffected
- FMT: sidecar writes are suppressed on clipboard MISMATCH
- CMP: sidecar-write suppression keys off ALL negative evidence (comparator verdict OR `SidecarStatus`), superseding the FMT decision above
- CMP: comparator selection lives in one function, `Resolve-VeriHashComparator`, public in Core so HotPath can reach it across the module boundary
- CMP: a pasted hash is a question, not a comparator — if it cannot be answered, the banner abstains (`UNVERIFIED`) rather than silently answering with the sidecar
- CMP: `BatchResult.Tally` is the seam for new counts; `TallyLine` stays byte-locked
- CMP: a weak primary (MD5, SHA1) computes a SHA256 companion in a parallel ThreadJob — the user's question is answered without withholding the digest worth keeping
- CMP: the sidecar is ALWAYS `.sha256` (or `.sha512` under an explicit SHA512); `.md5`/`.sha1` are never written, which supersedes the earlier "clipboard-selected algorithm writes nothing" rule
- CMP: SHA1 is fully supported — answerable as a question, never recorded as a durable result
- CMP: clipboard parsing tolerates grouping, vendor labels, and `sha256sum` lines, but never joins whitespace across what may be two separate digests
- CMP: single-pass `IncrementalHash` fan-out stays deferred; two parallel `Get-FileHash` jobs cost ~5-15% wall clock at typical sizes because the OS cache serves the second reader
- FMT: `BatchResult.TallyLine` stays byte-locked; console display is a separate concern
- FMT: the CLI pins `[Console]::OutputEncoding` to UTF-8; anything capturing its output must decode UTF-8 too

### Pending Todos

None. Both outstanding todos closed 2026-08-16:

- [manifest-summary-undercounts](todos/done/manifest-summary-undercounts.md) — **fixed.** Counts are now taken by walking entries once and incrementing exactly one bucket each; an uncounted status throws. `Summary` gained `Rejected`, and the tally line renders it.
- [debug-sendto-manifest-crash](todos/done/debug-sendto-manifest-crash.md) — **already fixed by `403350d`, verified and closed.** Reproduced the SendTo shape (ten paths with spaces appended after `-Manifest`): 10 files, exit 0, all entries present. The todo had simply outlived its fix by four months.

### Blockers/Concerns

None. One caveat for the release: three PSScriptAnalyzer warnings exist on `main` at v2.0.0, which is correct for that historical release point and not a regression on this branch. `dev` is analyzer-clean.

## Session Continuity

**Stopped at:** v3.0 scope closed — 371 tests pass, PSScriptAnalyzer clean, both todos closed
**Resume file:** `.planning/notes/comparator-algorithm-exploration.md`
**Next action:** milestone audit and retrospective for v3.0 (the archive v2.0 received), then tag v3.0.0 and merge dev into main. Phase 8 (Manifest Spot-Check) is deferred, not dropped — its five SPOT requirements are in REQUIREMENTS.md → Future Requirements.
