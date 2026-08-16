# Research Summary: VeriHash CI/CD Foundation

**Domain:** CI/CD automation for an existing PowerShell 7+ CLI tool
**Researched:** 2026-04-17
**Overall confidence:** HIGH

## Executive Summary

The CI/CD ecosystem for PowerShell 7+ open-source tools on GitHub is mature and well-documented. GitHub Actions provides first-class PowerShell support: `pwsh` is pre-installed on all runner OS images (Ubuntu, Windows, macOS), and `shell: pwsh` works identically across platforms. The community has converged on a simple pattern: raw `pwsh` steps invoking Pester and PSScriptAnalyzer directly, rather than third-party wrapper actions.

VeriHash is well-positioned for CI adoption. The project already has a `Test-All.ps1` runner with a `-CI` flag, a `PSScriptAnalyzerSettings.psd1` configuration file, and 133 passing Pester 5.x tests using the modern `New-PesterConfiguration` API. The main gaps are: (1) no `.github/workflows/` file exists yet, (2) PSScriptAnalyzer only targets `VeriHash.ps1` (Config and LogUtils are unlinted), and (3) the test runner doesn't produce machine-readable output (NUnit XML) or use Pester's native GitHub Actions annotation format.

The recommended stack is GitHub Actions with `ubuntu-latest` as the primary runner (faster, proves cross-platform) and `windows-latest` in a matrix (catches Windows-only regressions). Pester should stay on v5.x — Pester 6 introduces breaking changes with no benefit for this milestone. PSScriptAnalyzer v1.25 (March 2026) is current and compatible. All invocations should use raw `pwsh` steps rather than marketplace wrapper actions.

The biggest risk is not technical but operational: ensuring the CI workflow is strict enough to catch real issues (fail on PSScriptAnalyzer warnings, not just errors) while not being so noisy that developers ignore it (exclude the rules already justified in the settings file).

## Key Findings

**Stack:** GitHub Actions + `ubuntu-latest`/`windows-latest` matrix + Pester 5.x + PSScriptAnalyzer 1.25 — all via raw `pwsh` steps
**Architecture:** Single workflow file with separate lint job (fast, OS-independent) and matrix test job (cross-platform)
**Critical pitfall:** Pester 6 auto-install — if the CI workflow doesn't pin `MaximumVersion 5.99`, a runner image update could install Pester 6 and break all 133 tests

## Implications for Roadmap

Based on research, suggested phase structure:

1. **Logging Compliance** — Fix the privacy violations first
   - Addresses: Hash truncation, path sanitization, log rotation
   - Avoids: Shipping CI without having the code in a clean state first
   - Rationale: CI is a safety net — it's most valuable when the codebase it guards is already correct

2. **CI/CD Pipeline** — Add the automated regression net
   - Addresses: GitHub Actions workflow, expanded PSScriptAnalyzer coverage, NUnit XML reporting
   - Avoids: The Pester 6 trap (pin to 5.x), marketplace action dependency trap
   - Rationale: Once logging is compliant, CI locks in that compliance for all future changes

3. **Small Wins Bundle** — VT default flip, PSFramework dedup, log rotation config
   - Addresses: Remaining audit items from CONCERNS.md
   - Rationale: These are low-risk changes that CI now protects from regression

**Phase ordering rationale:**
- Logging fixes before CI because: CI catches regressions. If you add CI first, then fix logging, the CI history shows "broken → fixed." If you fix logging first, then add CI, the first CI run is green and stays green.
- CI before small wins because: small wins are the first changes landing after CI exists, proving the safety net works.

**Research flags for phases:**
- Phase 1 (Logging): Standard patterns, unlikely to need additional research
- Phase 2 (CI/CD): Fully researched here — this document is the research
- Phase 3 (Small Wins): Standard patterns, unlikely to need additional research

## Confidence Assessment

| Area | Confidence | Notes |
|---|---|---|
| Stack | HIGH | All versions and patterns verified via Context7 against official GitHub Actions docs and Pester docs |
| Features | HIGH | CI/CD features are well-defined by the milestone requirements in PROJECT.md |
| Architecture | HIGH | Single-workflow-with-matrix is the documented GitHub pattern for this exact use case |
| Pitfalls | HIGH | Pester v6 breakage risk, module pre-install churn, and Test-All.ps1 reuse issues are verified concerns |

## Gaps to Address

- **PSFramework in CI**: Not researched deeply. VeriHash degrades gracefully without PSFramework, so CI doesn't need it. But if a future milestone adds PSFramework-dependent tests, installation strategy will need research.
- **Code coverage**: Pester supports code coverage natively. Not needed for this milestone but could be added later. The configuration object already supports `$config.CodeCoverage.Enabled = $true`.
- **Release automation**: `Build.ps1` exists but GitHub Actions release workflows (tagging, changelog generation, artifact packaging) were out of scope for this research.
- **macOS runner matrix**: Excluded for now (VeriHash doesn't support macOS context menus). Adding `macos-latest` to the matrix is trivial if needed later.

---

*Research summary: 2026-04-17*
