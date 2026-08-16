---
title: Comparator correctness and clipboard-driven algorithm selection
date: 2026-08-16
context: Post-Phase-7 field report — an MD5 on the clipboard produced a false MISMATCH on an intact 596 MB installer
---

# Comparator Correctness & Clipboard-Driven Algorithm

## Problem

A user copied an **MD5** hash to the clipboard, then ran VeriHash on `Docker Desktop Installer.exe` (596 MB). VeriHash computed SHA256, compared the 32-character MD5 against the 64-character SHA256, and reported:

```text
  ✗  MISMATCH — file does NOT match clipboard hash
first 0 of 64 characters agree — divergence starts at character 1
sidecar     ✓ match — Docker Desktop Installer.exe.sha256
```

Three things went wrong, in increasing order of severity:

1. **A meaningless diff line.** `first 0 of 64 characters agree` is the output of comparing strings of different lengths. There is no character position at which an MD5 and a SHA256 could ever agree.
2. **The report contradicted itself.** The checklist reported `sidecar ✓ match` — the file was *provably intact* — while the banner above it declared MISMATCH. The report contained the correct answer and the banner overruled it with weaker evidence.
3. **The tool told the user to destroy a good file.** The MISMATCH advisory (`Do not run this file. Re-download it, then verify again.`) fired on a file that had just passed sidecar verification, and [Invoke-VeriHashHotPath.ps1:138](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L138) suppressed the sidecar write on the strength of that verdict.

For a verification tool, a **false MISMATCH is the most expensive failure mode over time**. A false MATCH is worse per incident, but a false MISMATCH teaches the user that the red banner is noise — which disarms every true mismatch that follows.

## Root cause

The comparator-selection rule is written down **twice**, and the two copies disagree.

`Format-VeriHashReport` guards the sidecar branch and leaves the clipboard branch unguarded:

