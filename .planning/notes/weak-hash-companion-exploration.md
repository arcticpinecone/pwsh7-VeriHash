---
title: Answering a weak hash without withholding the strong one
date: 2026-08-16
context: Field report — a space-grouped SHA256 read as an empty clipboard, and a vendor-supplied MD5 could not be checked at all
supersedes: the Step 2 decision table in comparator-algorithm-exploration.md
---

# Weak-Hash Companion & Clipboard Tolerance

## Two problems, one root attitude

Both defects come from the same posture: VeriHash decided what shape a
question had to arrive in, and refused everything else.

1. **A space-grouped SHA256 read as an empty clipboard.** Fixed already; see
   *Clipboard tolerance* below.
2. **A vendor-supplied MD5 cannot be checked at all.** VeriHash computes
   SHA256, cannot compare, and reports `UNVERIFIED`. The user holds the only
   hash the vendor published and VeriHash declines to use it.

Problem 2 is the expensive one. Some vendors still publish MD5, and a few
still publish SHA1. The user cannot control that. Refusing to answer teaches
them that VeriHash is not the tool for the download they actually have, which
costs more trust than any weak-algorithm caveat could.

## Clipboard tolerance (shipped)

`ConvertTo-VeriHashAlgorithm` required a contiguous hex run, so any internal
whitespace made a digest invisible. This was never a regression — the same
regex shipped in `87fc78e` (Phase 01-02). What changed is that Phase 7 taught
the report to **print** hashes in 8-character groups without teaching anything
to **read** them, so VeriHash's own output could not round-trip through its own
clipboard reader.

`ConvertTo-VeriHashHexCandidate` (new, private) normalises pasted text into one
canonical string before any inference happens. It accepts bare hex, vendor
labels (`SHA-256: <hex>`), sha256sum lines (`<hex> *name`), certutil's 2-char
groups, and VeriHash's own 8-char groups including the line wrap a SHA512
always produces.

**It refuses to join whitespace when the tokens are not a uniform split of one
digest.** Two 64-hex digests on the clipboard concatenate to 128 characters and
would otherwise infer as a single SHA512 — a comparator assembled from two
unrelated hashes, which the file would then be judged against. A token that is
itself a full digest length is the tell: groups are fragments (2, 4, 8
characters), so a 32-character token means the clipboard holds a *list*.

The normaliser emits a canonical **string**, not a parsed record, so
`ConvertTo-VeriHashAlgorithm` keeps sole ownership of the prefix-versus-length
check. Restating that rule at a second call site is precisely how the 09-01 bug
happened.

## Primary and companion

**Primary** — the algorithm the verdict is about:

```text
explicit -Algorithm  >  supported clipboard hash  >  SHA256 default
```

**Companion** — SHA256, computed automatically **iff the primary is weak**
(`MD5` or `SHA1`), however the primary was chosen. An explicit
`-Algorithm MD5` gets the companion too: the user asked for MD5, not for the
absence of SHA256.

| Primary | Companion | Why |
| --- | --- | --- |
| MD5 | SHA256 | answer the question; supply the strong digest anyway |
| SHA1 | SHA256 | same |
| SHA256 | — | it *is* the companion |
| SHA512 | — | stronger than SHA256; a second pass would teach nothing |

At most two digests, ever. The common no-clipboard run is unchanged: one
SHA256 pass, one `.sha256`.

### What this supersedes

`comparator-algorithm-exploration.md`'s Step 2 decision table says a
clipboard-selected algorithm computes that algorithm **alone** and leaves every
sidecar untouched. That row is replaced:

| Situation | Old | New |
| --- | --- | --- |
| Clipboard MD5, no flag | compute MD5; touch no sidecar | compute MD5 **+ SHA256**; write `.sha256` |

The old rule existed to stop a vendor's weak choice from downgrading the
durable local record. That concern is met more directly here: the sidecar is
**always** SHA256, so `.md5` and `.sha1` are never written at all.

## Sidecar policy

The sidecar is always derived from the **SHA256** digest — primary or
companion — and is always `.sha256`. `.md5` and `.sha1` are never written.

This matters beyond tidiness: `Get-PreferredSidecar` ranks `.sha512 > .sha256 >
.md5`, so a `.md5` written once would be a weak file that a *later* run could
promote to the trusted comparator. Never writing it closes that path.

Suppression is unchanged and still keys off all negative evidence: a
mismatching primary or a `SidecarStatus` of `mismatch` blocks the write. A file
whose MD5 failed does not get a `.sha256` minted for it.

`-Algorithm SHA512` still writes `.sha512`. Only a **weak** primary redirects
the sidecar to the companion's `.sha256`.

## CMP-13 is satisfied rather than mitigated

`comparator-algorithm-exploration.md` worried that a clipboard-selected MD5
would make `Test-VeriHashSidecar` re-hash the file to answer a `.sha256`
sidecar — a second full pass on the exact workflow the `-ComputedResult`
plumbing was added to protect. Its answer was to pin the sidecar check to the
run's algorithm and accept losing the `.sha256` row.

That trade is no longer necessary. A weak run now **always** holds a SHA256, so
the sidecar check is pinned to SHA256 and served free from the companion
digest. The row survives and the file is still read once per digest.

## Rendering

The banner answers the user's actual question — the primary. The companion gets
its own labelled block so SHA256 is on screen every run without competing for
the verdict.

