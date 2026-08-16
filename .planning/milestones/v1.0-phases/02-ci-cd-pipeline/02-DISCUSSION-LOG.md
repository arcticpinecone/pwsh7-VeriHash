# Phase 2: CI/CD Pipeline - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-18
**Phase:** 02-ci-cd-pipeline
**Areas discussed:** Workflow trigger & branch strategy, Platform matrix & OS coverage, Lint expansion approach, Dependency pinning & caching

---

## Workflow Trigger & Branch Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Push to dev + main, plus all PRs | Catches regressions on both active branches, validates PRs before merge | ✓ |
| All PRs only | Leanest, but regressions on direct pushes go undetected | |
| Push to all branches + all PRs | Broadest — runs on every push to any branch | |

**User's choice:** Push to dev + main, plus all PRs
**Notes:** Recommended option — balances coverage with CI resource usage

| Option | Description | Selected |
|--------|-------------|----------|
| Single workflow file | Simpler to maintain; tests + lint in one ci.yml | ✓ |
| Separate workflows | Tests.yml + lint.yml run independently | |

**User's choice:** Single workflow file for everything

| Option | Description | Selected |
|--------|-------------|----------|
| Parallel jobs: test (matrix) + lint (single) | Lint doesn't need OS matrix, tests do; runs faster | ✓ |
| Sequential steps in one job per OS | Simpler YAML, but lint runs twice | |

**User's choice:** Parallel jobs: test (matrix) + lint (single)

| Option | Description | Selected |
|--------|-------------|----------|
| Filter to .ps1 and Tests/ changes only | Skip CI for README edits, docs, etc. | ✓ |
| Run on all changes | Simplest; no missed triggers | |

**User's choice:** Filter to .ps1 and Tests/ changes only

---

## Platform Matrix & OS Coverage

| Option | Description | Selected |
|--------|-------------|----------|
| ubuntu-latest + windows-latest only | Matches roadmap requirements; macOS out-of-scope | ✓ |
| Add macos-latest too | Broader coverage, but macOS context-menu isn't implemented | |

**User's choice:** ubuntu-latest + windows-latest only

| Option | Description | Selected |
|--------|-------------|----------|
| Latest pwsh only | Project requires 7+; GitHub Actions runners ship current pwsh | ✓ |
| pwsh 7.2 LTS + latest | Broader compat, adds matrix complexity | |

**User's choice:** Latest pwsh only

| Option | Description | Selected |
|--------|-------------|----------|
| pwsh (PowerShell 7+) shell only | Matches project requirement | ✓ |

**User's choice:** pwsh shell only — confirmed

---

## Lint Expansion Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Run PSScriptAnalyzer directly in CI against all 3 files | Explicit, doesn't depend on Test-All.ps1 | ✓ |
| Use Test-All.ps1 after expanding it | Reuses existing runner | |

**User's choice:** Run PSScriptAnalyzer directly in CI

| Option | Description | Selected |
|--------|-------------|----------|
| Fail on Error and Warning | Matches PSScriptAnalyzerSettings.psd1 severity config | ✓ |
| Fail on Error only | Lenient, warnings could accumulate | |

**User's choice:** Fail on Error and Warning

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, expand Test-All.ps1 too | Keeps local and CI behavior consistent | ✓ |
| No, only fix CI | Local lint stays VeriHash.ps1 only | |

**User's choice:** Yes, expand Test-All.ps1 too

---

## Dependency Pinning & Caching

| Option | Description | Selected |
|--------|-------------|----------|
| Pin Pester to 5.x + PSSA to latest | Prevents Pester 6 breakage; PSSA is stable | ✓ |
| Pin both to exact versions | Strictest, requires manual version bumps | |
| Pin Pester only | Minimum needed for CICD-04 | |

**User's choice:** Pin Pester to 5.x (MaximumVersion 5.99) + PSScriptAnalyzer to latest

| Option | Description | Selected |
|--------|-------------|----------|
| No caching — install fresh each run | Simplest; fast install ~10-15s | ✓ |
| Cache PowerShell modules | Faster re-runs, more YAML complexity | |

**User's choice:** No caching

| Option | Description | Selected |
|--------|-------------|----------|
| Skip PSFramework in CI | Optional, tests work without it | ✓ |
| Install PSFramework in CI | Broader coverage | |

**User's choice:** Skip PSFramework in CI

---

## Agent's Discretion

- Exact YAML structure and step naming
- `Install-Module` vs `Install-PSResource` choice
- Test results upload format
- Workflow concurrency settings

## Deferred Ideas

None — discussion stayed within phase scope.
