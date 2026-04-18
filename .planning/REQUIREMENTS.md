# Requirements: VeriHash — Privacy + Foundation

**Defined:** 2026-04-17
**Core Value:** Close audit gaps so the privacy-first logging guide is the honest contract, and put a CI/CD safety net in place before new feature work.

## v1 Requirements

Requirements for this milestone. Each maps to roadmap phases.

### Privacy / GDPR Compliance

- [x] **PRIV-01**: Hash values truncated to 16 chars + `...` in all `Write-PSFMessage` data payloads (closes `Get-And-SaveHash:839`)
- [x] **PRIV-02**: All config-path log payloads in `VeriHash.Config.ps1` pass through `ConvertTo-SanitizedPath` (closes 11 unsanitized-path violations)
- [x] **PRIV-03**: `ConvertTo-SanitizedPath` relocated to `VeriHash.LogUtils.ps1` so it is available to all dot-sourced modules (dot-source order: LogUtils → Config → VeriHash)
- [x] **PRIV-04**: After fixes, `Verihash Logging Concepting.md` describes actual code behavior with zero caveats

### CI/CD Pipeline

- [ ] **CICD-01**: GitHub Actions workflow runs Pester tests on every push and PR (`ubuntu-latest` + `windows-latest` matrix)
- [ ] **CICD-02**: GitHub Actions workflow runs PSScriptAnalyzer on every push and PR (fail on any finding)
- [ ] **CICD-03**: PSScriptAnalyzer lints all three `.ps1` files (`VeriHash.ps1`, `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`)
- [ ] **CICD-04**: Pester pinned to 5.x (`MaximumVersion 5.99`) in CI to prevent Pester 6 auto-install breakage

### Logging & Configuration

- [ ] **LOGC-01**: PSFramework log rotation enabled via `LogRotatePath` + `LogRetentionTime` parameters (30-day retention)
- [x] **LOGC-02**: Single PSFramework bootstrap detection — eliminate redundant `Get-Module -ListAvailable -Name PSFramework` call between `VeriHash.Config.ps1` and `VeriHash.ps1`
- [ ] **LOGC-03**: `virustotal.enabled` defaults to `$false` in `Get-VeriHashDefaultConfig` until VirusTotal integration ships

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Testing

- **TEST-01**: Unit tests for `ConvertTo-SanitizedPath` and `ConvertFrom-SanitizedPath` (currently zero coverage)
- **TEST-02**: Code coverage thresholds enforced in CI (Pester supports natively)

### Infrastructure

- **INFRA-01**: Release automation via GitHub Actions (tagging, changelog generation, artifact packaging)
- **INFRA-02**: Linux matrix expansion to include `macos-latest` for cross-platform coverage

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Monolith split of `VeriHash.ps1` | Highest blast-radius change; deserves its own milestone with dedicated planning and test migration |
| VirusTotal integration (Phase 3) | Next feature milestone; don't start until foundation is honest |
| Multifile / batch hashing | Tracked in concepting doc; feature work, not foundation |
| `QuickHash.ps1` deprecation/rewrite | Diverged tool; decide fate in dedicated cleanup milestone |
| macOS context-menu integration | Not implemented today and not driven by user demand |
| Release automation | Build.ps1 exists; GitHub Actions release workflows are a future concern |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| PRIV-01 | Phase 1 | Complete |
| PRIV-02 | Phase 1 | Complete |
| PRIV-03 | Phase 1 | Pending |
| PRIV-04 | Phase 1 | Complete |
| LOGC-02 | Phase 1 | Pending |
| CICD-01 | Phase 2 | Pending |
| CICD-02 | Phase 2 | Pending |
| CICD-03 | Phase 2 | Pending |
| CICD-04 | Phase 2 | Pending |
| LOGC-01 | Phase 3 | Pending |
| LOGC-03 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 11 total
- Mapped to phases: 11 ✓
- Unmapped: 0

---
*Requirements defined: 2026-04-17*
*Last updated: 2026-04-17 after roadmap creation*
