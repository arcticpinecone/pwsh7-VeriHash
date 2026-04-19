# Roadmap — VeriHash

## Shipped Milestones

- ✅ **v2.0 Modular Rebuild** (2026-04-19) — 5 phases, 15 plans, 38/38 requirements. [Full archive →](milestones/v2.0-ROADMAP.md)
- ✅ **v1.0 Privacy + Foundation** (2026-04-18) — 3 phases, 6 plans, 11/11 requirements. [Full archive →](milestones/v1.0-ROADMAP.md)

## Next Milestone

_Not yet planned. Use `/gsd-new-milestone` to start._

## Backlog

### Phase 999.6: Sidecar auto-detect — right-click .sha256 verifies companion

When a `.sha256`/`.sha512`/`.md5` file is passed (with or without `-Manifest`), auto-detect:
- 1 non-blank line → sidecar mode: verify companion file against stored hash
- Multiple lines → manifest mode: verify all entries

Currently, right-clicking a sidecar hashes the text file itself (useless). Users expect verification.

See: `.planning/notes/sidecar-autodetect-exploration.md`

### Phase 999.5: Output formatting — rich single-file report + batch table

Redesign VeriHash output presentation with two modes:
- **Single-file:** Rich sectioned report with `[Metadata]`, `[Hash]`, `[Signature]`, `[Verification]` headers, friendly dates, hash speed, start/end timestamps, clean dividers.
- **Batch:** Compact `Format-Table` with auto-fit columns (File, Size, Hash, Time, Speed, Status), coloured tally, totals.

Consistent 6-colour palette (Green/Red/Yellow/Cyan/Gray/White). No emoji. No magenta.

See: `.planning/notes/output-formatting-exploration.md`

### Phase 999.4: Manifest spot-check — single-file verify against existing manifest

When a single file is passed with `-Manifest` and a manifest already exists in the same directory, auto-detect and verify just that entry instead of creating a new manifest. Enables "right-click one ISO → confirm it matches the snapshot" workflow without re-hashing all files.

**Key decisions needed:**
- Auto-detect (manifest present → spot-check) vs explicit flag
- Multiple manifests in directory: pick most recent? Ask?
- File not in manifest: clear "not found in manifest" error

Depends on: SendTo multi-file bug fix (todo)

### Phase 999.2: VeriHash.BatchResult default format view — ✅ RESOLVED

Resolved in commit `e7bb55a`. Added `VeriHash.HotPath.format.ps1xml` with `FormatsToProcess` in manifest.

### Phase 999.3: Silence Test-ModuleManifest RequiredModules warnings — ✅ RESOLVED

Resolved in commit `e7bb55a`. Added repo root to `$env:PSModulePath` in test setup.
