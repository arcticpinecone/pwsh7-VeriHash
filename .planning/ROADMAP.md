# Roadmap — VeriHash

## Shipped Milestones

- ✅ **v2.0 Modular Rebuild** (2026-04-19) — 5 phases, 15 plans, 38/38 requirements. [Full archive →](milestones/v2.0-ROADMAP.md)
- ✅ **v1.0 Privacy + Foundation** (2026-04-18) — 3 phases, 6 plans, 11/11 requirements. [Full archive →](milestones/v1.0-ROADMAP.md)

## v3.0 — UX Polish & Smart Routing

**Milestone goal:** Make VeriHash smarter about user intent on right-click, and give output a polished presentation.

### Phases

- [x] **Phase 6: Sidecar Auto-Detect** — Right-clicking `.sha256`/`.sha512`/`.md5` verifies the companion file instead of hashing the sidecar
- [x] **Phase 7: Output Formatting** — Verdict banner, stacked hash comparison, and checklist grid in truecolor, with a compact batch view
- [ ] **Phase 8: Manifest Spot-Check** — Single-file verify against existing manifest in same directory

### Phase Details

#### Phase 6: Sidecar Auto-Detect

**Goal**: Right-clicking a hash-extension file verifies the companion file instead of uselessly hashing the sidecar text
**Depends on**: Phase 5 (v2.0 complete)
**Requirements**: SIDE-01, SIDE-02, SIDE-03, SIDE-04, SIDE-05, SIDE-06
**Success Criteria** (what must be TRUE):

  1. Right-clicking a single-line `.sha256` sidecar file verifies the companion file's hash — not the sidecar text file itself
  2. Right-clicking a multi-line `.sha256` file triggers manifest verification of all entries
  3. Companion file is resolved relative to the sidecar's directory, not the current working directory
  4. Clear, actionable error messages appear when companion file doesn't exist or sidecar file is empty
  5. Behaviour is identical whether the sidecar file is passed with or without the `-Manifest` flag
**Plans:** 2 plans

Plans:

- [x] 06-01-PLAN.md — Core Invoke-VeriHashSidecarDetect function + unit tests (TDD)
- [x] 06-02-PLAN.md — CLI dispatch integration + E2E tests (SIDE-06)

See: `.planning/notes/sidecar-autodetect-exploration.md`

#### Phase 7: Output Formatting

**Goal**: The verdict is legible at a glance — a reversed-video banner carries it, and everything else (hash comparison, checklist, footer) supports it
**Depends on**: Phase 6 (routing must be solid before reformatting output)
**Requirements**: FMT-01, FMT-02, FMT-03, FMT-04, FMT-05, FMT-06, FMT-07
**Success Criteria** (what must be TRUE):

  1. Single-file mode renders header, verdict banner, stacked hash comparison, checklist grid, and footer — in that order
  2. A MISMATCH highlights the diverging 8-char hash groups on both lines, names the divergence character, and shows the `Recommendation: Do not run this file.` advisory
  3. A MISMATCH never writes or updates a sidecar file
  4. Batch mode renders each file compactly and closes with the middot tally, while `BatchResult.TallyLine` stays byte-locked
  5. Output is legible with `NO_COLOR` set and on a non-UTF-8 code page
**Plans**: 1 plan

Plans:

- [x] 07-01-PLAN.md — Console output redesign: palette, banner, hash comparison, checklist, batch tally

See: `HANDOFF-console-spec.md` (supersedes `.planning/notes/output-formatting-exploration.md`)

#### Phase 8: Manifest Spot-Check

**Goal**: Right-clicking a single file when a manifest exists in the same directory verifies just that file's entry — no full re-hash
**Depends on**: Phase 6 (manifest routing must be solid)
**Requirements**: SPOT-01, SPOT-02, SPOT-03, SPOT-04, SPOT-05
**Success Criteria** (what must be TRUE):

  1. Passing a single file with `-Manifest` when a manifest exists in the same directory spot-checks that file against the manifest entry instead of creating a new manifest
  2. Only the single target file is hashed and compared — the rest of the manifest is not re-verified
  3. Clear pass/fail report shows the expected hash, computed hash, and match result for the single entry
  4. "File not found in manifest" error appears when the file has no entry in the existing manifest

See: `.planning/notes/manifest-exploration.md`

#### Phase 9: Comparator Correctness

**Goal**: A verdict is never stronger than the evidence behind it, and the algorithm VeriHash computes is the one the user asked about
**Depends on**: Phase 7 (the renderer and comparator this corrects). Numbered after Phase 8 but **not** behind it in execution order — 09-01 fixes live bugs in shipped output
**Requirements**: CMP-01 … CMP-14, FMT-05 (amended), FMT-07 (extended)
**Success Criteria** (what must be TRUE):

  1. An MD5 on the clipboard during a SHA256 run of an intact file produces no MISMATCH banner, no advisory, and no suppressed sidecar write
  2. Comparator selection exists in exactly one place, reachable from both modules at runtime
  3. A hash the user supplied but VeriHash could not compare produces a yellow `UNVERIFIED` banner, distinct from both `MISMATCH` and `HASHED`
  4. No file that any check proved bad ever has a sidecar written or overwritten for it
  5. A batch containing unverified files reports them as unverified on `Tally` and in the rendered summary — never as `missing`, never silently as `matched`
  6. `BatchResult.TallyLine` keeps its byte-locked format string and its numbers
  7. No run writes to the path of the file it was asked to verify, under any algorithm value
  8. With no explicit `-Algorithm`, a supported clipboard hash determines the algorithm the file is hashed with, reads the file once, and leaves every sidecar untouched
  9. `VeriHash.ps1 <file> -Algorithm SHA512` computes SHA512 and writes `.sha512`

Plans:

- [x] 09-01 — Comparator extraction, algorithm guard, `UNVERIFIED` state, sidecar-write suppression, `MatchResult` unverified, FMT-05 advisory
- [ ] 09-02 — Unsupported-hex reporting (CMP-10) — narrowed: 40 hex is supported now, so this covers 56/96/other lengths
- [x] 09-03 — Clipboard tolerance, clipboard-driven algorithm, SHA256 companion, SHA1 support, CLI `-Algorithm` (CMP-04, 06, 07, 08, 13, 15–19)

See: `.planning/notes/comparator-algorithm-exploration.md` and
`.planning/notes/weak-hash-companion-exploration.md` (which supersedes the
former's Step 2 sidecar rule).

### Progress

| Phase | Plans Complete | Status | Completed |
| ------- | ---------------- | -------- | ----------- |
| 6. Sidecar Auto-Detect | 2/2 | ✅ Complete | 2026-04-20 |
| 7. Output Formatting | 1/1 | ✅ Complete | 2026-08-15 |
| 8. Manifest Spot-Check | 0/TBD | Not started | - |
| 9. Comparator Correctness | 1/3 | In progress | - |

## Backlog (Resolved)

### Phase 999.1: PSFramework missing notification — STALE (removed v2.0)

Removed: v2.0 replaced PSFramework with custom logging. No longer applicable.

### Phase 999.2: VeriHash.BatchResult default format view — ✅ RESOLVED

Resolved in commit `e7bb55a`. Added `VeriHash.HotPath.format.ps1xml` with `FormatsToProcess` in manifest.

### Phase 999.3: Silence Test-ModuleManifest RequiredModules warnings — ✅ RESOLVED

Resolved in commit `e7bb55a`. Added repo root to `$env:PSModulePath` in test setup.
