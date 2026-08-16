---
title: Manifest verify summary undercounts — parse-error and traversal-rejected entries vanish
date: 2026-08-16
source: switch-default audit during Phase 9 comparator exploration
severity: moderate — fails loud (red, exit 3) but the summary arithmetic is false
area: VeriHash.Manifest
---

# Manifest Summary Undercounts Rejected Entries

## Problem

`Test-VeriHashManifest` produces **five** entry statuses and counts **three**. Entries in the other two categories are included in `Total` but in none of the buckets, so the rendered summary does not add up.

Statuses produced:

| Status | Set at | Counted? |
| --- | --- | --- |
| `parse-error` | [Test-VeriHashManifest.ps1:53](../../../VeriHash.Manifest/Public/Test-VeriHashManifest.ps1#L53) | **no** |
| `traversal-rejected` | [:69](../../../VeriHash.Manifest/Public/Test-VeriHashManifest.ps1#L69) | **no** |
| `missing` | [:87](../../../VeriHash.Manifest/Public/Test-VeriHashManifest.ps1#L87), [:102](../../../VeriHash.Manifest/Public/Test-VeriHashManifest.ps1#L102) | yes |
| `pass` | [:113](../../../VeriHash.Manifest/Public/Test-VeriHashManifest.ps1#L113) | yes |
| `mismatch` | [:122](../../../VeriHash.Manifest/Public/Test-VeriHashManifest.ps1#L122) | yes |

The counts at [:133-135](../../../VeriHash.Manifest/Public/Test-VeriHashManifest.ps1#L133-L135):

```powershell
$passedCount  = ($entries | Where-Object { $_.Status -eq 'pass'     }).Count
$failedCount  = ($entries | Where-Object { $_.Status -eq 'mismatch' }).Count
$missingCount = ($entries | Where-Object { $_.Status -eq 'missing'  }).Count
```

`Total` is `$entries.Count` — every status. The three buckets are three named statuses. Nothing reconciles them.

## Reproduction

A 10-line manifest, 8 entries valid, 2 entries with `../` paths that `Test-PathTraversal` rejects:

```text
  ok/a.bin: pass
  ...
  ../../etc/passwd: traversal-rejected
  ../../../secrets.txt: traversal-rejected
8/10 passed, 0 mismatch, 0 missing
```

**8 + 0 + 0 ≠ 10.** Two entries are absent from the accounting, and they are the two a security guard rejected.

## What already works

This is not a fail-green, which is why it is filed rather than folded into Phase 9:

- `traversal-rejected` and `parse-error` both set `$hasParseError`, so `ExitCode` is correctly `3` ([:128](../../../VeriHash.Manifest/Public/Test-VeriHashManifest.ps1#L128)).
- The tally line renders red, because [VeriHash.ps1:200](../../../VeriHash.ps1#L200) colours on `ExitCode -ne 0`.
- Each rejected entry prints its own red line — [VeriHash.ps1:192-197](../../../VeriHash.ps1#L192-L197)'s `switch` has `default { 'Red' }`, so unknown statuses render alarming rather than reassuring.

The user is warned. The summary line is simply arithmetically false about what it counted, and silently so.

## Fix sketch

Two parts, and the second matters more than the first:

1. **Report the rejected entries.** Either add a `Rejected` count to `Summary` and the rendered line, or fold both statuses into `Failed`. Adding a field is preferable — `traversal-rejected` is a security rejection, not a hash mismatch, and collapsing them loses that.
2. **Make the buckets reconcile by construction.** The bug is that `Total` and the buckets are derived independently, so drift is undetectable. Derive one from the other — count by grouping over `Status`, or assert `Passed + Failed + Missing + Rejected -eq Total` and throw if not. A test asserting the sum equals `Total` for a manifest containing all five statuses is the regression guard.

## Related

Same failure class as the batch-tally finding in `.planning/notes/comparator-algorithm-exploration.md` (*The batch tally*): a producer with N values, consumers written for N-1, and a fallback that absorbs the difference without complaint. That one is being fixed in Phase 9; this one is a different module and a different feature, so it is tracked separately.

The generalised lesson is recorded as **CMP-14** in that note: a value outside a closed set must never resolve to a silent fallback.
