---
phase: 2
slug: ci-cd-pipeline
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Pester 5.7.1 |
| **Config file** | None — configuration built inline (project convention) |
| **Quick run command** | `pwsh -Command "Invoke-Pester ./Tests -Output Detailed"` |
| **Full suite command** | `pwsh -File ./Test-All.ps1 -CI` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `pwsh -Command "Invoke-Pester ./Tests -Output Detailed"`
- **After every plan wave:** Run `pwsh -File ./Test-All.ps1 -CI`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | CICD-01 | — | N/A | smoke | Push commit; check Actions tab for workflow trigger on ubuntu + windows | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | CICD-02 | — | N/A | smoke | Push commit with known PSSA violation; verify red CI | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 1 | CICD-04 | — | N/A | inspection | Verify `MaximumVersion 5.99` in ci.yml | ❌ W0 | ⬜ pending |
| 02-02-01 | 02 | 1 | CICD-03 | — | N/A | unit | `pwsh -Command "Invoke-ScriptAnalyzer -Path ./VeriHash.Config.ps1 -Settings ./PSScriptAnalyzerSettings.psd1"` | ✅ (LogUtils inline test exists) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `.github/workflows/` directory — must be created
- [ ] Verify `VeriHash.Config.ps1` passes PSSA before adding to CI lint (run locally first)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| CI triggers on push/PR | CICD-01 | Requires actual GitHub push | Push a commit to `dev`; verify Actions tab shows workflow run on both OS runners |
| CI blocks failing PR | CICD-01, CICD-02 | Requires actual PR | Open PR with a failing test or PSSA violation; verify checks fail |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
