# VeriHash console output — implementation spec (handoff)

Target: `Format-VeriHashReport` in VeriHash.Core (dev branch). Rendered with ANSI escape sequences via `$PSStyle` or raw `` `e[ `` codes; PowerShell 7+, Windows Terminal / any VT-capable terminal. Design reference: `VeriHash UI Options.dc.html` options 1a/1b/1c.

## Output order (single file)

1. Header line
2. Verdict banner (blank line above and below)
3. Hash comparison block
4. Checklist grid
5. Footer (path, mtime, pause prompt)

## 1. Header

```pwsh
VeriHash 2.0 · SHA256 · installer.exe (45.32 MB)
VeriHash 2.0 · MD5 (clipboard) + SHA256 · installer.exe (45.32 MB)
```

- Dim gray, except filename in default foreground; size dim.
- `·` separator (U+00B7). Fallback to `-` if console codepage isn't UTF-8 (set `[Console]::OutputEncoding = [Text.UTF8Encoding]::new()` first; VT + UTF-8 is assumed throughout).
- **The algorithm segment is load-bearing.** It names what was actually computed, appends `(clipboard)` when the clipboard selected it, and appends `+ SHA256` when a weak primary earned a companion. A user reading grouped hex by eye has no other signal telling them which algorithm is on screen, and comparing an MD5 against a vendor page's SHA256 by eye is a silent failure.

## 2. Verdict banner

One full-width-of-content line, reversed video (colored BACKGROUND, not colored text) — this is the only filled element on screen and readable at a glance.

| State | Text | BG (truecolor) | FG |
| --- | --- | --- | --- |
| Match | `✓  MATCH — SHA256 matches hash on clipboard` | `38;200;134` (green) | near-black `8;23;13` |
| Mismatch | `✗  MISMATCH — file does NOT match clipboard hash` | `211;69;49` (red) | white |
| Unverified | `!  UNVERIFIED — {reason}` | amber `210;153;34` | near-black `28;20;2` |
| No clipboard hash | `●  HASHED — no hash on clipboard to compare against` | gray `48;54;61` | default fg |

- Pad the line to a fixed width (e.g. 76 cols or `[Console]::WindowWidth - 4`, whichever is smaller) so the bar reads as a bar.
- Sidecar-only verification uses the same MATCH/MISMATCH banners with `— SHA256 matches sidecar file` wording when no clipboard hash exists but a sidecar does.
- **UNVERIFIED means the user supplied a hash and VeriHash could not compare it** — a wrong algorithm for this run, or a length it does not implement. `{reason}` is the comparator's explanation, e.g. `clipboard holds MD5; this run computed SHA256`. It is distinct from HASHED, which means the user never asked. Yellow marks a condition the user can clear; it must never mark a *successful* comparison against a weak algorithm, because a signal that can never go green stops being read.
- Fallback when truecolor unavailable: `$PSStyle.Background.Green/Red` + black/white FG.

## 3. Hash comparison block

Both hashes, chunked into 8-char groups separated by single spaces, expected above computed so agreement reads as columns:

```pwsh
expected  clipboard
71792c02 8e07b0fd d30f4e2a 9c1b3d5e 8a46f1c2 9d073bb5 e6c48d90 a2f1e3b7
computed  52 ms
71792c02 8e07b0fd d30f4e2a 9c1b3d5e 8a46f1c2 9d073bb5 e6c48d90 a2f1e3b7
```

- Labels dim gray; hex in soft blue (`121;184;255`).
- MISMATCH: find the first differing character index `i`. Every 8-char group containing index ≥ floor(i/8)*8 onward renders with dark-red background (`92;30;25`) + light-red FG (`255;160;150`) on BOTH lines, matching prefix groups stay blue. Then one dim line:
  `first {i} of {len} characters agree — divergence starts at character {i+1}`
- No-clipboard state: single `sha256` label + one hash line, no comparison.
- MD5 = 4 groups, SHA1 = 5 groups, SHA512 = 16 groups (wrap at console width; keep group boundaries).
- **Companion block.** When a weak primary (MD5, SHA1) earned a SHA256 companion, its digest follows the comparison after a blank line, under a 10-char label and its own timing:

```pwsh
sha256    2018 ms
9f2b1a44 6c30e7d1 4b8e0a35 c7d21f60 8ae4b913 20fc55d7 e1a3b846 7c0d9e22
```

  Separate on purpose: the banner answers the one question the user asked, and a second digest folded into the comparison would make the verdict ambiguous about which hash it refers to.

## 4. Checklist grid

Two columns: 10-char left-aligned label (dim gray), value. One glyph + one clause per row.

```pwsh
clipboard   ✓ match (plain hex, SHA256)
sidecar     ✓ match — installer.exe.sha256
signature   ✓ valid — {signer CN}
elapsed     52 ms · 45.32 MB · ~872 MB/s
```

Glyphs/colors: `✓` green, `✗` red, `!` dark yellow (`210;153;34`), `−` gray.

- **Weak-algorithm clause.** An MD5 or SHA1 comparison appends `— weak; prefer SHA256 if the vendor lists one` (preceded by a space) inside the parenthetical, on match *and* mismatch:

```pwsh
clipboard   ✓ match (plain hex, MD5 — weak; prefer SHA256 if the vendor lists one)
```

  It never reaches the banner. A successful MD5 comparison is green: the comparison is not uncertain, and the weakness belongs to the vendor's choice rather than to the verification. Yellow is reserved for *your question went unanswered*, which the user can clear.

Row values by state:

- clipboard: `✓ match (…)` / `✗ mismatch (…)` / `− nothing recognizable — copy the vendor's hash and re-run`. Parenthetical = detected format: `plain hex, SHA256` or `prefixed, sha256:`.
- sidecar: `✓ match — {name}` / `✓ created — {name}` / `✗ sidecar mismatch — {name}` / `− none found · not written on mismatch` (do NOT write/update a sidecar when the clipboard verdict is MISMATCH).
- signature: `✓ valid — {signer}` / `✗ invalid — {reason}` / `! unsigned` / `− skipped (not a PE file)`.
- elapsed: `{ms} ms · {size} · ~{size/seconds} MB/s` (one decimal max on MB/s below 10; integer otherwise; use GB/s ≥ 1000).

