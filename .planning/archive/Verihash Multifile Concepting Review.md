# Verihash Multifile Concepting Review

## What's solid in your concept

- **GNU `sha256sum` format** — right call. Free interop with `sha256sum -c`, 7-Zip, Total Commander, etc. Don't invent a format.
- **UTF-8 no BOM** — correct.
- **Temp file + atomic rename** — correct pattern. Your `Write-IndexAtomically` snippet is good.
- **"Index is a snapshot"** mental model — this is the single most important idea in your doc. Keep it, enforce it, don't let features erode it.
- **Skip `.sha*`/`.md5` files when creating** — correct and simple.
- **Parameter sets for `-Create`/`-Verify`/`-Update`/`-Compare`** — correct PowerShell idiom.

## What I'd cut or defer

Trim to what actually matches the "right-click some files → get a manifest" goal:

| Feature | Verdict |
| - | - |
| Recursive folder hashing | **Cut for MVP.** You said it — less frequent, more complexity (symlinks, permissions, enumeration errors). Add in a later phase if a real need shows up. |
| Smart-entry folder detection (0/1/N indexes) | **Cut.** Only matters if folders are in scope. |
| Parent-directory index discovery for single files | **Cut.** Neat idea, low payoff, adds surprise behavior. |
| Sidecar import / cleanup | **Cut.** Side-quest. Your existing sidecar flow already works. |
| `-Update`, `-Compare` | **Defer.** Not needed for the use case you described. Users can just make a new manifest. |
| GUI options dialog (before hashing) | **Cut for MVP.** Right-click → go. Save dialog *after* is enough. |
| Index discovery dialog | **Cut.** See above. |
| Two-phase streaming counter + batched summary with 50-issue threshold + auto report file | **Simplify.** Just stream results and print a summary. Write a report file only on `-Report` or if `>N` failures — don't build the whole tiered output system yet. |
| Permission pre-check with Skip/Abort/Cancel dialog | **Simplify.** Catch per-file read failure during hashing, record as "unreadable", continue, summarize at end. A pre-pass adds I/O and complexity for a rare case. |
| Signature column in index | **Cut permanently from the index.** Breaks `sha256sum -c` compatibility. If you want it, separate sidecar report. |
| `-TrustImports` / `-VerifyImports` / `-CleanSidecars` | **Cut.** |

## The simpler MVP that matches what you actually want

**Two Send To entries:**

1. `VeriHash` (existing) — single-file sidecar flow. Unchanged.
2. `VeriHash — Manifest` (new) — the multi-file flow.

**Behavior of the new entry:**

- Input = N file paths (what Explorer passes when you multi-select and Send To). Ignore folders for MVP, or error out with a clear message: *"Folder input not supported yet. Select files directly."*
- Input = 1 path ending in `.sha256`/`.sha512`/`.md5` → **verify** mode.
- Otherwise → **create** mode.
- All files must share a common parent directory (single-root rule you proposed). If they don't, error: *"Selected files span multiple directories. Manifest uses relative paths — pick files under one root."*

**Create flow:**

1. Filter out any `.sha256`/`.sha512`/`.sha384`/`.sha1`/`.md5` inputs (can't hash an index as content).
2. Hash sequentially with a small queue — you said "so it doesn't make the CPU go crosseyed." `ForEach-Object -Parallel -ThrottleLimit 2` is plenty. Don't auto-tune yet. Just `2`.
3. Write to `~verihash-<guid>.tmp` in the common root.
4. On success, atomic rename to `YYYY-MM-DDTHHMMSSZ.sha256` in the common root (no save dialog for MVP — predictable and scriptable; a save dialog can come later).
5. On Ctrl+C / error → delete temp file. You already have a clean pattern for this.

**Verify flow:**

1. Parse the index (strict: `^([0-9a-fA-F]{hashlen})[ ](\*| )(.+)$`).
2. Resolve each entry relative to the **index file's directory** — not CWD. This is the single biggest foot-gun to get right.
3. Re-hash each, stream `✅`/`❌`/`⚠️ missing` as you go.
4. Summary at end. Exit code: `0` all good, `1` any mismatch, `2` any missing, `3` parse error. Machine-readable without parsing stdout.

## Concrete improvements to your doc / code

**1. Timestamp format.** Your doc says `YYYY-MM-DDTHHMMSS.sha256`. Add a `Z` so it's unambiguously UTC and valid ISO-8601: `2026-04-16T143022Z.sha256`. Colons would be nicer but are illegal in Windows filenames, so your compact form is right — just mark UTC.

**2. Path separator on read.** You say "store `/`, accept `\`". Good. Also normalize to `/` when **hashing** for the manifest write, so the same file hashed on Windows and Linux produces byte-identical manifest lines. Means `sha256sum -c` on WSL works on a Windows-created manifest.

**3. Path traversal guard.** When verifying, reject any entry whose resolved path escapes the index's root directory (`..\..\etc\passwd`). You flagged this in Security; make it a hard rule, not a todo.

**4. Skip-extension list is incomplete.** Add `.sha2_256` (your own existing format!) and `.sha2_512` if you use those. Grep shows you do (VeriHash.ps1 line 41). Don't hash your own sidecars into a manifest.

**5. Existing code reuse.** Your `Get-And-SaveHash` already handles per-file hashing cleanly. The manifest path should call the underlying `Get-FileHash` directly and skip the sidecar logic — don't try to reuse `Get-And-SaveHash`, it'll drag sidecar-creation side effects in. Factor out a tiny `Get-FileHashOnly` helper if you want DRY.

**6. SendTo install.** Your `Install-WindowsSendTo` makes one `.lnk`. For the manifest entry, add a second `.lnk` (`VeriHash — Manifest.lnk`) that passes a `-Manifest` switch. Same function, parameterized:

```powershell
function Install-WindowsSendTo {
    param([switch]$ManifestMode)
    $name = if ($ManifestMode) { 'VeriHash - Manifest.lnk' } else { 'VeriHash.lnk' }
    $extraArg = if ($ManifestMode) { ' -Manifest' } else { '' }
    # ...existing shortcut creation, append $extraArg to $arguments
}
```

Then `-SendTo` installs both. One flag, two shortcuts, minimal new code.

**7. Windows Send To argument limits.** Explorer passes each selected file as a separate argument. PowerShell + `.lnk` handles this fine, but long paths × many files can exceed ~8KB command line. Not an MVP blocker, but document the limit and, if you hit it, the fallback is reading paths from stdin or a temp file. Don't pre-build for this.

**8. Tests.** Your Tests/ folder already has Pester. Minimum new test files:

- `Tests/VeriHash.Manifest.Tests.ps1` — create→verify roundtrip, tampered file detected, missing file detected, `sha256sum -c` compatibility (invoke WSL if available, skip otherwise), path-traversal rejected, mixed-root input rejected.

## Recommended phase 1 scope (what to actually build)

1. `-Manifest` switch + routing (create vs verify based on input).
2. Common-root validation.
3. GNU-format writer with atomic temp→rename.
4. GNU-format parser with strict regex + path-traversal guard.
5. Sequential or `-ThrottleLimit 2` parallel hashing.
6. Streaming output + end summary + exit codes.
7. Second SendTo shortcut.
8. Tests for the above.

Everything else in your doc → move to a "Later" section. You'll know if you actually want it after using this for a few weeks.

Want me to draft the implementation plan into plan.md and implementation.md following your AGENTS.md workflow? Or edit the concept doc in place to reflect this trimmed scope?
