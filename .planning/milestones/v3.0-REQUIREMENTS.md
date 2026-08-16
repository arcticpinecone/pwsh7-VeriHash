# Requirements: VeriHash

**Defined:** 2026-04-19
**Core Value:** Trustworthy file integrity verification — fast, scriptable, privacy-respecting.

## v3.0 Requirements

Requirements for v3.0 UX Polish & Smart Routing. Each maps to roadmap phases.

### Sidecar Auto-Detect

- [x] **SIDE-01**: When a single `.sha256`/`.sha512`/`.md5` file is passed, auto-detect: 1 non-blank line → sidecar verify, multiple lines → manifest verify
- [x] **SIDE-02**: Sidecar companion resolution: GNU format (`hash *filename`) → filename from line; bare hash → strip hash extension from sidecar filename
- [x] **SIDE-03**: Companion file resolved relative to sidecar's directory, not CWD
- [x] **SIDE-04**: Clear error when companion file doesn't exist: "Companion file not found: {name}"
- [x] **SIDE-05**: Clear error when sidecar file is empty
- [x] **SIDE-06**: `.sha256`/`.sha512`/`.md5` files passed with `-Manifest` flag also auto-detect (unified behaviour)

### Output Formatting

- [x] **FMT-01**: Single-file mode opens with a one-line header: `VeriHash 3.0 · {ALGO} · {filename} ({size})`
- [x] **FMT-02**: A full-width reversed-video verdict banner states MATCH / MISMATCH / HASHED, with blank lines above and below
- [x] **FMT-03**: Expected and computed hashes render stacked, in 8-character groups, with mismatching groups highlighted and the divergence character reported
- [x] **FMT-04**: A four-row checklist grid reports clipboard, sidecar, signature, and elapsed (ms · size · throughput)
- [x] **FMT-05**: A dim footer gives the full path and UTC modified time; MISMATCH additionally shows the advisory `Recommendation: Do not run this file. Re-download it, then verify again.`
- [x] **FMT-06**: Batch mode renders each file compactly and closes with `batch of N · x matched · y mismatch · z missing`, while `BatchResult.TallyLine` keeps its byte-locked legacy format
- [x] **FMT-07**: Output degrades cleanly: `NO_COLOR` disables all colour, a non-UTF-8 code page falls back to ASCII glyphs, and no emoji are used anywhere

### Comparator Correctness