## 5. Footer

Dim gray: `{full path} · modified {yyyy-MM-dd HH:mm} UTC`, blank line, then existing pause prompt (`Press any key to close…`) unless `-NoPause`.

MISMATCH adds, before the footer, a red-bordered advisory (top/bottom rule of `─` in dim red, or just a red-text line if simpler):
`Recommendation: Do not run this file. Re-download it, then verify again.`

## Batch mode

Per-file: header + banner + checklist only (skip the hash comparison block except for mismatched files). After the last file, a tally footer separated by a dim rule:

```pwsh
batch of 3 · 2 matched · 1 mismatch · 0 missing
 ✓ setup-x64.exe      match · signed
 ✓ setup-arm64.exe    match · signed
 ✗ langpack.msi       mismatch
```

Counts colored: matched green, mismatch red (only when > 0), missing dim.

## Color palette (truecolor RGB)

- bg assumption: user's terminal (do not set a background)
- default fg: terminal default · dim: `110;118;129` · faint: `72;79;88`
- green `63;222;134` (glyphs) / banner bg `38;200;134`
- red `229;83;75` (glyphs) / banner bg `211;69;49` / diff bg `92;30;25` / diff fg `255;160;150`
- dark yellow `210;153;34` · blue (hex) `121;184;255`

## Behavior notes

- Exit codes unchanged (0 match/hashed, 1 mismatch…).
- `-Log` line format unchanged; this spec is display-only.
- Keep all strings exactly as written above for testability (Pester can assert on them).