- [Format-VeriHashReport.ps1:54-56](../../VeriHash.Core/Public/Format-VeriHashReport.ps1#L54-L56) — clipboard branch takes `$CompareTo.Hash` unconditionally. **No algorithm check.**
- [Format-VeriHashReport.ps1:57-58](../../VeriHash.Core/Public/Format-VeriHashReport.ps1#L57-L58) — sidecar branch guards `$SidecarInfo.Algorithm -eq $Result.Algorithm`, with an inline comment explaining precisely why cross-algorithm comparison produces false alarms.

`Invoke-VeriHashHotPath` reproduces the same rule by hand, with the same omission:

- [Invoke-VeriHashHotPath.ps1:116-120](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L116-L120) — a comment stating `Mirrors Format-VeriHashReport's comparator rule exactly`.
- [Invoke-VeriHashHotPath.ps1:122-126](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L122-L126) — the mirrored rule, clipboard branch unguarded.

The correct principle was already understood and already written into this codebase. It was written into one branch out of four (two call sites × two comparator kinds), because a rule restated at each call site will eventually be forgotten at one.

**The information needed to prevent this was present and unread.** `Read-ClipboardHash` correctly identified the paste as MD5, set `Algorithm = 'MD5'`, built the display string `plain hex, MD5`, and passed it downstream. The report *printed* it. No comparator ever read the field.

Duplication is the visible half of the root cause. The other half is **a fact computed, carried, and then discarded** — and it appears twice in this codebase, not once. `CompareTo.Algorithm` is the instance that produced the field report. The second instance is worse and is live today.

Three supporting defects:

- **`SidecarStatus` is written and never read.** [Test-VeriHashSidecar.ps1:67](../../VeriHash.Core/Public/Test-VeriHashSidecar.ps1#L67) independently determines `matched` / `mismatch` against the sidecar's own algorithm, re-hashing the file when it has to. Nothing in `Invoke-VeriHashHotPath` ever consults that verdict. The sidecar-write suppression at [Invoke-VeriHashHotPath.ps1:138](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L138) keys off `$isMismatch`, which is derived only from the *comparator*. When the comparator abstains, a proven-bad file is written a fresh sidecar recording its bad hash.

  **This reproduces on shipped code with no clipboard involved.** A corrupt file, a `.sha512` sidecar holding the vendor hash, a default SHA256 run: `Test-VeriHashSidecar` re-hashes with SHA512 and returns `SidecarStatus = 'mismatch'`; [Invoke-VeriHashHotPath.ps1:124](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L124) rejects the sidecar as a comparator because `SHA512 -ne SHA256`, so `$isMismatch` is `$false`; the `else` branch writes a `.sha256` sidecar for the corrupt file and the checklist reports `✓ created`. The banner says HASHED. The one function that knew the file was bad was overruled by silence. See *Step 1 — Sidecar-write suppression* for the fix.

- **No length precondition.** `Get-VeriHashDiffIndex` accepts strings of unequal length and returns the shorter length as the divergence point. [Get-VeriHashDiffIndex.ps1:7-9](../../VeriHash.Core/Private/Get-VeriHashDiffIndex.ps1#L7-L9) documents this exact MD5-vs-SHA256 scenario and treats it as legitimate divergence to highlight. The case was anticipated at the character-diff layer instead of the comparator layer.
- **`Get-FileHash` is only ever called with the run algorithm.** [VeriHash.ps1:213](../../VeriHash.ps1#L213) never passes `-Algorithm` at all, so single-file runs are permanently SHA256 regardless of what the user pasted or wants.

## Design principles

Three rules drive every decision below.

### 1. A pasted hash is a question, not a comparator

"Is this file the one this hash describes?" The algorithm is part of the **user's question**, not part of VeriHash's configuration. Today VeriHash answers a different question (SHA256, always) and reports the difference between its answer and the user's question as a *file* failure.

### 2. The sidecar records the algorithm the user *chose*; the clipboard's algorithm is a *question*

The vendor picked MD5. The user did not. Writing a `.md5` sidecar because a vendor published MD5 lets a transient question permanently downgrade a durable local record — and `Get-PreferredSidecar` prefers `.sha512 > .sha256 > .md5`, so that weak sidecar becomes the trusted one on every future run of that file.

### 3. Escalate on mismatch, never on match

A mismatch is the cheap moment to investigate: the user is already stopped, and the file is already read. This principle is **stated here but not implemented in this work** — see Deferred.

## Behaviour decision table

The three user populations this must serve: people who paste a hash first (the primary workflow), people who never paste and read the grouped hex by eye, and power users who want a non-default algorithm.

| Situation | Compute | Sidecar | Banner source |
| --- | --- | --- | --- |
| No clipboard hash, no flag | SHA256 | write `.sha256` | `none` → HASHED |
| Clipboard MD5, no flag | **MD5** — answer the question | **leave sidecars untouched** | `clipboard` |
| Clipboard SHA256, no flag | SHA256 | write `.sha256` | `clipboard` |
| Explicit `-Algorithm SHA512` | SHA512 | write `.sha512` | per comparability |
| Explicit `-Algorithm SHA512` + clipboard MD5 | SHA512 — **flag wins** | write `.sha512` | `unusable` |
| Batch mode (N files) | run algorithm only | per existing rules | per comparability |

**Precedence: explicit `-Algorithm` > clipboard-inferred > SHA256 default.** An explicit flag is a choice; the clipboard is a question; a choice outranks a question.

---

## Step 1 — Extract the comparator, add the guard

A standalone correctness fix. Ships independently and is a strict prerequisite for Step 2.

### New function

`VeriHash.Core/Public/Resolve-VeriHashComparator.ps1` (public — see *Call sites* for why it cannot be private):

```text
Resolve-VeriHashComparator
  -CompareTo         <pscustomobject>  clipboard record, may be $null
  -SidecarInfo       <pscustomobject>  sidecar record, may be $null
  -ComputedAlgorithm <string>          the algorithm actually hashed with

  → [pscustomobject]@{
        Source       = 'clipboard' | 'sidecar' | 'unusable' | 'none'
        ExpectedHash = <lowercase hex>  or $null
        Algorithm    = <comparator's algorithm> or $null
        Reason       = <string> or $null   # populated only for 'unusable'
    }
```

Selection rule, in order:

1. Clipboard present, usable (`CompareTo.Algorithm` non-null) **and** `CompareTo.Algorithm -eq ComputedAlgorithm` → `clipboard`.
2. Clipboard present but not usable as a comparator → `unusable`, carrying `Reason`. **The sidecar is not substituted.**

   Two distinct situations collapse into this one Source, because from the comparator's point of view they are the same event — *the user asked, and I cannot answer*:

   - **Wrong algorithm** — `CompareTo.Algorithm` differs from `ComputedAlgorithm`. `Reason`: `clipboard holds MD5; this run computed SHA256`.
   - **Unsupported hash** — `CompareTo.Algorithm` is `$null` because the clipboard held plausible hex of a length VeriHash does not implement. `Reason` comes straight from `CompareTo.Detail` (see *Third clipboard outcome* below), e.g. `clipboard holds 40 hex characters — looks like SHA-1, which VeriHash does not support`.

   This is the crux of the design and deserves its reasoning stated plainly. A user who pastes a hash is asking one specific question. If VeriHash cannot answer it, printing a green `MATCH — SHA256 matches sidecar file` banner would answer a *different* question in a way the user is overwhelmingly likely to read as an answer to theirs. That is the silent-fallback failure — worse than the bug being fixed here, because it fails green.

   No information is lost by refusing: the checklist reports the sidecar on its own row regardless of what the comparator chose, so `sidecar ✓ match` still appears. What the banner declines to do is *promote* that fact into a verdict on a question it does not address.
3. No clipboard, sidecar present with `ExpectedHash` **and** matching algorithm → `sidecar`.
4. Otherwise → `none`.

A defensive length equality assertion accompanies rule 1: equal algorithm names must imply equal hex length, and if they ever disagree that is a bug, not a mismatch.

### Call sites

Both [Format-VeriHashReport.ps1:49-65](../../VeriHash.Core/Public/Format-VeriHashReport.ps1#L49-L65) and [Invoke-VeriHashHotPath.ps1:116-127](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L116-L127) delete their local copies of the rule and call this function. The `Mirrors ... exactly` comment is deleted along with the thing it was describing.

**`Resolve-VeriHashComparator` cannot live in `VeriHash.Core/Private/`.** Both modules dot-source their own `Private/*.ps1` into their own module scope ([VeriHash.Core.psm1:3-5](../../VeriHash.Core/VeriHash.Core.psm1#L3-L5), [VeriHash.HotPath.psm1:11-13](../../VeriHash.HotPath/VeriHash.HotPath.psm1#L11-L13)), and PowerShell does not share module scope across a boundary. There is **no existing cross-module private helper to follow as a pattern** — every one of the twelve files in `VeriHash.Core/Private/` is called only from within Core, and `VeriHash.HotPath` reaches Core exclusively through exported publics (`Get-VeriHashResult`, `Read-ClipboardHash`, `Test-VeriHashSidecar`, `Format-VeriHashReport`, `Format-VeriHashBatchTally`, `Write-VeriHashLog`, `Get-VeriHashPlatform`).

Placed in `Private/`, the function resolves inside `Format-VeriHashReport` and throws `CommandNotFoundException` inside `Invoke-VeriHashHotPath`. CMP-01 fails at runtime, not at review.

It therefore ships as **`VeriHash.Core/Public/Resolve-VeriHashComparator.ps1`**, added to `FunctionsToExport` at [VeriHash.Core.psd1:72-74](../../VeriHash.Core/VeriHash.Core.psd1#L72-L74). This matches how `Test-VeriHashSidecar` and `Format-VeriHashBatchTally` already cross the boundary — `Format-VeriHashBatchTally`'s own doc comment states the precedent: *"Public because VeriHash.HotPath's Invoke-VeriHashBatch calls it across a module boundary."*

*Alternative considered and deferred:* resolve the comparator once in `Invoke-VeriHashHotPath` and pass the record to `Format-VeriHashReport -Comparator`, making the renderer a pure consumer rather than a second independent decider. That is the better end state — it removes the possibility of the two ever disagreeing again, rather than relying on both calling the same function — but it changes the renderer's public signature and every direct test call site. Not worth coupling to a correctness fix. Revisit if a third caller appears.

### A fourth verdict state: UNVERIFIED (yellow)

The current three banner states collapse two genuinely different negative answers. The banner answers one question — *was the thing you asked to be verified actually verified?* — and there are four answers, not three:

| Answer | State | Banner colour |
| --- | --- | --- |
| Yes, and it matched | `Match` | green |
| Yes, and it did not | `Mismatch` | red |
| **You asked, and I could not** | **`Unverified`** | **yellow** |
| You never asked | `Hashed` | neutral grey |

`Hashed` means *you didn't ask*. `unusable` means *you asked and I couldn't answer*. Rendering the second as the first tells a user who deliberately copied a hash that their clipboard was empty.

**Why this state is yellow and a matching MD5 is not.** Yellow marks *"your question went unanswered"* — a condition the user can act on and clear, by re-copying the right hash or re-running with the matching algorithm. It must never mark *"answered successfully, but with a weak algorithm"*: that comparison is not uncertain, VeriHash knows the answer, and the weakness belongs to the vendor's choice of algorithm rather than to the verification. A user whose vendors publish MD5 would see a permanent yellow that can never be cleared, and a signal that never goes green is wallpaper. The weak-algorithm caveat therefore stays on the checklist row (see *Weak-algorithm messaging*), never on the banner.

### Rendering the `unusable` state

- **Palette** — `Get-VeriHashPalette` gains a `BannerWarn` key alongside `BannerMatch` / `BannerMismatch` / `BannerHashed`, in both the truecolor and 16-colour tables, reversed-video like its siblings. Truecolor: amber background with dark foreground, consistent in weight with the existing banner pair. The `Yellow` colour and `Warn` glyph already exist and are already used for `unsigned` signatures, so the vocabulary is unchanged — only the banner-background key is new. `NO_COLOR` blanks it with everything else.
- **Banner** — `Format-VeriHashBanner`'s `-State` `ValidateSet` gains `'Unverified'` and its `-Source` `ValidateSet` gains `'unusable'`. Body is the comparator's `Reason`, prefixed with the verdict word: `UNVERIFIED — clipboard holds MD5; this run computed SHA256`. Glyph is `$g.Warn`.

  **Widening the `ValidateSet` and adding the `switch` arm are one edit, not two.** [Format-VeriHashBanner.ps1:24](../../VeriHash.Core/Private/Format-VeriHashBanner.ps1#L24) switches on `$State` with **no `default` arm**, relying on the `ValidateSet` to guarantee a match. PowerShell does not error on an unmatched `switch` — it falls through, leaving `$glyph`, `$body`, and `$sgr` at `$null`. Widen the set without adding the arm and the function returns a **blank, unstyled, correctly-padded bar** and throws nothing. Add `default { throw "unhandled banner state '$State'" }` in the same commit so the two can never be separated again. Same reasoning as the guard in Step 2's *`$Algorithm` stops being ValidateSet-guarded*: a `ValidateSet` protects the parameter, not the logic that assumed it.
- **Checklist** — `Format-VeriHashChecklist`'s clipboard row gains a fourth shape alongside none/match/mismatch, in `$c.Yellow` with `$g.Warn`: `! not compared ({CompareTo.Format}) — different algorithm than this run`. For the unsupported-hash case the clause is `CompareTo.Detail` instead.
- **Hash comparison block** — no expected/computed stacking and no diff line when `Source -eq 'unusable'`. Render the single-hash shape (the existing `else` branch at [Format-VeriHashReport.ps1:104-108](../../VeriHash.Core/Public/Format-VeriHashReport.ps1#L104-L108)).
- **Advisory** — stays keyed off `Mismatch` only. `unusable` is not a mismatch; VeriHash has no grounds to tell the user not to run the file, because it did not check.
- **Sidecar write** — **not** keyed off the banner state. See the next section; this is where the naive version of this fix does real damage.

### Sidecar-write suppression

The obvious rule — *suppress on `Mismatch`, proceed otherwise* — is the rule shipped today, and extracting the comparator turns it into a fail-green data-loss bug.

Trace a corrupt file with a good `.sha256` beside it and an MD5 on the clipboard:

1. `Resolve-VeriHashComparator` returns `Source = 'unusable'`, `ExpectedHash = $null`.
2. [Invoke-VeriHashHotPath.ps1:127](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L127) — `$isMismatch = ($null -ne $expectedHash) -and ...` → `$false`.
3. The `else` branch at [:149-173](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L149-L173) runs. `.sha256` exists, its recorded hash differs from the computed one, so `$sidecarVerb = 'updated'` and [`WriteAllText`](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L162) **overwrites the vendor's hash with the corrupt file's hash.**
4. `$sidecarRecord` is replaced, and [Format-VeriHashChecklist.ps1:57](../../VeriHash.Core/Private/Format-VeriHashChecklist.ps1#L57) renders `✓ updated`.

The user sees a yellow banner and a green sidecar row, and the only evidence that the file was bad has been destroyed — by VeriHash, silently, in the same run that declined to draw a conclusion. Today's bug accidentally prevents this: the false MISMATCH suppresses the write. Removing the false MISMATCH without replacing the suppression removes the accident and keeps nothing.

**The rule is not "did the comparator say mismatch". It is "does any evidence say this file is bad".**

```text
$sidecarProvenBad = $sidecarRecord -and $sidecarRecord.SidecarStatus -eq 'mismatch'
$suppressWrite    = $isMismatch -or $sidecarProvenBad
```

`SidecarStatus` is authoritative on its own terms and needs no algorithm guard: [Test-VeriHashSidecar.ps1:67](../../VeriHash.Core/Public/Test-VeriHashSidecar.ps1#L67) compares the sidecar's recorded hash against a digest computed **with that sidecar's own algorithm**, re-hashing the file when the caller's digest cannot answer. A `mismatch` from it is a real, independently established fact about the file — which is exactly why the comparator's algorithm guard must not be allowed to discard it. The guard exists to stop VeriHash *comparing* across algorithms; it was never meant to stop VeriHash *believing* a comparison something else already made correctly.

Consequences to render honestly:

- When `$sidecarProvenBad` suppresses the write, the existing `$sidecarRecord` already says `mismatch` and [Format-VeriHashChecklist.ps1:58](../../VeriHash.Core/Private/Format-VeriHashChecklist.ps1#L58) already renders `✗ sidecar mismatch — <name>`. No new row shape is needed. The `'none'` synthesis at [:141-148](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L141-L148) stays reserved for the case where there is genuinely no sidecar record at all.
- **The banner still reads `UNVERIFIED`, not `MISMATCH`.** This is deliberate and is the same discipline as rule 2 of the selection order: the banner answers *the question the user asked*, and the user asked about an MD5. A red MISMATCH banner would read as an answer to that question and would be sourced from evidence the user did not ask about. The sidecar's `✗` on the checklist is where that fact belongs, and it is already loud.
- **The advisory does not fire.** Same reasoning. A user staring at `✗ sidecar mismatch` has what they need; the advisory is the banner's escalation, and the banner abstained.

This is the one place where the report's rows disagree in tone — yellow banner, red sidecar row — and that is correct rather than a defect to smooth over. It is the honest rendering of *"I could not answer what you asked, and separately, something else here is wrong."* Collapsing the two into one verdict is what produced the original bug.

**This fix stands alone and is independently shippable.** It repairs live behaviour on shipped code (see *Root cause*, first supporting defect) and does not depend on `UNVERIFIED`, the comparator extraction, or anything else in Step 1. If `09-01` is split further, this travels with the comparator extraction and not behind it.

### Third clipboard outcome — recognised but unsupported

`ConvertTo-VeriHashAlgorithm` currently returns `$null` for two unrelated situations: *the clipboard holds no hash at all*, and *the clipboard holds hex of a length I do not implement*. `Read-ClipboardHash` inherits the conflation and returns `$null` for both, so a SHA-1 (40 hex), a SHA-224 (56 hex), or a paste that lost a character all render as:

```text
clipboard   − nothing recognizable — copy the vendor's hash and re-run
```

That instructs a user who *did* copy the vendor's hash to go copy the vendor's hash. `$null` is doing double duty as "nothing there" and "something there I must decline", and every consumer downstream inherits it.

**`ConvertTo-VeriHashAlgorithm`** gains a third outcome. It is private and has exactly one caller ([Read-ClipboardHash.ps1:31](../../VeriHash.Core/Public/Read-ClipboardHash.ps1#L31)), so the contract change is contained. It returns a small record rather than a bare string:

```text
  → [pscustomobject]@{
        Algorithm = 'MD5' | 'SHA256' | 'SHA512' | $null
        Status    = 'supported' | 'unsupported'
        Detail    = <string> or $null   # populated only for 'unsupported'
    }
  → $null   # genuinely not hash-shaped
```

Classification rule:

1. Prefixed `md5|sha256|sha512:` with the right hex length → `supported`.
2. Prefixed with any other algorithm token (`sha1:`, `blake3:`, `sha3-256:`) → `unsupported`, `Detail` naming the prefix.
3. Bare hex of length 32 / 64 / 128 → `supported`.
4. Bare hex of any other even length from 16 to 256 → `unsupported`. Name the well-known lengths — 40 → SHA-1, 56 → SHA-224, 96 → SHA-384 — and fall back to `{N} hex characters — not a hash length VeriHash recognises` for the rest.
5. Anything else → `$null`. A shopping list on the clipboard is not a failed verification and must stay silent.

**`Read-ClipboardHash`** returns `$null` only for case 5. For `unsupported` it returns a record with `Algorithm = $null`, `Hash = $null`, and `Detail` carried through, which `Resolve-VeriHashComparator` turns into `Source = 'unusable'` per rule 2 above. Checklist row:

```text
clipboard   ! 40 hex characters — looks like SHA-1, which VeriHash does not support
```

**The `CompareTo` record contract.** It now has three shapes, and every consumer must be written against the whole set rather than against the one it was first shown. Stated once here so it is not inferred from three separate sections:

| Shape | `Algorithm` | `Hash` | `Format` | `Detail` |
| --- | --- | --- | --- | --- |
| supported | `'MD5'` \| `'SHA256'` \| `'SHA512'` | lowercase hex | display parenthetical | `$null` |
| unsupported | `$null` | `$null` | `$null` | why it cannot be used |
| nothing there | *(record is `$null` — no object at all)* | | | |

Consumers to check against all three:

- [Format-VeriHashReport.ps1:54](../../VeriHash.Core/Public/Format-VeriHashReport.ps1#L54) tests `$CompareTo -and $CompareTo.Hash` — already safe, because an unsupported record has a `$null` `Hash`. It becomes `Resolve-VeriHashComparator`'s problem regardless.
- [Format-VeriHashChecklist.ps1:43-49](../../VeriHash.Core/Private/Format-VeriHashChecklist.ps1#L43-L49) tests only `$null -eq $CompareTo` and then reads `$CompareTo.Format` in both remaining branches. An unsupported record reaching those branches renders a bare `()`. The new fourth row shape must be selected on `Source`, not on `ClipboardMatch`.
- [Invoke-VeriHashHotPath.ps1:184](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L184) forwards on `$null -ne $clip`, so unsupported records do flow through to the renderer. That is intended — the checklist must report them.

`Read-ClipboardHash`'s `.OUTPUTS` block documents only the supported shape and needs updating alongside.

This is the one piece of genuinely new scope in Step 1 rather than a refinement of existing behaviour. It can be deferred to `09-02` if `09-01` needs to stay minimal — but shipping Step 1 without it leaves the SHA-1 case still reporting an empty clipboard, and the yellow state it feeds is already being built.

### Behaviour change

The reported scenario renders as:

```text
VeriHash 2.0 · SHA256 · Docker Desktop Installer.exe (596.18 MB)

  !  UNVERIFIED — clipboard holds MD5; this run computed SHA256

clipboard   ! not compared (plain hex, MD5) — different algorithm than this run
sidecar     ✓ match — Docker Desktop Installer.exe.sha256
signature   ✓ valid — Docker Inc
```

No MISMATCH banner, no advisory, no suppressed sidecar write, and no diff line. The user can still see that the file passed its sidecar check, and can see exactly why their paste went unanswered.

After Step 2 this same scenario resolves further — the clipboard's MD5 becomes the run algorithm and the banner turns green or red on a real MD5 comparison. Step 1's yellow is the honest intermediate, and remains the permanent rendering for the cases Step 2 cannot resolve (explicit `-Algorithm` colliding with the clipboard, batch mode, and unsupported clipboard hashes).

**`MatchResult` must not be left alone here.** [Invoke-VeriHashHotPath.ps1:198](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L198) derives it as *not mismatched* rather than *compared and equal*, so an `unusable` comparator would report `matched` — a file nothing verified, labelled with the word for a successful verification, on the object callers consume programmatically.

That derivation is inherited (a hash-only run already reports `matched` today for the same reason), and in the single-file case it is survivable because the yellow banner is right there. In batch mode it is not: the per-file banners scroll away and the tally is what remains. So `MatchResult` gains `'unverified'` as part of this work. The full consequences — two consumers with `default` branches that absorb the new value silently, and how `TallyLine` stays byte-identical — are in *The batch tally* below.

`$hasComparator` remains the field that answers *did a comparison happen at all*, and stays `$false` for `unusable`.

**Also inherited, and left alone deliberately:** the log line at [Invoke-VeriHashHotPath.ps1:205-206](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L205-L206) derives `Op` and `Result` from `$hasComparator`, so an unusable clipboard logs `hash` / `n/a` — the log records that the user never asked, when in fact they asked and got no answer. Low stakes, no consumer known to depend on it, and widening the log's vocabulary is a contract change of its own. `Write-VeriHashLog` is **not** modified by this work; noted so the omission is a decision rather than an oversight.

### Tests — Step 1

- `Resolve-VeriHashComparator` unit tests: all four Source outcomes, both `unusable` sub-cases (wrong algorithm, unsupported hash), plus precedence (clipboard beats sidecar when both are comparable).
- `Resolve-VeriHashComparator` is callable from `VeriHash.HotPath`'s scope — import only the two manifests and invoke it from inside an exported HotPath function. A unit test that dot-sources the file directly would pass while the shipped module throws.
- Renderer: clipboard-MD5 + SHA256-run emits `UNVERIFIED`, no `MISMATCH`, no advisory, no diff line.
- Hot path, sidecar write **proceeds**: clipboard-MD5 + SHA256-run with no sidecar on disk, and again with a *matching* `.sha256` — the file is good, nothing is suppressed. This is the regression test for the original suppression bug.
- Hot path, sidecar write **suppressed**: clipboard-MD5 + SHA256-run against a corrupt file with a `.sha256` whose hash differs. Assert the sidecar bytes on disk are **unchanged**, the checklist shows `✗ sidecar mismatch`, and the banner still reads `UNVERIFIED` (not `MISMATCH`).
- Hot path, no clipboard at all, corrupt file, `.sha512` sidecar, default SHA256 run: no `.sha256` is created, checklist shows `✗ sidecar mismatch`. **This one fails on `main` today** — it pins the live bug from *Root cause*, supporting defect 1.
- `ConvertTo-VeriHashAlgorithm`: 32/64/128 hex → `supported`; 40/56/96 hex → `unsupported` with the algorithm named; `sha1:`-prefixed → `unsupported`; non-hex → `$null`.
- `Read-ClipboardHash`: unsupported hex returns a record (not `$null`) carrying `Detail`; a non-hash clipboard still returns `$null`.
- Checklist: unsupported-hex clipboard renders the `Detail` clause, **not** `nothing recognizable`.
- Banner: `Unverified` renders in `BannerWarn` with the `Warn` glyph, and degrades correctly under `NO_COLOR`, `VERIHASH_NO_TRUECOLOR`, and a non-UTF-8 code page (FMT-07 still holds for the new state).
- Banner: every value in the `-State` `ValidateSet` produces a non-empty body — iterate the attribute's `ValidValues` rather than listing states by hand, so the test cannot drift out of sync with the set it is guarding.
- Existing golden-text tests for MATCH/MISMATCH/HASHED must still pass unchanged.

---

## Step 2 — The clipboard drives the algorithm

Built on Step 1's seam. Changes one branch: instead of reporting `unusable`, hash with the algorithm the user asked about.

### Behaviour

In `Invoke-VeriHashHotPath`, **before** starting the hash ThreadJob:

1. If `-Algorithm` was bound explicitly, use it. (Requires `$PSBoundParameters.ContainsKey('Algorithm')` — a default-valued parameter cannot otherwise be distinguished from an explicit one.)
2. Else read the clipboard, and if it yields a hash, use its algorithm.
3. Else SHA256.

This moves `Read-ClipboardHash` from [Invoke-VeriHashHotPath.ps1:94](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L94) — currently after the hash job completes — to before the job starts, and **deletes** the later call rather than duplicating it. The direct cost is one `Get-Clipboard` on the critical path, which is not measurable against a file read. The indirect cost is much larger and is dealt with next.

`unusable` remains reachable three ways — explicit flag colliding with the clipboard (precedence rule 1), batch mode, and an unsupported clipboard hash, which no amount of algorithm selection can resolve. Step 1's yellow `Unverified` rendering is therefore permanent, not transitional.

Note that step 2 chooses the algorithm from the clipboard **only when the clipboard is `supported`**. An `unsupported` clipboard record carries `Algorithm = $null` and cannot select anything, so the run falls through to SHA256 and reports `Unverified`.

### `$Algorithm` stops being ValidateSet-guarded

Today `$Algorithm` can only arrive through a parameter carrying `[ValidateSet('MD5','SHA256','SHA512')]`, so every consumer downstream is free to assume it is one of three strings. Step 2 breaks that assumption: the value now comes from **clipboard-parsed text**, and PowerShell validates parameters, not assignments.

One consumer assumes it dangerously. [Invoke-VeriHashHotPath.ps1:132-133](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L132-L133):

```powershell
$algoExtMap  = @{ 'SHA256' = '.sha256'; 'SHA512' = '.sha512'; 'MD5' = '.md5' }
$sidecarPath = "$resolved$($algoExtMap[$Algorithm])"
```

A hashtable miss in PowerShell returns `$null` — it does not throw. An unmapped algorithm therefore interpolates to nothing and makes **`$sidecarPath` equal to `$resolved`: the target file itself.** From there the existing write path runs to completion without a single error:

1. [:152](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L152) `Test-Path` succeeds — the file is certainly there.
2. [:154](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L154) reads the first line of the binary; `-match '^([A-Fa-f0-9]+)\s'` fails, so `$sidecarVerb = 'updated'` and `$shouldWrite` stays `$true`.
3. [:162](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L162) `WriteAllText` **replaces the file being verified with a ~100-byte text file.**
4. The checklist reports `✓ updated`.

**This is not reachable on `main`** — `ValidateSet` rejects everything else at bind time. It is listed here because Step 2 is the change that removes that protection, and because the blast radius is *destroying the user's file during an operation whose entire purpose is protecting it*.

Step 2 as specified keeps it safe: the clipboard selects an algorithm only when `Status = 'supported'`, and `supported` means one of the three. But that invariant is now maintained in `ConvertTo-VeriHashAlgorithm`, two functions and a module boundary away from the code that would destroy the file. Correct by construction is not the same as safe under edit — CMP-10 is actively widening `ConvertTo-VeriHashAlgorithm`'s vocabulary in the adjacent plan.

**Guard the lookup, not just the source:**

```powershell
$ext = $algoExtMap[$Algorithm]
if (-not $ext) { throw "unmapped algorithm '$Algorithm' — refusing to derive a sidecar path" }
$sidecarPath = "$resolved$ext"
```

Three lines, and it converts a silent file-destroying write into a loud stop. A test must pin it: call `Invoke-VeriHashHotPath` with the map bypassed (or mock `Read-ClipboardHash` to return an out-of-set `Algorithm`) and assert it throws **and that the target file is unmodified**.

### A clipboard-selected algorithm makes the file be read twice

This is the real cost of Step 2 and it is easy to miss, because it is paid inside a function this work does not otherwise touch.

[Invoke-VeriHashHotPath.ps1:100](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L100) hands the hash job's digest to `Test-VeriHashSidecar -ComputedResult`. [Test-VeriHashSidecar.ps1:45-50](../../VeriHash.Core/Public/Test-VeriHashSidecar.ps1#L45-L50) reuses that digest **only when `ComputedResult.Algorithm` equals the chosen sidecar's algorithm**, and otherwise calls `Get-VeriHashResult` — a full second pass over the file, synchronous, on the main thread, between the hash job and the signature wait.

Under Step 2, a clipboard MD5 makes those algorithms differ by construction. `Get-PreferredSidecar` finds the `.sha256` **VeriHash itself wrote on the previous run of that same file**, and the file is read twice.

This is not an edge case. It is the default outcome of the primary workflow — paste hash, Send To, verify — on any file that has been verified before, which is precisely when a `.sha256` exists. On the 596 MB installer from the field report it roughly doubles wall clock, in the same function whose `-ComputedResult` parameter was added specifically to eliminate a second pass.

**Decision: when the clipboard selected the algorithm, constrain the sidecar check to that algorithm.** `Test-VeriHashSidecar` gains an optional `-Algorithm` that pins `Get-PreferredSidecar` to a single extension instead of walking the `.sha512 > .sha256 > .md5` precedence. The hot path passes it only on clipboard-driven runs.

- If a sidecar in the run's algorithm exists, it is checked for free against the digest already in hand.
- If it does not, `Test-VeriHashSidecar` returns `$null` and the checklist reports no sidecar. Correct: no *comparable* sidecar exists, and none will be written either (see *Sidecar policy* below).

Rejected alternative: skip the sidecar check entirely on clipboard-driven runs. Cheaper to implement, but it discards a free same-algorithm check when one is available, and a free check is exactly what the `-ComputedResult` plumbing exists to provide.

**Accepted cost:** on a clipboard-driven MD5 run, a `.sha256` sitting on disk is no longer consulted, so the report loses a `sidecar ✓ match` row it would otherwise have shown. That row cost a full re-read of the file to produce, and the user asked about the MD5 — the banner answers their actual question either way. Worth stating out loud because it is a visible reduction in what the report says, chosen deliberately.

The timing suite must cover this: a clipboard-driven MD5 run against a file with an existing `.sha256` reads the file exactly once. Assert on `Get-VeriHashResult` invocation count, not on elapsed time.

### Sidecar policy

Per design principle 2, the sidecar write in [Invoke-VeriHashHotPath.ps1:129-173](../../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1#L129-L173) becomes conditional on **how the algorithm was chosen**, not on what it is:

- Algorithm chosen by explicit flag or default → write the matching sidecar (unchanged).
- Algorithm chosen by the clipboard → **write nothing, touch nothing.** Existing sidecars are left exactly as found.

The checklist sidecar row needs a shape for this: `⊘ not written — algorithm came from clipboard`. Silence here would read as "no sidecar exists", which is a different fact.

**That new shape does not outrank a real verification result.** The row is already answering two different questions with one field — *did a sidecar verify this file?* and *did VeriHash write one?* — and `SidecarStatus` carries all six answers in one string. Adding a seventh value without stating precedence would let a bookkeeping note about a write silently replace evidence about the file. Precedence, most important first:

1. `mismatch` / `error` — the file failed a check, or a sidecar could not be read. Always wins. Never replaced by a note about writing.
2. `matched` — a sidecar verified this file. Beats `not written`, and reporting both would be noise: the row already implies no write was needed.
3. `not written — algorithm came from clipboard` — only when there is no sidecar record to report at all.

With the `-Algorithm` pinning from the previous section, cases 1 and 2 arise only for a sidecar in the run's own algorithm, and case 3 is the common outcome on a clipboard-driven run. That is the right default: the row explains why no `.md5` appeared next to the file, which is the question the user would actually have.

### Header attribution

`FMT-01`'s header becomes load-bearing. Today [Format-VeriHashReport.ps1:77-78](../../VeriHash.Core/Public/Format-VeriHashReport.ps1#L77-L78) prints an effectively constant `SHA256`. Once the clipboard can redirect the algorithm, a user reading grouped hex by eye has no other signal telling them which algorithm is on screen — and comparing on-screen MD5 against a vendor page's SHA256 by eye is a silent failure.

When the clipboard drove the choice, the header reads:

```text
VeriHash 2.0 · MD5 (from clipboard) · Docker Desktop Installer.exe (596.18 MB)
```

### Weak-algorithm messaging

A matching MD5 must not render as a failure, and must not render identically to a matching SHA256. One clause on the existing row, no second line, no lecture:

```text
clipboard   ✓ match (plain hex, MD5 — weak; prefer SHA256 if the vendor lists one)
```

This is the runtime warning `.planning/codebase/CONCERNS.md:51` asked for and never received. Applies to MD5 only.

### Batch mode is excluded

`Invoke-VeriHashBatch` calls `Invoke-VeriHashHotPath` per file, and each call reads the clipboard. Letting one clipboard value redirect the algorithm for N files would re-hash an entire batch with MD5 because of a single paste. **The clipboard is not an algorithm selector in batch mode.** `Invoke-VeriHashBatch` passes its `-Algorithm` explicitly (it already does, at [Invoke-VeriHashBatch.ps1:39](../../VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1#L39)), which under precedence rule 1 suppresses clipboard inference automatically. No extra flag needed — but a test must pin it.

### Tests — Step 2

- Clipboard MD5 → run hashes MD5, banner MATCH/MISMATCH against the MD5, **no sidecar written**, existing `.sha256` untouched on disk.
- Clipboard SHA512 → run hashes SHA512, no sidecar written.
- Explicit `-Algorithm SHA512` + clipboard MD5 → SHA512 computed, `.sha512` written, clipboard row `⊘ not compared`.
- No clipboard → SHA256, `.sha256` written (unchanged behaviour).
- Batch with MD5 on clipboard → every file hashed SHA256, not MD5.
- Header shows `MD5 (from clipboard)` only when the clipboard drove the choice.
- MD5 weak-hash clause appears on match and on mismatch; absent for SHA256/SHA512.
- **Clipboard MD5 + existing `.sha256` on disk → the file is read exactly once.** Count `Get-VeriHashResult` invocations; do not assert on elapsed time.
- Sidecar row precedence: clipboard MD5 with a matching `.md5` present → `✓ match`, not `⊘ not written`. With a *mismatching* `.md5` → `✗ sidecar mismatch`, and the `.md5` bytes on disk are unchanged.
- An algorithm outside `$algoExtMap` throws, and **the target file is byte-identical afterwards**. Assert on the file, not only on the exception — the exception is the mechanism, the intact file is the requirement.

---

## Step 3 — Expose `-Algorithm` on the CLI

Small and independent. [VeriHash.ps1](../../VeriHash.ps1) has no `-Algorithm` parameter at all, though `Invoke-VeriHashHotPath` and `Invoke-VeriHashBatch` both accept one and v1 had the flag. Power users currently cannot request SHA512 by any means.

- Add `[ValidateSet('MD5','SHA256','SHA512')] [string]$Algorithm` to the `param()` block, **with no default value**, so `$PSBoundParameters` can distinguish explicit from absent (Step 2 depends on this).
- Splat it through to `Invoke-VeriHashHotPath` / `Invoke-VeriHashBatch` only when bound.
- Add the flag to the `-Help` banner's Switches section.
- SendTo integration is **unchanged**: one menu entry, no per-algorithm variants. The clipboard already carries the user's intent and cannot disagree with itself the way a second menu entry could.

---

## Advisory wording (FMT-05)

Requested alongside this work. Change [Format-VeriHashReport.ps1:134](../../VeriHash.Core/Public/Format-VeriHashReport.ps1#L134):

```text
- Do not run this file. Re-download it, then verify again.
+ Recommendation: Do not run this file. Re-download it, then verify again.
```

Still a clear warning, but framed as guidance the user is choosing to follow rather than an order. 72 characters, within the palette width, no wrapping.

Occurrences to update in the same commit:

- [Format-VeriHashReport.ps1:134](../../VeriHash.Core/Public/Format-VeriHashReport.ps1#L134) — the source string
- `Tests/VeriHash.Core.Format-VeriHashReport.Tests.ps1:174` — exact-match assertion
- `Tests/VeriHash.Cli.Tests.ps1:228` — substring assertion (`Do not run this file`) still passes, but should be tightened to the new string
- `HANDOFF-console-spec.md:76` — byte-locked spec string
- `.planning/REQUIREMENTS.md:25` and `.planning/ROADMAP.md:45` — FMT-05 wording

The two `Should -Not -Match` assertions (lines 113, 177) match on `Do not run this file.` and remain correct.

**Do not update** `.planning/phases/7-output-formatting/07-01-PLAN.md:1525` and `:1707`. A grep for the string finds them; they are the historical record of what Phase 7 planned and shipped, and rewriting them would falsify it. Listed here so the next person stops rather than tidying.

---

## Explicitly deferred

| Item | Reason |
| --- | --- |
| Single-pass multi-hash fan-out | Forces abandoning `Get-FileHash` for a hand-rolled `IncrementalHash` loop. In PowerShell script that is frequently *slower* than `Get-FileHash` due to per-buffer interpreter overhead; doing it properly needs an `Add-Type` C# helper. Its real payoff is `-Algorithm All` (`.planning/codebase/CONCERNS.md:96`: a 3.7 GB file read three times, ~63 s vs ~21 s), not the clipboard case. Build it when `All` returns. |
| `-Algorithm All` | Depends on fan-out. |
| SHA3 / BLAKE2 / BLAKE3 | `Get-FileHash` exposes none of them. SHA3 needs .NET 8+ *and* OS CNG support; BLAKE has no BCL support at all. Also collapses length inference — 64 hex becomes ambiguous across SHA256/SHA3-256/BLAKE2s-256, which would promote the `sha256:` prefix form from optional sugar to the primary interface and make escalate-on-mismatch mandatory rather than optional. |
| Escalate on mismatch | Requires >1 algorithm per output length to be useful, so it lands with SHA3/BLAKE. |
| Batch-mode clipboard semantics | See below. |

## Discovered, out of scope

**Batch mode compares one clipboard hash against every file.** `Invoke-VeriHashBatch` loops `Invoke-VeriHashHotPath`, and each iteration reads the clipboard fresh. With any hash on the clipboard, at most one file can match; the other N-1 render a MISMATCH banner and have their sidecar writes suppressed. The `Compact` early-return at [Format-VeriHashReport.ps1:126](../../VeriHash.Core/Public/Format-VeriHashReport.ps1#L126) hides the advisory, so it is quieter than the single-file bug — but it is the same class of false alarm, and it silently withholds sidecars from good files.

Not fixed here because it needs its own decision: should the clipboard be a comparator in batch mode at all? Recommendation is that it should not be, but that changes shipped Phase 7 behaviour and deserves its own discussion. **Filed as a todo, not folded into this work.**

Note that Step 1 does defuse the damaging half: with the clipboard hash not comparable to most files' computed hash, those files now resolve `unusable` rather than `Mismatch`, so sidecar writes are no longer suppressed for them. What remains is the display question above.

**A MISMATCH exits 0.** [VeriHash.ps1:211-217](../../VeriHash.ps1#L211-L217) — the normal hash-mode branch — never assigns `$exitCode`. Only sidecar-verify ([:187](../../VeriHash.ps1#L187)) and manifest-verify ([:203](../../VeriHash.ps1#L203)) do. So `verihash corrupted.exe` with a mismatching clipboard hash prints a red banner, a red advisory, and exits `0`; a batch that is entirely mismatches exits `0` too.

This is the strongest machine-readable signal a CLI has, and it is unwired. It is also the natural home for the `TallyLine` residual risk above — an exit code distinguishes *verified*, *failed*, and *could not verify* without touching a frozen string. Out of scope here because it changes shipped CLI behaviour and anything currently invoking VeriHash in a script would start seeing failures it never saw before, which needs its own decision. **Filed as a todo, and it should be a near-term one.**

## The batch tally

`TallyLine` is byte-locked to `matched / mismatch / missing` ([Invoke-VeriHashBatch.ps1:64-69](../../VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1#L64-L69)) and is the machine-readable contract anything parsing VeriHash's output depends on. **Its format string is not touched by this work.** Everything below is about making sure the numbers going into it stay honest.

### The problem: a loud false alarm becomes a silent all-clear

Keeping `TallyLine` at three buckets *and* letting yellow files fall into `matched` are each defensible alone. Together, on the field-report scenario scaled to a batch of 50 files with an MD5 on the clipboard:

| | `TallyLine` | What actually happened |
| --- | --- | --- |
| Today | `0/50 matched, 50 mismatch, 0 missing` | Nothing was verified. Wrong, but loudly wrong. |
| Naive Step 1 | `50/50 matched, 0 mismatch, 0 missing` | Nothing was verified. **Reads as a clean pass.** |

By this note's own standard — fail-green is worse than fail-loud, because a green result is acted on — the second row is a worse outcome than the bug being fixed. It cannot ship that way just because `TallyLine`'s format is frozen. Freezing the *format* was never a licence to let the *numbers* mean something new.

### `MatchResult` gains a fourth value

`MatchResult` gains `'unverified'`, set when `Resolve-VeriHashComparator` returned `Source = 'unusable'`. The derivation becomes an explicit three-way classification rather than *not mismatched*:

```text
'mismatch'   when $isMismatch
'unverified' when $comparator.Source -eq 'unusable'
'matched'    otherwise
```

**`Source = 'none'` still reports `matched`, and that is left alone.** A plain hash-only run — the user never asked anything — has reported `matched` since v2.0, `Invoke-VeriHashBatch` has always tallied it there, and changing it would flip every hash-only batch from `N/N matched` to `0/N matched`. That is a shipped-behaviour change with no correctness argument behind it: nobody is misled by a hash-only run, because they did not ask a question to be misled about. The case being fixed here is different in kind — the user *did* ask, and `matched` would be answering them.

So the *not mismatched* wart is narrowed, not eliminated. `$hasComparator` remains the field that answers *did a comparison happen*.

Adding a value to `MatchResult` is a **breaking change to two consumers that both fail silently**, and both must be updated in the same commit:

- [Invoke-VeriHashBatch.ps1:41-45](../../VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1#L41-L45) — the switch has `default { $missing++ }`. Untouched, every yellow file tallies as **missing**, and `TallyLine` changes. Needs an explicit `'unverified'` case.
- [Format-VeriHashBatchTally.ps1](../../VeriHash.Core/Public/Format-VeriHashBatchTally.ps1) — counts via three `Where-Object -eq` filters, so yellow files are excluded from **all three**; and the per-file `switch` has `default { ... 'missing' }`, so each one renders with the `None` glyph and the word `missing`. Untouched, a fully-yellow batch prints `batch of 50 · 0 matched · 0 mismatch · 0 missing` above 50 lines that each claim `missing`.

Neither throws. Both just quietly lie. This is the same failure shape as the original bug — a new value added at the producer, `default` branches absorbing it at the consumers — which is worth noting given that the bug being fixed here came from exactly this.

### Keeping `TallyLine` byte-identical

`unverified` files count into the `matched` bucket **for `TallyLine` arithmetic only**:

```text
'unverified' { $unverified++; $matched++ }
```

The three numbers are then arithmetically identical to what today's *not mismatched* derivation produces for the same inputs, and the format string is untouched. Success criterion 10 holds in the strict sense: same format, same numbers, for every input that reaches it.

### Where the yellow count becomes visible

- **`Tally` hashtable** ([Invoke-VeriHashBatch.ps1:76](../../VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1#L76)) gains `Unverified = $unverified`. **This hashtable is a separate object from `TallyLine` and was never byte-locked** — it is the seam that lets the count be exposed without touching the frozen string, and it is the field programmatic consumers should be pointed at.
- **`Format-VeriHashBatchTally`** gains a yellow count in the summary line, shown only when non-zero (matching how `mismatch` already colours only when non-zero — a permanent yellow `0 unverified` is the wallpaper problem this note warns about elsewhere), and a per-file `unverified` case with `$g.Warn` in `$c.Yellow`. This is the human-facing renderer Phase 7 deliberately separated from `TallyLine` precisely so it could evolve. That boundary pays for itself here.

### Residual risk, stated not hidden

A consumer reading **only** `TallyLine` still sees `50/50 matched` for a batch where nothing was verified. `Tally.Unverified` is the correct field, but the string is what exists in scripts today.

Not fixed here, because every fix changes shipped output: a fourth bucket breaks the byte-lock, and re-basing `matched` to mean *compared and matched* changes the plain hash-only batch from `N/N matched` to `0/N matched`. Both are defensible; neither belongs inside a correctness fix. **Filed as a todo: does `TallyLine` earn a fourth bucket in v3, and does `matched` mean *not mismatched* or *compared and matched*?** The `Tally` hashtable is the migration path either way.

### Tests — batch tally

- Batch of N with an MD5 on the clipboard → `TallyLine` is byte-identical to the Phase 7 format string and reports `N/N matched, 0 mismatch, 0 missing`; `Tally.Unverified -eq N`.
- The same batch renders N yellow `unverified` per-file lines, **not** N `missing` lines, and the summary count line shows the unverified count.
- A batch with no unverified files renders exactly as it does on `main` — no yellow count, no layout shift.
- A mixed batch (some matched, some mismatch, some unverified) sums correctly in both `Tally` and `TallyLine`.

## Proposed requirements

New `CMP` group for `.planning/REQUIREMENTS.md`:

- **CMP-01**: Comparator selection lives in exactly one function; `Format-VeriHashReport` and `Invoke-VeriHashHotPath` both call it rather than restating the rule
- **CMP-02**: A clipboard hash whose algorithm differs from the computed algorithm is never compared, never reported as MISMATCH, and never on its own causes a sidecar write to be suppressed
- **CMP-03**: A clipboard hash that cannot be used is rendered honestly in banner and checklist — it is not reported as an absent clipboard, and the sidecar is not silently substituted for it
- **CMP-04**: When no explicit `-Algorithm` is given, a recognised clipboard hash selects the algorithm the file is hashed with
- **CMP-05**: A clipboard-selected algorithm writes no sidecar and modifies no existing sidecar
- **CMP-06**: The header names the algorithm actually computed, and attributes it when the clipboard selected it
- **CMP-07**: An MD5 comparison is labelled weak in the clipboard row, on both match and mismatch
- **CMP-08**: `VeriHash.ps1` accepts `-Algorithm MD5|SHA256|SHA512` and passes it through; batch mode always passes an explicit algorithm
- **CMP-09**: A fourth verdict state `UNVERIFIED` renders in yellow when the user supplied a hash that could not be compared; a successful comparison against a weak algorithm renders green, never yellow
- **CMP-10**: A clipboard holding plausible but unsupported hex is reported as such, naming the likely algorithm where the length is well known, and is never reported as an empty or unrecognisable clipboard
- **CMP-11**: A sidecar is never written or overwritten for a file that any check proved bad. Suppression is keyed off all available negative evidence — the comparator's verdict *and* `SidecarStatus` — not off the banner state alone
- **CMP-12**: `MatchResult` distinguishes *verified and equal* from *not verified*; a batch containing unverified files exposes that count on `BatchResult.Tally`, and every per-file line and summary count in `Format-VeriHashBatchTally` reports unverified files as unverified rather than as missing
- **CMP-13**: A clipboard-selected algorithm does not cause the file to be read a second time
- **CMP-14**: A value outside a closed set never resolves to a silent fallback. Specifically: an unmapped algorithm never yields a sidecar path equal to the target file, and an unhandled banner state never renders an empty bar. Both fail loudly instead
- **FMT-05** (amended): the MISMATCH advisory reads `Recommendation: Do not run this file. Re-download it, then verify again.`
- **FMT-07** (extended): the `UNVERIFIED` banner degrades with the other three under `NO_COLOR`, `VERIHASH_NO_TRUECOLOR`, and a non-UTF-8 code page
- **Unchanged by this work**: `BatchResult.TallyLine` keeps its three buckets and its byte-locked format string

## Proposed roadmap placement

Phase 9 of v2.1, after Phase 8 (Manifest Spot-Check) in numbering but **not** in execution order — Step 1 fixes a live correctness bug in shipped Phase 7 output and should not wait behind Phase 8.

**Goal**: A verdict is never stronger than the evidence behind it, and the algorithm VeriHash computes is the one the user asked about.

**Depends on**: Phase 7 (the renderer and comparator this corrects).

**Success criteria** (what must be TRUE):

1. An MD5 on the clipboard during a SHA256 run of an **intact** file produces no MISMATCH banner, no advisory, and no suppressed sidecar write
2. Comparator selection exists in exactly one place in the codebase, and that one place is reachable from both modules at runtime
3. A hash the user supplied but VeriHash could not compare produces a yellow `UNVERIFIED` banner, distinct from both `MISMATCH` and `HASHED`
4. A successful comparison against MD5 produces a green `MATCH` banner with the weakness noted on the clipboard row
5. A SHA-1 on the clipboard is reported as an unsupported SHA-1, not as an empty clipboard
6. With no explicit `-Algorithm`, a supported clipboard hash determines the algorithm the file is hashed with
7. A clipboard-selected algorithm leaves every sidecar on disk untouched
8. The header always names the algorithm actually computed
9. `VeriHash.ps1 <file> -Algorithm SHA512` computes SHA512 and writes `.sha512`
10. `BatchResult.TallyLine` is byte-identical to its Phase 7 output — same format string, same numbers for the same inputs
11. **No file that any check proved bad ever has a sidecar written or overwritten for it** — including when the comparator abstained and only `SidecarStatus` knew, and including the no-clipboard `.sha512`-sidecar-under-a-SHA256-run case that fails on `main` today
12. A batch containing unverified files reports them as unverified in `BatchResult.Tally` and on every line of the rendered summary — never as `missing`, never silently as `matched`
13. A clipboard-selected MD5 run against a file with an existing `.sha256` reads the file exactly once
14. **No run of VeriHash writes to the path of the file it was asked to verify**, under any algorithm value, and no banner state renders an empty bar

Suggested plan split, in execution order:

- **`09-01` — correctness.** Comparator extraction (as a Core *public*), the algorithm guard, the `UNVERIFIED` state and its palette/banner/checklist rendering, the sidecar-write suppression fix, and `MatchResult = 'unverified'` with both batch consumers updated. Everything here corrects behaviour that is wrong on `main` today. CMP-01, 02, 03, 09, 11, 12.
- **`09-02` — unsupported-hex reporting.** `ConvertTo-VeriHashAlgorithm`'s third outcome, `Read-ClipboardHash`'s record shape, the checklist clause. CMP-10. Split out because it is the only **genuinely new behaviour** in Step 1 rather than a correction, and `09-01` is already the larger plan of the two. The yellow state it feeds is built in `09-01`, so this is purely additive.
- **`09-03` — clipboard-driven algorithm.** Steps 2 and 3 together: `-Algorithm` on the CLI is a prerequisite for Step 2's precedence rule, so they cannot usefully be separated. CMP-04, 05, 06, 07, 08, 13.

The FMT-05 advisory rewording is unrelated to all three and depends on nothing. Ship it whenever convenient — including before `09-01`.

**Do not defer the sidecar-write suppression fix out of `09-01`.** It is the item with live data-loss consequences and it is the reason the phase should not wait behind Phase 8.

## Files touched

| File | Step | Why |
| --- | --- | --- |
| `VeriHash.Core/Public/Resolve-VeriHashComparator.ps1` (new) | 1 | **Public, not Private** — see *Call sites* |
| `VeriHash.Core/VeriHash.Core.psd1` | 1 | `FunctionsToExport` — required, not conditional |
| `VeriHash.Core/Private/ConvertTo-VeriHashAlgorithm.ps1` | 1 | third outcome |
| `VeriHash.Core/Private/Format-VeriHashBanner.ps1` | 1 | `Unverified` / `unusable` in both `ValidateSet`s |
| `VeriHash.Core/Private/Format-VeriHashChecklist.ps1` | 1, 2 | clipboard 4th shape; sidecar `not written` shape + precedence |
| `VeriHash.Core/Private/Get-VeriHashPalette.ps1` | 1 | `BannerWarn` in both colour tables |
| `VeriHash.Core/Public/Read-ClipboardHash.ps1` | 1 | record shape + `.OUTPUTS` doc |
| `VeriHash.Core/Public/Format-VeriHashReport.ps1` | 1, 2, advisory | call the comparator; header attribution |
| `VeriHash.Core/Public/Test-VeriHashSidecar.ps1` | 2 | optional `-Algorithm` pin (stops the double read) |
| `VeriHash.Core/Public/Format-VeriHashBatchTally.ps1` | 1 | `unverified` count + per-file case — **silently wrong without this** |
| `VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1` | 1, 2 | comparator call, suppression rule, `MatchResult`, clipboard-first |
| `VeriHash.HotPath/Public/Invoke-VeriHashBatch.ps1` | 1 | `'unverified'` switch case + `Tally` key — **silently wrong without this** |
| `VeriHash.ps1` | 3 | `-Algorithm` param + help banner |
| `HANDOFF-console-spec.md` | 1, 2, advisory | |
| `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md` | all | |
| `Tests/VeriHash.Core.Comparator.Tests.ps1` (new) | 1 | incl. cross-module reachability |
| `Tests/VeriHash.Core.Read-ClipboardHash.Tests.ps1` | 1 | |
| `Tests/VeriHash.Core.Banner.Tests.ps1` | 1 | |
| `Tests/VeriHash.Core.Checklist.Tests.ps1` | 1, 2 | |
| `Tests/VeriHash.Core.Formatters.Tests.ps1` | 1 | palette + batch tally rendering |
| `Tests/VeriHash.Core.Format-VeriHashReport.Tests.ps1` | 1, 2, advisory | |
| `Tests/VeriHash.Core.Test-VeriHashSidecar.Tests.ps1` | 2 | `-Algorithm` pin; read-count assertion |
| `Tests/VeriHash.HotPath.Tests.ps1` | 1, 2 | suppression cases, tally, read count |
| `Tests/VeriHash.Cli.Tests.ps1` | 3, advisory | |

**Not touched, deliberately:** `VeriHash.Core/Public/Write-VeriHashLog.ps1` and `Format-VeriHashLogLine.ps1` (see the log note in Step 1), `Get-VeriHashDiffIndex.ps1` (the comparator now guarantees equal lengths, so its unequal-length branch becomes unreachable rather than wrong — leave it as the defensive backstop it is), and `.planning/phases/7-output-formatting/07-01-PLAN.md` (historical record).
