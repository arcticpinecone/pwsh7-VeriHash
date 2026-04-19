# Roadmap — VeriHash

## Shipped Milestones

- ✅ **v2.0 Modular Rebuild** (2026-04-19) — 5 phases, 15 plans, 38/38 requirements. [Full archive →](milestones/v2.0-ROADMAP.md)
- ✅ **v1.0 Privacy + Foundation** (2026-04-18) — 3 phases, 6 plans, 11/11 requirements. [Full archive →](milestones/v1.0-ROADMAP.md)

## v2.1 — UX Polish & Smart Routing

**Milestone goal:** Make VeriHash smarter about user intent on right-click, and give output a polished presentation.

### Phases

- [ ] **Phase 6: Sidecar Auto-Detect** — Right-clicking `.sha256`/`.sha512`/`.md5` verifies the companion file instead of hashing the sidecar
- [ ] **Phase 7: Output Formatting** — Rich sectioned single-file report + compact batch table with 6-colour palette
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
**Plans**: TBD

See: `.planning/notes/sidecar-autodetect-exploration.md`

#### Phase 7: Output Formatting
**Goal**: VeriHash output is scannable, sectioned, and colour-coded — rich report for single files, compact table for batches
**Depends on**: Phase 6 (routing must be solid before reformatting output)
**Requirements**: FMT-01, FMT-02, FMT-03, FMT-04, FMT-05, FMT-06, FMT-07
**Success Criteria** (what must be TRUE):
  1. Single-file mode displays a sectioned report with `[Metadata]`, `[Hash]`, `[Signature]`, `[Verification]` headers showing path, size, friendly dates, hash speed, and timestamps
  2. Batch mode displays a compact table with File, Size, Hash preview (12 chars), Time, Speed, and Status columns plus a coloured tally line
  3. All output uses a consistent 6-colour palette (Green=pass, Red=fail, Yellow=warning, Cyan=info, Gray=timestamps, White=emphasis) with zero emoji characters
  4. Report includes UTC start timestamp at top and completed timestamp with total elapsed time at bottom
**Plans**: TBD

See: `.planning/notes/output-formatting-exploration.md`

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

### Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 6. Sidecar Auto-Detect | 0/TBD | Not started | - |
| 7. Output Formatting | 0/TBD | Not started | - |
| 8. Manifest Spot-Check | 0/TBD | Not started | - |

## Backlog (Resolved)

### Phase 999.1: PSFramework missing notification — STALE (removed v2.0)

Removed: v2.0 replaced PSFramework with custom logging. No longer applicable.

### Phase 999.2: VeriHash.BatchResult default format view — ✅ RESOLVED

Resolved in commit `e7bb55a`. Added `VeriHash.HotPath.format.ps1xml` with `FormatsToProcess` in manifest.

### Phase 999.3: Silence Test-ModuleManifest RequiredModules warnings — ✅ RESOLVED

Resolved in commit `e7bb55a`. Added repo root to `$env:PSModulePath` in test setup.