```text
VeriHash 2.0 · MD5 (clipboard) + SHA256 · Docker Desktop Installer.exe (596.18 MB)

  ✓  MATCH — MD5 matches hash on clipboard

expected  clipboard
5417cedc 1aeb16b4 88b80840 25246b64
computed  1179 ms
5417cedc 1aeb16b4 88b80840 25246b64

sha256    2018 ms
9f2b1a44 6c30e7d1 4b8e0a35 c7d21f60 8ae4b913 20fc55d7 e1a3b846 7c0d9e22

clipboard   ✓ match (plain hex, MD5 — weak; prefer SHA256 if the vendor lists one)
sidecar     ✓ created — Docker Desktop Installer.exe.sha256
signature   ✓ valid — Docker Inc
elapsed     2104 ms total · 2018 ms hashing · 596.18 MB · ~295 MB/s
```

- **Header** names both algorithms and attributes the primary when the
  clipboard chose it. A user reading grouped hex by eye otherwise has no signal
  telling them which algorithm is on screen.
- **Weak clause** on the clipboard row (CMP-07, specified in 09-01 and never
  built) fires on match *and* mismatch. It never touches the banner: a
  successful MD5 comparison is green. Yellow means *your question went
  unanswered*, and a permanent yellow a user cannot clear is wallpaper.
- **Companion block** is suppressed in `-Compact` (batch) mode along with the
  rest of the hash block.

## Concurrency

A second `Start-ThreadJob` alongside the existing hash and signature jobs. The
orchestrator already collects with `Wait-Job -Any`; the companion joins that
set and the render still waits for everything.

Measured on a 500 MB file (`VeriHash.Timing.Tests.ps1`): MD5 1179 ms, SHA256
1724 ms, SHA512 1351 ms. Two parallel readers land near the slower of the pair
because the OS file cache serves the second — roughly 1.8 s against 1.7 s for
SHA256 alone. A genuine second read is paid only on files larger than RAM.

*Deferred, unchanged:* the single-pass `IncrementalHash` fan-out via `Add-Type`.
It reads once at any size and is the prerequisite for `-Algorithm All`. Build it
when `All` returns; the companion rule does not depend on it.

## SHA1 becomes real

`Get-FileHash` supports SHA1, so nothing blocks it but our own `ValidateSet`s.
It joins the supported set in `Get-VeriHashHexLength` (40), both modules'
parameter sets, and `ConvertTo-VeriHashAlgorithm`'s length inference.

CMP-10's planned message — `looks like SHA-1, which VeriHash does not support`
— is deleted rather than written. The unsupported-hex work that remains is
genuinely unsupported lengths (56 → SHA-224, 96 → SHA-384, and the rest).

SHA1 is weak, so it takes the companion and never gets a sidecar. It is
accepted as an *answer to a question*, never as a durable record.

## Requirements

- **CMP-15**: A weak primary algorithm (MD5, SHA1) is computed **and** a SHA256
  companion is computed in the same run
- **CMP-16**: The sidecar is always `.sha256`; `.md5` and `.sha1` are never
  written under any algorithm selection
- **CMP-17**: SHA1 is a fully supported algorithm — hashable, comparable, and
  inferrable from a 40-character paste
- **CMP-18**: The header names every algorithm computed and attributes the
  primary when the clipboard selected it
- **CMP-19**: Whitespace-grouped, labelled, and sha256sum-formatted pastes are
  recognised; whitespace is never joined across what may be two separate digests
- **CMP-07** (finally built): an MD5 or SHA1 comparison is labelled weak on the
  clipboard row, on both match and mismatch, and never on the banner
- **CMP-13** (satisfied): a weak run reads the file once per digest and no more

## Success criteria

1. A clipboard MD5 on an intact file produces a green `MATCH` on the MD5, a
   SHA256 on screen, and a `.sha256` on disk
2. A clipboard SHA1 does the same
3. A clipboard MD5 on a corrupt file produces `MISMATCH` and **no** sidecar
4. No run writes `.md5` or `.sha1`, under any algorithm selection
5. A SHA256 or SHA512 primary computes exactly one digest — no wasted pass
6. `VeriHash.ps1 <file> -Algorithm SHA512` computes SHA512 and writes `.sha512`
7. A weak batch algorithm companions every file; a clipboard hash never selects
   the algorithm in batch mode
8. Existing golden-text output for `MATCH` / `MISMATCH` / `HASHED` /
   `UNVERIFIED` is byte-identical when no companion runs
9. `BatchResult.TallyLine` keeps its format string and its numbers

## Files touched

| File | Why |
| --- | --- |
| `VeriHash.Core/Private/ConvertTo-VeriHashHexCandidate.ps1` | new — clipboard tolerance (shipped) |
| `VeriHash.Core/Public/Read-ClipboardHash.ps1` | use the normaliser (shipped) |
| `VeriHash.Core/Private/ConvertTo-VeriHashAlgorithm.ps1` | SHA1 inference |
| `VeriHash.Core/Private/Get-VeriHashHexLength.ps1` | SHA1 = 40 |
| `VeriHash.Core/Private/Format-VeriHashChecklist.ps1` | weak clause on the clipboard row |
| `VeriHash.Core/Public/Format-VeriHashReport.ps1` | header attribution, companion block |
| `VeriHash.Core/Public/Resolve-VeriHashComparator.ps1` | SHA1 in the `ValidateSet` |
| `VeriHash.Core/Public/Test-VeriHashSidecar.ps1` | optional `-Algorithm` pin |
| `VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1` | selection, companion job, sidecar redirect |
| `VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1` | SHA1 in the `ValidateSet` |
| `VeriHash.ps1` | `-Algorithm` flag + help banner |
| `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md` | CMP-15…CMP-19 |

## Explicitly out of scope

Unchanged from `comparator-algorithm-exploration.md`: single-pass fan-out,
`-Algorithm All`, SHA3/BLAKE, escalate-on-mismatch, batch-mode clipboard
semantics, and the exit-code todo. None of them are prerequisites here.