- [x] **CMP-01**: Comparator selection lives in exactly one function; `Format-VeriHashReport` and `Invoke-VeriHashHotPath` both call it rather than restating the rule
- [x] **CMP-02**: A clipboard hash whose algorithm differs from the computed algorithm is never compared, never reported as MISMATCH, and never on its own causes a sidecar write to be suppressed
- [x] **CMP-03**: A clipboard hash that cannot be used is rendered honestly in banner and checklist — it is not reported as an absent clipboard, and the sidecar is not silently substituted for it
- [x] **CMP-09**: A fourth verdict state `UNVERIFIED` renders in yellow when the user supplied a hash that could not be compared
- [x] **CMP-11**: A sidecar is never written or overwritten for a file that any check proved bad. Suppression is keyed off the comparator's verdict *and* `SidecarStatus`, not off the banner state alone
- [x] **CMP-12**: `MatchResult` distinguishes *verified and equal* from *not verified*; a batch exposes the unverified count on `BatchResult.Tally`, and every per-file line and summary count reports unverified files as unverified rather than as missing
- [x] **CMP-14**: A value outside a closed set never resolves to a silent fallback — an unmapped algorithm never yields a sidecar path equal to the target file, and an unhandled banner state never renders an empty bar
- [x] **CMP-04**: When no explicit `-Algorithm` is given, a recognised clipboard hash selects the algorithm the file is hashed with
- [x] ~~**CMP-05**: A clipboard-selected algorithm writes no sidecar and modifies no existing sidecar~~ — **superseded by CMP-16.** The concern (a vendor's weak choice leaving a weak permanent record) is met by never writing `.md5`/`.sha1` at all, which is stronger than writing nothing
- [x] **CMP-06**: The header names the algorithm actually computed, and attributes it when the clipboard selected it
- [x] **CMP-07**: An MD5 or SHA1 comparison is labelled weak in the clipboard row, on both match and mismatch, and never on the banner
- [x] **CMP-08**: `VeriHash.ps1` accepts `-Algorithm MD5|SHA1|SHA256|SHA512` and passes it through only when bound; batch mode always passes an explicit algorithm
- [x] **CMP-10**: A clipboard holding plausible but unsupported hex is reported as such, naming the likely algorithm where the length is well known, and is never reported as an empty or unrecognisable clipboard — *narrowed by CMP-17: 40 hex is now supported, so this covers 56 (SHA-224), 96 (SHA-384), and other lengths*
- [x] **CMP-13**: A weak-primary run does not cause the file to be read a second time — the sidecar check is pinned to SHA256 and served from the companion digest
- [x] **CMP-15**: A weak primary algorithm (MD5, SHA1) is computed **and** a SHA256 companion is computed in the same run
- [x] **CMP-16**: The sidecar is always `.sha256` (or `.sha512` under an explicit SHA512); `.md5` and `.sha1` are never written under any algorithm selection
- [x] **CMP-17**: SHA1 is a fully supported algorithm — hashable, comparable, and inferrable from a 40-character paste
- [x] **CMP-18**: The header names every algorithm computed and attributes the primary when the clipboard selected it
- [x] **CMP-19**: Whitespace-grouped, vendor-labelled, and sha256sum-formatted pastes are recognised; whitespace is never joined across what may be two separate digests

## Future Requirements

### Manifest Spot-Check — deferred from v3.0

Deferred 2026-08-16. Spot-check is additive: nothing VeriHash currently reports
is wrong without it, and a user can already verify a whole manifest. v3.0's
other three phases shipped, so holding the release for an unplanned feature
would delay correctness fixes that are done in exchange for convenience that is
not started.

- [ ] **SPOT-01**: With `-Manifest` and a single file, auto-detect existing manifest in same directory and spot-check instead of creating
- [ ] **SPOT-02**: Entry lookup: find the matching filename in the existing manifest
- [ ] **SPOT-03**: Hash just that one file and compare against the manifest entry
- [ ] **SPOT-04**: Clear pass/fail report for the single-entry check
- [ ] **SPOT-05**: "File not found in manifest" error when the entry doesn't exist in the manifest

## Out of Scope

| Feature | Reason |
| --------- | -------- |
| Recursive folder hashing for manifests | Manifest MVP is flat-files-in-one-directory; deferred from v2.0 |
| Multiple-manifest disambiguation | v3.0 picks the most recent manifest; interactive selection deferred |
| Custom colour themes | 6-colour palette is hardcoded; user customisation deferred |
| Batch progress bar | Compact table is sufficient for v3.0; live progress deferred |

## Traceability

| Requirement | Phase | Status |
| ------------- | ------- | -------- |
| SIDE-01 | Phase 6 | Complete |
| SIDE-02 | Phase 6 | Complete |
| SIDE-03 | Phase 6 | Complete |
| SIDE-04 | Phase 6 | Complete |
| SIDE-05 | Phase 6 | Complete |
| SIDE-06 | Phase 6 | Complete |
| FMT-01 | Phase 7 | Complete |
| FMT-02 | Phase 7 | Complete |
| FMT-03 | Phase 7 | Complete |
| FMT-04 | Phase 7 | Complete |
| FMT-05 | Phase 7 | Complete |
| FMT-06 | Phase 7 | Complete |
| FMT-07 | Phase 7 | Complete |
| CMP-01 | Phase 9 | Complete |
| CMP-02 | Phase 9 | Complete |
| CMP-03 | Phase 9 | Complete |
| CMP-04 | Phase 9 | Complete |
| CMP-05 | Phase 9 | Superseded by CMP-16 |
| CMP-06 | Phase 9 | Complete |
| CMP-07 | Phase 9 | Complete |
| CMP-08 | Phase 9 | Complete |
| CMP-09 | Phase 9 | Complete |
| CMP-10 | Phase 9 | Complete |
| CMP-11 | Phase 9 | Complete |
| CMP-12 | Phase 9 | Complete |
| CMP-13 | Phase 9 | Complete |
| CMP-14 | Phase 9 | Complete |
| CMP-15 | Phase 9 | Complete |
| CMP-16 | Phase 9 | Complete |
| CMP-17 | Phase 9 | Complete |
| CMP-18 | Phase 9 | Complete |
| CMP-19 | Phase 9 | Complete |
| SPOT-01 | Deferred | Deferred |
| SPOT-02 | Deferred | Deferred |
| SPOT-03 | Deferred | Deferred |
| SPOT-04 | Deferred | Deferred |
| SPOT-05 | Deferred | Deferred |

**Coverage:**

- v3.0 requirements: 37 total (13 defined at kickoff, 19 added by Phase 9, 5 deferred)
- Shipped: 32 — SIDE 6/6, FMT 7/7, CMP 19/19 (CMP-05 superseded by CMP-16)
- Deferred to a later milestone: 5 — SPOT-01..05
- Unmapped: 0 ✓

> The counts above were 18/18/0 until 2026-08-16. Phase 9 was added after this
> document was written and its 19 CMP requirements were never traced, while
> SIDE and FMT stayed marked Pending long after both phases shipped. The
> milestone read as 67% complete when it was substantially further along.

---
*Requirements defined: 2026-04-19*
*Last updated: 2026-08-16 — traced Phase 9, ticked shipped SIDE/FMT, deferred SPOT*
