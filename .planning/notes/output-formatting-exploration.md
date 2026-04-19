---
title: Output formatting exploration — modern middle-path
date: 2026-04-19
context: Post-v2.0 ideation — comparing v1 presentation style with v2 structured output
---

# Output Formatting Exploration

## Problem

v2 output is functionally correct but lost the "presentation ceremony" of v1 — the section headers, friendly dates, hash speed, start/end timestamps, and clean dividers that made the output scannable and factual. Users want a "clear summation of their check."

## Design Decision: Two Modes

**Single-file → rich report** (read and understand one file)
**Batch → compact table** (scan and confirm across many files)

## Single-File Report Layout

```
--- VeriHash Report ---

File selected:    {filename}
---
Start UTC:        {iso timestamp}

[Metadata]
  File Path:      {full path}                     (Cyan)
  File Size:      {human MB/GB}  ({bytes} bytes)  (Yellow)
  Created:        {Month Day, Year | HH:mm:ss}    (Gray)
  Modified:       {Month Day, Year | HH:mm:ss}    (Gray)

[Signature]
  Authenticode:   {status} ({reason})              (Green/Yellow/Red)

[Hash - {ALGORITHM}]
  Hash:           {full hash lowercase}            (Green)
  Hash time:      {seconds}  ({ms} ms)             (Gray)
  Hash speed:     {MB/s}                           (Gray)

[Verification]
  Clipboard:      {MATCH|MISMATCH} ({algorithm})   (Green/Red)
  Sidecar:        {filename.sha256}                (Green/Red)

---
Completed:        {Month Day, Year | HH:mm:ss}     (Gray)
Total time:       {seconds}  ({ms} ms)              (Gray)
```

## Batch Table Layout

```
--- VeriHash Batch ---
  Directory:  {common parent}                       (Cyan)
  Files:      {count}                               (Cyan)
  Algorithm:  {algo}                                (Cyan)

File                            Size    Hash (first 12)  Time   Speed       Status
----                            ----    ---------------  ----   -----       ------
{filename}                      {size}  {hash12}...      {time} {MB/s}      {OK|MISMATCH|MISSING}

{m}/{n} matched, {x} mismatch, {z} missing
---
Total time:       {seconds}
Total size:       {human total}
```

## Colour Language (6 colours, consistent everywhere)

| Meaning                      | Colour   |
|------------------------------|----------|
| Good / Pass / Match          | Green    |
| Bad / Fail / Mismatch        | Red      |
| Warning / Missing / Unsigned | Yellow   |
| Info / Labels / Section hdrs | Cyan     |
| Neutral / Timestamps         | Gray     |
| Emphasis / Filename          | White    |

No magenta, no dark colours that vanish on dark terminals. No emoji — terminals vary too much.

## Implementation Notes

- `Format-VeriHashReport` (VeriHash.Core) handles single-file rendering
- Batch table uses `Format-Table -AutoSize` for column fitting
- Hash speed = Size / ElapsedMs * 1000 / 1MB
- Friendly date format: `MMMM d, yyyy | HH:mm:ss`
- Truncated hash in batch: first 12 chars + `...`
- Status column in batch: OK (green), MISMATCH (red), MISSING (yellow)
  - Note: `Format-Table` doesn't natively support per-cell colour; implementation will need Write-Host with calculated column widths or a custom table renderer
