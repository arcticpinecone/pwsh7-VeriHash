# VeriHash Implementation Phases

Goal-focused implementation phases. Each phase delivers a working, testable milestone.

**Source:** `.agents/plan.md`
**Workflow:** Use `.agents/complete-phase.md` when finishing each phase

**Project:** VeriHash - Cross-platform file hash verification tool

**Tech Stack:** PowerShell 7+, Pester 5.x, PSScriptAnalyzer

---

## Development Principles

**TDD (Test-Driven Development):**

1. Write tests first that define expected behavior
2. Run tests - they should fail (red)
3. Write minimum code to pass tests (green)
4. Refactor while keeping tests green
5. Tests are NEVER modified to pass - code is modified

**Log Everything:**

- Phase 1 establishes the logging foundation
- All subsequent phases MUST use logging throughout
- Every new function logs entry/exit
- Every external call logs with timing
- Every error logs with full context

---

## Implementation Phases

### Phase 1: Logging Service Foundation

**Goal:** Establish a robust logging infrastructure that all future features will use.

**Deliverable:** A working logging module with tests that can be imported and used throughout VeriHash.

**Tasks:**

- [x] Create `VeriHash.LogUtils.ps1` module with core logging functions
- [x] Implement logging initialization in VeriHash.ps1 (lines 130-192)
- [x] Implement logging via PSFramework's `Write-PSFMessage` with level support
- [x] Implement log output targets (console, file, both)
- [x] Add UTC timestamp formatting (ISO 8601 via PSFramework)
- [x] Create platform-specific log paths (`~/.verihash/logs/` or `%APPDATA%\VeriHash\logs\`)
- [x] Support `$env:VERIHASH_LOG_LEVEL` environment variable override
- [x] Write Pester tests for all logging functions (`VeriHash.LogUtils.Tests.ps1`)
- [x] Add log rotation via PSFramework (daily files)
- [x] Document logging usage in `.agents/context/logging.md`

**Success Test:**

- [x] All logging tests pass
- [x] Can log at different levels with correct filtering
- [x] Logs written to file with proper formatting
- [x] Log level can be set via parameter or environment variable

**Why Logging First:**

- Enables troubleshooting for all subsequent phases
- Makes agent and human debugging focused
- Creates audit trail for security-sensitive operations (VirusTotal)
- Reduces "what happened?" guesswork

**Implementation Notes:**

- Used PSFramework instead of custom logging (battle-tested, feature-rich)
- Logging integrated directly into VeriHash.ps1 rather than separate module
- `VeriHash.LogUtils.ps1` provides log analysis utilities (not core logging)
- GDPR-compliant path sanitization built in

---

### Phase 2: Configuration System

**Goal:** Unified configuration management for VeriHash settings including logging, VirusTotal, and user preferences.

**Deliverable:** A configuration module that manages settings from environment variables, config files, and defaults.

**Tasks:**

- [x] Create `VeriHash.Config.ps1` module
- [x] Implement `Get-VeriHashConfig` to load merged configuration
- [x] Implement `Set-VeriHashConfig` to update config file
- [x] Define config schema with logging section and VirusTotal section
- [x] Support priority: env vars > config file > defaults
- [x] Create default config file on first run (`Initialize-VeriHashConfig`)
- [x] **Use logging:** Log config loading, source of each setting, validation errors
- [x] Write Pester tests for config loading, merging, validation (25 tests)
- [x] Handle missing config gracefully (use defaults)
- [x] Cross-platform path handling (`~/.verihash/` on Linux/macOS, `$env:APPDATA\VeriHash\` on Windows)

**Config Schema:**

```json
{
  "logging": {
    "level": "INFO",
    "file": true,
    "console": true
  },
  "virustotal": {
    "apiKey": "",
    "enabled": true,
    "preferApi": true,
    "autoOpen": false
  }
}
```

**Note:** Log path is not stored in config - it's determined at runtime based on platform:
- Windows: `$env:APPDATA\VeriHash\logs\`
- Linux/macOS: `~/.verihash/logs/`

**Success Test:**

- [x] Config loads from file with correct merging
- [x] Env vars override config file values
- [x] Logs show which config source was used (via `-IncludeSource` parameter)
- [x] Tests pass for all config scenarios (24 passed, 1 skipped platform-specific)

---

### Phase 3: VirusTotal Integration

**Goal:** Enable users to check file hashes against VirusTotal for malware detection.

**Deliverable:** Working VirusTotal integration with API and browser fallback modes.

**Tasks:**

- [ ] Create `VeriHash.VirusTotal.ps1` module
- [ ] Implement `Test-VirusTotalHash` for API-based lookup
- [ ] Implement `Open-VirusTotalSearch` for browser fallback
- [ ] Implement `Get-VirusTotalRateLimit` to check remaining quota
- [ ] Implement rate limit tracking in `~/.verihash/api-usage.json`
- [ ] Add `-SkipVirusTotal` parameter to main VeriHash function
- [ ] Add `-VirusTotalApiKey` parameter for one-time API usage
- [ ] **Use logging:** Log API calls, rate limits, responses, errors, browser opens
- [ ] Prompt user after hash computation: `Check this file on VirusTotal? [Y/n]`
- [ ] Display results inline (detection ratio, last analysis date, report link)
- [ ] Handle network errors gracefully (timeout after 10 seconds)
- [ ] Write Pester tests with mocked API responses
- [ ] Test rate limit logic with time manipulation

**Success Test:**

- VirusTotal lookup works with valid API key
- Rate limits are tracked and respected
- Graceful fallback to browser when API unavailable
- Logs show full request/response lifecycle
- Tests pass including edge cases (no key, rate limited, network error)

---

### Phase 4: Additional Desktop Integration

**Goal:** Extend Linux context menu support to GNOME and XFCE desktop environments.

**Deliverable:** Context menu integration for GNOME (Nautilus) and XFCE (Thunar).

**Tasks:**

- [ ] Detect GNOME via `$XDG_CURRENT_DESKTOP`
- [ ] Implement `Install-GNOMEContextMenu` for Nautilus scripts
- [ ] Detect XFCE via `$XDG_CURRENT_DESKTOP`
- [ ] Implement `Install-XFCEContextMenu` for Thunar custom actions
- [ ] Update `Install-LinuxContextMenu` to auto-detect and offer choices
- [ ] **Use logging:** Log desktop detection, installation paths, success/failure
- [ ] Write Pester tests for detection logic
- [ ] Test installation on actual GNOME/XFCE systems (manual verification)
- [ ] Update README with new desktop environment support

**Success Test:**

- Desktop environment correctly detected
- Context menu installs successfully on GNOME
- Context menu installs successfully on XFCE
- Logs show installation process
- Tests pass for detection and installation logic

---

### Phase 5: Performance & UX Enhancements (Backlog)

**Goal:** Polish the user experience with performance improvements and visual enhancements.

**Deliverable:** Enhanced hash computation with optional parallel processing and visual feedback.

**Tasks:**

- [ ] Implement parallel hash computation for multiple algorithms
- [ ] Add progress bar for large file hashing (>100MB)
- [ ] Color-coded throughput display (red=slow, yellow=medium, green=fast)
- [ ] **Use logging:** Log performance metrics, timing data, algorithm choices
- [ ] Write Pester tests for parallel computation correctness
- [ ] Benchmark and document performance improvements

**Success Test:**

- Parallel hashing produces correct results
- Progress bar shows accurate progress
- Performance improves measurably for multi-algorithm scenarios
- Logs capture timing data for analysis

---

### Phase 6: MkDocs Documentation Site

**Goal:** Professional documentation site that addresses user confusion, discoverability, and corporate credibility.

**Deliverable:** MkDocs documentation site deployed to GitHub Pages with anti-drift protection.

**Tasks:**

- [ ] Install MkDocs and Material theme (`pip install mkdocs mkdocs-material`)
- [ ] Create `mkdocs.yml` configuration with Material theme
- [ ] Create `docs/index.md` landing page (elevator pitch)
- [ ] Create `.github/workflows/docs.yml` for GitHub Pages deployment
- [ ] Split README.md content into structured pages:
  - [ ] `docs/getting-started/installation.md`
  - [ ] `docs/getting-started/quickstart.md`
  - [ ] `docs/getting-started/platform-setup.md`
  - [ ] `docs/usage/basic-usage.md`
  - [ ] `docs/usage/parameters.md`
  - [ ] `docs/usage/output-formats.md`
  - [ ] `docs/usage/logging.md`
  - [ ] `docs/tools/verihash.md`
  - [ ] `docs/tools/quickhash.md`
  - [ ] `docs/tools/logutils.md`
  - [ ] `docs/guides/powershell-profile.md`
  - [ ] `docs/guides/cicd.md`
  - [ ] `docs/reference/commands.md`
  - [ ] `docs/reference/config.md`
  - [ ] `docs/reference/faq.md`
  - [ ] `docs/contributing/development.md`
- [ ] Create `scripts/Generate-Docs.ps1` to extract parameter docs from comment-based help
- [ ] Create `Tests/VeriHash.Docs.Tests.ps1` to validate doc examples work
- [ ] **Use logging:** Log doc generation process, validation results
- [ ] Trim README.md to brief overview + link to docs site
- [ ] Update AGENTS.md with "user-facing changes require doc updates" guideline
- [ ] Create `.github/PULL_REQUEST_TEMPLATE.md` with docs checkbox

**Site Structure:**

```
docs/
├── index.md                    # What is VeriHash? (elevator pitch)
├── getting-started/
│   ├── installation.md         # GitHub CLI, Git clone, future: Install-Module
│   ├── quickstart.md           # Your first hash verification
│   └── platform-setup.md       # Windows SendTo, Linux context menu, macOS
├── usage/
│   ├── basic-usage.md          # Common scenarios
│   ├── parameters.md           # Full parameter reference (auto-generated)
│   ├── output-formats.md       # Console, JSON, file output
│   └── logging.md              # Privacy-first logging guide
├── tools/
│   ├── verihash.md             # Main tool deep-dive
│   ├── quickhash.md            # QuickHash companion tool
│   └── logutils.md             # Log analysis utilities
├── guides/
│   ├── powershell-profile.md   # Profile integration
│   └── cicd.md                 # CI/CD integration
├── reference/
│   ├── commands.md             # Quick reference / cheat sheet
│   ├── config.md               # Configuration system
│   └── faq.md                  # Common questions
└── contributing/
    └── development.md          # For contributors
```

**Success Test:**

- `mkdocs serve` shows navigable site at localhost:8000
- GitHub Actions deploys to GitHub Pages on push to main
- Search finds key terms (e.g., "algorithm", "clipboard", "logging")
- `Invoke-Pester Tests/VeriHash.Docs.Tests.ps1` passes
- `scripts/Generate-Docs.ps1` extracts parameters correctly
- README.md links to docs site

---

## Testing Strategy

**Phase 1:** Unit tests for logging functions - isolation, formatting, filtering
**Phase 2:** Unit tests for config loading - merging, validation, defaults
**Phase 3:** Integration tests with mocked VirusTotal API - full workflow
**Phase 4:** Unit tests for detection, manual integration tests on actual systems
**Phase 5:** Unit tests for correctness, performance benchmarks
**Phase 6:** Doc example validation tests, auto-generation script tests

**All Phases:**

- TDD approach: Write tests first
- Tests define expected behavior
- Code is modified to pass tests (never the reverse)
- Use logging to verify operations in test output

---

## Phase Tracking

- [x] **Phase 1: Logging Service** - ✅ Complete
- [x] **Phase 2: Configuration System** - ✅ Complete (pending commit)
- [ ] **Phase 3: VirusTotal Integration** - ⏳ Not Started
- [ ] **Phase 4: Desktop Integration** - ⏳ Not Started
- [ ] **Phase 5: Performance & UX** - ⏳ Not Started
- [ ] **Phase 6: Documentation Site** - ⏳ Not Started

**Current Phase:** Phase 3

**Development Branch:** `dev`

---

## Logging Requirements Per Phase

Every phase MUST include:

1. **Entry logging:** Log when significant functions are called with key parameters
2. **Exit logging:** Log completion with results or status
3. **External call logging:** Log API calls, file system operations with timing
4. **Decision logging:** Log why a code path was taken (e.g., "Using API mode because API key is valid and rate limit not exceeded")
5. **Error logging:** Log errors with full context (input, state, exception message)

This ensures agents and humans can trace operations and troubleshoot effectively.

---

**Remember:** Each phase builds on the previous. Logging (Phase 1) is required before any other phase can begin. Do not skip ahead.
