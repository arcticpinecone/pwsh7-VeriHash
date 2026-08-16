# Roadmap — VeriHash

## Shipped Milestones

- ✅ **v3.0 UX Polish & Smart Routing** (2026-08-16) — 3 phases, 32/32 in-scope requirements, 371 tests. [Full archive →](milestones/v3.0-ROADMAP.md)
- ✅ **v2.0 Modular Rebuild** (2026-04-19) — 5 phases, 15 plans, 38/38 requirements. [Full archive →](milestones/v2.0-ROADMAP.md)
- ✅ **v1.0 Privacy + Foundation** (2026-04-18) — 3 phases, 6 plans, 11/11 requirements. [Full archive →](milestones/v1.0-ROADMAP.md)

## Next Milestone

_Not yet planned._

## Backlog

### Manifest Spot-Check — deferred from v3.0

Already specified as SPOT-01..05 in
[v3.0-REQUIREMENTS.md](milestones/v3.0-REQUIREMENTS.md) → Future Requirements, so this is
the cheapest milestone to open: the requirements exist and only need phasing and plans.

With `-Manifest` and a single file, auto-detect an existing manifest in the same directory
and spot-check that one entry instead of creating a new manifest.

Deferred because it is additive — nothing VeriHash reports today is wrong without it, and
a user can already verify a whole manifest. Holding a release that contained finished
correctness work in exchange for unstarted convenience was the wrong trade.

### Cross-platform clipboard

`Read-ClipboardHash` returns `$null` on non-Windows. v1.3.0 had Linux clipboard support
via `wl-paste`/`xclip`/`xsel`; the modular rewrite did not carry it forward, so Linux
users get sidecar and manifest verification but no clipboard comparison.

### Phase 999.2 / 999.3 — ✅ RESOLVED

Both resolved in commit `e7bb55a` during v2.0: format views via
`VeriHash.HotPath.format.ps1xml`, and `Test-ModuleManifest` warnings via repo root on
`$env:PSModulePath`.
