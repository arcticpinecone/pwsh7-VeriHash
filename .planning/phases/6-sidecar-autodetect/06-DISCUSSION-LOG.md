# Phase 6: Sidecar Auto-Detect - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-19
**Phase:** 6-sidecar-autodetect
**Areas discussed:** Verify behavior, Supported extensions, Clipboard interaction, Hash length mismatch

---

## Verify Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Full hot-path | Same output as right-clicking the companion directly (signature, clipboard, metadata, timing) | |
| Focused verify | Hash + compare + pass/fail only | ✓ |
| You decide | Agent's discretion | |

**User's choice:** Focused verify (hash + compare + pass/fail only)
**Notes:** User chose this because right-clicking a sidecar is an "answer one question" action — does the companion match?

---

## Supported Extensions

| Option | Description | Selected |
|--------|-------------|----------|
| .sha256, .sha512, .md5 only | Matches existing manifest + sidecar code | ✓ |
| Add .sha2 and .sha2_256 too | v1 compatibility | |
| You decide | Agent's discretion | |

**User's choice:** Three canonical extensions only (.sha256, .sha512, .md5)
**Notes:** Keeps consistent with v2 codebase. Legacy v1 extensions dropped in the rebuild.

---

## Clipboard During Sidecar Verify

| Option | Description | Selected |
|--------|-------------|----------|
| Skip clipboard | Sidecar is the authority — no clipboard noise | ✓ |
| Still check clipboard | Show both comparisons | |
| You decide | Agent's discretion | |

**User's choice:** Skip clipboard during sidecar verify
**Notes:** Avoids confusing dual-comparison scenario (sidecar says match, clipboard from different source says mismatch).

---

## Hash Length Mismatch

| Option | Description | Selected |
|--------|-------------|----------|
| Clear error | Stop and tell user exactly what's wrong | |
| Warn but still attempt comparison | Best-effort — computed hash still shown | ✓ |
| You decide | Agent's discretion | |

**User's choice:** Warn but still attempt comparison (best-effort)
**Notes:** User gets the computed hash even when sidecar is corrupted, so they can compare manually or fix the sidecar.

---

## Agent's Discretion

- Module placement of the auto-detect function
- Internal routing logic structure
- Whether Read-SidecarLine needs promotion from private
- Exact error message wording
- Test structure and mock strategy

## Deferred Ideas

None — discussion stayed within phase scope.
