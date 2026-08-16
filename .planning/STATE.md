---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: UX Polish & Smart Routing
status: ready_to_plan
last_updated: "2026-08-16T00:00:00.000Z"
last_activity: 2026-08-16
progress:
  total_phases: 4
  completed_phases: 2
  total_plans: 6
  completed_plans: 4
  percent: 67
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-04-19 for v3.0)

**Core value:** Trustworthy file integrity verification — fast, scriptable, privacy-respecting.
**Current focus:** v3.0 — UX Polish & Smart Routing → Phase 9: Comparator Correctness

## Current Position

**Milestone:** v3.0 — UX Polish & Smart Routing
**Phase:** 9 of 9 (Comparator Correctness) — 09-01 and 09-03 executed, 09-02 to plan
**Plan:** 2 of 3 complete
**Status:** 09-01 and 09-03 shipped (353 tests pass). Phase 8 (Manifest Spot-Check) still unplanned.
**Last activity:** 2026-08-16 — 09-03 executed (clipboard tolerance, clipboard-driven algorithm, SHA256 companion, SHA1 support, CLI `-Algorithm`)

Progress: [███████░░░] 67%

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

- [manifest-summary-undercounts](todos/pending/manifest-summary-undercounts.md) — `Test-VeriHashManifest` produces 5 entry statuses and counts 3; `parse-error` and `traversal-rejected` are in `Total` but no bucket, so the summary line does not add up. Fails loud (red, exit 3), but the arithmetic is false. Found by the switch-default audit, 2026-08-16.

### Blockers/Concerns

None yet.

## Session Continuity

**Stopped at:** Phase 9 plans 09-01 and 09-03 complete — 353 tests pass
**Resume file:** `.planning/notes/weak-hash-companion-exploration.md`
**Next action:** 09-02 (unsupported-hex reporting, narrowed — 40 hex is supported now, so it covers 56/96/other lengths). Phase 8 (Manifest Spot-Check) remains unplanned.
