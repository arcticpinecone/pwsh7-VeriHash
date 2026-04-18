# Phase 2: CI/CD Pipeline - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Every push and PR is automatically validated — tests pass cross-platform, lint is clean across all modules. GitHub Actions workflow runs Pester tests and PSScriptAnalyzer on ubuntu-latest + windows-latest. A PR that introduces a violation or failure cannot pass CI.

</domain>

<decisions>
## Implementation Decisions

### Workflow trigger & branch strategy
- **D-01:** Single workflow file (`ci.yml`) — tests and lint in one file, simpler to maintain
- **D-02:** Triggers on push to `dev` and `main` branches, plus all PRs targeting those branches
- **D-03:** Path filters active — CI only runs when `.ps1` files or `Tests/` directory change (skips README, docs-only edits)
- **D-04:** Parallel jobs within the workflow: a test job (OS matrix) and a lint job (single runner) run concurrently

### Platform matrix & OS coverage
- **D-05:** OS matrix: `ubuntu-latest` + `windows-latest` only — macOS excluded per PROJECT.md out-of-scope
- **D-06:** PowerShell version: latest `pwsh` only — project requires 7+, no multi-version matrix
- **D-07:** All workflow steps use `shell: pwsh` — no Windows PowerShell 5.x

### Lint expansion approach
- **D-08:** CI runs PSScriptAnalyzer directly against all 3 files (`VeriHash.ps1`, `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`) — not via Test-All.ps1
- **D-09:** CI fails on both Error and Warning severity findings — matches `PSScriptAnalyzerSettings.psd1` configuration
- **D-10:** `Test-All.ps1` is also updated to lint all 3 files locally — keeps local and CI behavior consistent

### Dependency pinning & caching
- **D-11:** Pester pinned to 5.x (`MaximumVersion 5.99`) — prevents Pester 6 auto-install breakage (CICD-04)
- **D-12:** PSScriptAnalyzer installed at latest (not pinned to exact version) — stable module, no breakage risk
- **D-13:** No module caching between runs — fresh install each time; module install is fast (~10-15s) and avoids cache invalidation complexity
- **D-14:** PSFramework is NOT installed in CI — it's optional, tests work without it, keeps CI fast

### Agent's Discretion
- Exact YAML structure and step naming within the workflow
- Whether to use `Install-Module -Force -Scope CurrentUser` or `Install-PSResource`
- Test results upload format (if any — e.g., Pester NUnit XML)
- Workflow concurrency settings (cancel in-progress runs on new push or not)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### CI/CD requirements
- `.planning/REQUIREMENTS.md` — CICD-01 through CICD-04 define the exact requirements for this phase
- `.planning/ROADMAP.md` §Phase 2 — Success criteria with 4 verifiable conditions

### Existing test infrastructure
- `Test-All.ps1` — Current test runner with `-CI` flag; lint expansion target (D-10)
- `PSScriptAnalyzerSettings.psd1` — Lint rules to reuse in CI; excluded rules with justification

### Codebase concerns
- `.planning/codebase/CONCERNS.md` §Missing Critical Features — Documents "No CI/CD Pipeline" and "PSScriptAnalyzer Does Not Analyze Config/LogUtils"
- `.planning/codebase/TESTING.md` — Full test patterns, run commands, and isolation requirements

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Test-All.ps1` with `-CI` flag: Ready-made entry point that exits with error code on failure — can be invoked from workflow for tests
- `PSScriptAnalyzerSettings.psd1`: Complete linter config with justified exclusions — reuse via `-Settings` parameter in CI
- `Tests/` directory: 5 test files covering VeriHash.ps1, Config, LogUtils, Timing, and QuickHash

### Established Patterns
- Test isolation: `$env:VERIHASH_TEST_MODE = '1'` in every `BeforeAll` — CI needs no special env setup
- Platform-conditional skipping: Tests use `Set-ItResult -Skipped` for OS-specific tests — matrix handles this naturally
- PSScriptAnalyzer as inline test: `VeriHash.LogUtils.Tests.ps1` already has an inline PSSA check as a Pester test

### Integration Points
- `.github/workflows/ci.yml` — new file, no existing workflows to conflict with
- `Test-All.ps1` line 116 — `$scriptPath` variable needs expanding from single file to array of 3 files (D-10)

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches for GitHub Actions PowerShell CI.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-ci-cd-pipeline*
*Context gathered: 2026-04-18*
