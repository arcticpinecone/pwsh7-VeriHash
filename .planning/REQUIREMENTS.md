# Requirements: VeriHash

**Defined:** 2026-04-19
**Core Value:** Trustworthy file integrity verification — fast, scriptable, privacy-respecting.

## v2.1 Requirements

Requirements for v2.1 UX Polish & Smart Routing. Each maps to roadmap phases.

### Sidecar Auto-Detect

- [ ] **SIDE-01**: When a single `.sha256`/`.sha512`/`.md5` file is passed, auto-detect: 1 non-blank line → sidecar verify, multiple lines → manifest verify
- [ ] **SIDE-02**: Sidecar companion resolution: GNU format (`hash *filename`) → filename from line; bare hash → strip hash extension from sidecar filename
- [ ] **SIDE-03**: Companion file resolved relative to sidecar's directory, not CWD
- [ ] **SIDE-04**: Clear error when companion file doesn't exist: "Companion file not found: {name}"
- [ ] **SIDE-05**: Clear error when sidecar file is empty
- [ ] **SIDE-06**: `.sha256`/`.sha512`/`.md5` files passed with `-Manifest` flag also auto-detect (unified behaviour)

### Output Formatting

- [ ] **FMT-01**: Single-file mode shows rich sectioned report with `[Metadata]`, `[Hash]`, `[Signature]`, `[Verification]` section headers
- [ ] **FMT-02**: Report includes file metadata: path, human-readable size, friendly dates (Created/Modified in `MMMM d, yyyy | HH:mm:ss`)
- [ ] **FMT-03**: Report includes hash speed (MB/s) and hash time (seconds + milliseconds)
- [ ] **FMT-04**: Report includes UTC start timestamp at top and completed timestamp + total time at bottom
- [ ] **FMT-05**: Batch mode shows compact table with File, Size, Hash preview (12 chars), Time, Speed, Status columns
- [ ] **FMT-06**: 6-colour palette applied consistently: Green (pass), Red (fail), Yellow (warning), Cyan (info/labels), Gray (timestamps), White (emphasis)
- [ ] **FMT-07**: No emoji characters in any output (terminal-safe)

### Manifest Spot-Check

- [ ] **SPOT-01**: With `-Manifest` and a single file, auto-detect existing manifest in same directory and spot-check instead of creating
- [ ] **SPOT-02**: Entry lookup: find the matching filename in the existing manifest
- [ ] **SPOT-03**: Hash just that one file and compare against the manifest entry
- [ ] **SPOT-04**: Clear pass/fail report for the single-entry check
- [ ] **SPOT-05**: "File not found in manifest" error when the entry doesn't exist in the manifest

## Future Requirements

_None deferred from v2.1._

## Out of Scope

| Feature | Reason |
|---------|--------|
| Recursive folder hashing for manifests | Manifest MVP is flat-files-in-one-directory; deferred from v2.0 |
| Multiple-manifest disambiguation | v2.1 picks the most recent manifest; interactive selection deferred |
| Custom colour themes | 6-colour palette is hardcoded; user customisation deferred |
| Batch progress bar | Compact table is sufficient for v2.1; live progress deferred |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SIDE-01 | Phase 6 | Pending |
| SIDE-02 | Phase 6 | Pending |
| SIDE-03 | Phase 6 | Pending |
| SIDE-04 | Phase 6 | Pending |
| SIDE-05 | Phase 6 | Pending |
| SIDE-06 | Phase 6 | Pending |
| FMT-01 | Phase 7 | Pending |
| FMT-02 | Phase 7 | Pending |
| FMT-03 | Phase 7 | Pending |
| FMT-04 | Phase 7 | Pending |
| FMT-05 | Phase 7 | Pending |
| FMT-06 | Phase 7 | Pending |
| FMT-07 | Phase 7 | Pending |
| SPOT-01 | Phase 8 | Pending |
| SPOT-02 | Phase 8 | Pending |
| SPOT-03 | Phase 8 | Pending |
| SPOT-04 | Phase 8 | Pending |
| SPOT-05 | Phase 8 | Pending |

**Coverage:**
- v2.1 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-19*
*Last updated: 2026-04-19 after initial definition*
