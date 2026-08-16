# Codebase Structure

**Analysis Date:** 2026-04-18

## Directory Layout

```
VeriHash\
├── VeriHash.ps1                       # Main script — CLI, hashing, verification, OS integration (~66 KB, ~1528 lines)
├── VeriHash.Config.ps1                # Configuration module (dot-sourced)
├── VeriHash.LogUtils.ps1              # Log path + path-sanitisation module (dot-sourced)
├── QuickHash.ps1                      # Standalone interactive mini-tool (independent of main)
├── Test-All.ps1                       # Runs Pester + PSScriptAnalyzer + profiler
├── Build.ps1                          # Release automation (runs tests, bumps version)
├── Profile-VeriHashTiming.ps1         # Timing / performance harness
├── Microsoft.PowerShell_profile_example.ps1  # Example profile snippet for users
├── VeriHash-OpenWith.bat              # Windows "Open With" launcher
├── PSScriptAnalyzerSettings.psd1      # Linter rule customisation
├── README.md
├── CHANGELOG.md
├── LICENSE.md                         # MIT
├── Verihash Logging Concepting.md     # Design notes
├── Verihash Multifile Concepting.md   # Design notes
├── Verihash Multifile Concepting Review.md
├── VeriHash.code-workspace            # VS Code workspace
├── VeriHash.sublime-project
├── VeriHash.sublime-workspace
├── .gitignore
├── Tests\                             # Pester 5.x test suite
│   ├── VeriHash.Tests.ps1             # Core hashing / verification tests (~47 KB)
│   ├── VeriHash.Config.Tests.ps1      # Config priority & persistence tests
│   ├── VeriHash.LogUtils.Tests.ps1    # Path sanitisation tests
│   ├── VeriHash.Timing.Tests.ps1      # Timing / performance tests
│   ├── QuickHash.Tests.ps1            # Tests for QuickHash.ps1
│   └── VeriHash_1024.ico              # Test fixture icon
├── Icons\                             # Application icons (source + generated)
│   ├── VeriHash_256.ico / _256.webp
│   ├── VeriHash_512.icns              # macOS icon bundle
│   ├── VeriHash_1024.png / _1024.webp
│   └── SourceIcons.7z                 # Archived source art
├── .github\
│   ├── copilot-instructions.md        # Project-wide AI agent instructions
│   └── workflows\
│       └── ci.yml                     # GitHub Actions CI pipeline
├── .planning\                         # GSD planning tree (milestones, phases, research, codebase map)
│   ├── PROJECT.md
│   ├── STATE.md
│   ├── ROADMAP.md
│   ├── REQUIREMENTS.md
│   ├── MILESTONES.md
│   ├── RETROSPECTIVE.md
│   ├── config.json
│   ├── codebase\                      # ← Documents produced by /gsd-map-codebase (this file lives here)
│   ├── milestones\
│   │   ├── v1.0-REQUIREMENTS.md
│   │   ├── v1.0-ROADMAP.md
│   │   ├── v1.0-MILESTONE-AUDIT.md
│   │   └── v1.0-phases\
│   │       ├── 01-privacy-logging-compliance\
│   │       ├── 02-ci-cd-pipeline\
│   │       └── 03-small-wins-baseline-lock\
│   ├── phases\
│   │   └── 999.1-psframework-missing-notification\
│   ├── quick\
│   │   └── 260418-rename-log-jsonl\
│   └── research\
│       ├── SUMMARY.md
│       ├── STACK.md
│       ├── ARCHITECTURE.md
│       ├── FEATURES.md
│       └── PITFALLS.md
├── .claude\
│   └── settings.local.json            # Local agent settings (gitignored content pattern)
├── .vscode\
│   ├── .gitignore
│   └── github-accounts.json
└── tmp\                               # Scratch / transient (excluded from analysis)
```

> Note: there is **no** `.agents\` directory in this repository. Agent instructions live under `.github\copilot-instructions.md` and `.claude\`.

## Directory Purposes

**Repository root:**
- Purpose: Runnable PowerShell scripts live directly at the root — there is no `src\` layer. This is idiomatic for dot-sourced PowerShell tools.
- Contains: All production `.ps1` scripts, all `.md` documentation, editor workspace files, the Windows launcher `.bat`, and the linter settings file.
- Key files: `VeriHash.ps1`, `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`, `QuickHash.ps1`, `Test-All.ps1`, `Build.ps1`.

**`Tests\`:**
- Purpose: Pester 5.x test suite, one `*.Tests.ps1` per production script.
- Contains: Four VeriHash test files plus `QuickHash.Tests.ps1` and a shared binary fixture `VeriHash_1024.ico`.
- Convention: Tests live in a single flat directory rather than co-located with the scripts under test.

**`Icons\`:**
- Purpose: Application branding assets shipped with the tool. `VeriHash_256.ico` is referenced by `Install-WindowsSendTo` when creating the SendTo shortcut.
- Contains: Multi-resolution Windows (`.ico`), macOS (`.icns`), and web (`.png`, `.webp`) icons plus archived sources (`SourceIcons.7z`).
- Generated: No — committed art assets.

**`.github\`:**
- Purpose: GitHub metadata — CI workflow and AI-agent instructions.
- Contains: `workflows\ci.yml` (runs `Test-All.ps1 -CI`) and `copilot-instructions.md` (authoritative agent brief for build/test/lint commands).

**`.planning\`:**
- Purpose: GSD (Get-Shit-Done) planning tree. Not part of the runtime tool; consumed by planning / execution commands.
- Contains: Top-level project docs (`PROJECT.md`, `STATE.md`, `ROADMAP.md`, `REQUIREMENTS.md`, `MILESTONES.md`, `RETROSPECTIVE.md`), the `milestones\v1.0-phases\` tree with per-phase `-CONTEXT.md`, `-PLAN.md`, `-RESEARCH.md`, `-PATTERNS.md`, `-VALIDATION.md`, `-VERIFICATION.md`, `-SUMMARY.md`, and `-DISCUSSION-LOG.md` files, a `quick\` tree for lightweight tasks, a `research\` snapshot of the codebase, and the `codebase\` directory where this document lives.

**`.claude\`, `.vscode\`:**
- Purpose: Per-tool local settings. Not part of the shipped tool.
- Committed: Partially — `.claude\settings.local.json` and `.vscode\github-accounts.json` are present; `.vscode\.gitignore` filters local secrets.

**`tmp\`:**
- Purpose: Scratch directory for ad-hoc output.
- Generated: Yes.
- Committed: Likely gitignored content (directory itself kept).

## Key File Locations

**Entry Points:**
- `VeriHash.ps1`: Primary tool. Parameter block at lines 56–93; final dispatch `Invoke-HashFile ...` at line 1528.
- `QuickHash.ps1`: Standalone mini-tool — its bottom-level prompts at lines 83–95 are the entry.
- `VeriHash-OpenWith.bat`: Windows shell-verb launcher that invokes `pwsh -File VeriHash.ps1 "%1"`.
- `Microsoft.PowerShell_profile_example.ps1`: Template users copy into their PowerShell profile to expose the `verihash` alias.

**Configuration:**
- `VeriHash.Config.ps1`: Defines `Get-VeriHashConfig`, `Set-VeriHashConfig`, `Initialize-VeriHashConfig`, `Get-VeriHashConfigPath`, `Get-VeriHashDefaultConfig`.
- Runtime config file (not in repo): `%APPDATA%\VeriHash\config.json` (Windows) or `~/.verihash/config.json` (Linux/macOS).
- Environment variables honoured: `VERIHASH_LOG_LEVEL`, `VERIHASH_LOG_FILE`, `VERIHASH_LOG_CONSOLE`, `VERIHASH_VT_APIKEY`, `VERIHASH_VT_ENABLED`, `VERIHASH_TEST_MODE`.
- `PSScriptAnalyzerSettings.psd1`: Linter rule customisation (suppresses `PSAvoidUsingWriteHost` and `PSAvoidUsingBrokenHashAlgorithms`).

**Core Logic:**
- `VeriHash.ps1` line ~212: `$script:DesktopEnvironments` registry.
- `VeriHash.ps1` line ~228: `Get-DesktopEnvironment`.
- `VeriHash.ps1` line ~284: `Install-WindowsSendTo`.
- `VeriHash.ps1` line ~339: `Install-LinuxContextMenu`.
- `VeriHash.ps1` line ~387: `Install-KDEContextMenu`.
- `VeriHash.ps1` line ~619: `Select-File` (interactive file picker).
- `VeriHash.ps1` line ~650: `Test-InputHash`.
- `VeriHash.ps1` line ~665: `Get-ClipboardHash` (cross-platform clipboard read + auto-algorithm detection).
- `VeriHash.ps1` line ~780: `Get-And-SaveHash` (single-algorithm compute + sidecar write).
- `VeriHash.ps1` line ~1024: `Invoke-HashFile` (main orchestrator).
- `VeriHash.ps1` line ~1392: `Test-HashSidecar` (multi-entry sidecar verifier).

**Logging:**
- `VeriHash.LogUtils.ps1`: `Get-VeriHashLogPath`, `ConvertTo-SanitizedPath`, `ConvertFrom-SanitizedPath`.
- `VeriHash.ps1` lines 108–187: PSFramework provider configuration (JSONL, UTC, 30-day retention, sanitised headers).

**Testing:**
- `Tests\VeriHash.Tests.ps1`: Core tests for the main script (largest test file, ~47 KB).
- `Tests\VeriHash.Config.Tests.ps1`: Config priority + round-trip tests.
- `Tests\VeriHash.LogUtils.Tests.ps1`: Path sanitisation tests.
- `Tests\VeriHash.Timing.Tests.ps1`: Performance / timing tests.
- `Tests\QuickHash.Tests.ps1`: QuickHash tests.
- `Test-All.ps1`: Developer-facing runner.
- `.github\workflows\ci.yml`: CI invocation.

## Naming Conventions

**Files:**
- Production scripts: `PascalCase` with dot-separated sub-scope — `VeriHash.ps1`, `VeriHash.Config.ps1`, `VeriHash.LogUtils.ps1`.
- Independent sibling tools at root use a single `PascalCase` word — `QuickHash.ps1`, `Build.ps1`.
- Developer scripts use `PascalCase-PascalCase.ps1` — `Test-All.ps1`, `Profile-VeriHashTiming.ps1`.
- Pester tests mirror the tested script with a `.Tests.ps1` suffix — `VeriHash.Config.ps1` → `Tests\VeriHash.Config.Tests.ps1`.
- Settings files follow their tool's idiom — `PSScriptAnalyzerSettings.psd1` (PowerShell data file).
- Planning documents are `SHOUTING-KEBAB-CASE.md` under `.planning\` — `REQUIREMENTS.md`, `MILESTONES.md`, plus phase-scoped `01-PATTERNS.md`, `02-RESEARCH.md`, etc.

**Directories:**
- Runtime directories: `PascalCase` (`Tests\`, `Icons\`).
- Metadata / tooling directories: `.lowercase` (`.github\`, `.planning\`, `.claude\`, `.vscode\`).
- Phase directories use a two-digit prefix + kebab-case slug: `01-privacy-logging-compliance\`, `02-ci-cd-pipeline\`.

**Functions (PowerShell verb-noun):**
- All public functions use approved PowerShell verbs followed by a `VeriHash`-prefixed noun or a descriptive noun: `Get-VeriHashConfig`, `Set-VeriHashConfig`, `Initialize-VeriHashConfig`, `Get-VeriHashLogPath`, `ConvertTo-SanitizedPath`, `Test-HashSidecar`, `Install-KDEContextMenu`, `Get-DesktopEnvironment`, `Invoke-HashFile`, `Select-File`, `Test-InputHash`, `Get-ClipboardHash`.
- One legacy hyphenated exception: `Get-And-SaveHash` (non-standard compound verb). New code should prefer a single approved verb (e.g. `Save-VeriHashFileHash`).

**Variables:**
- Script-scoped constants: `$script:CamelCase` — `$script:RunningOnWindows`, `$script:DesktopEnvironments`, `$script:SignableExtensions`, `$script:VeriHashConfig`, `$script:VeriHashLogPath`, `$script:PSFrameworkAvailable`, `$script:ValidLogLevels`.
- Local variables and parameters: `$camelCase` or `$PascalCase` — the codebase mixes both (`$configDir`, `$fileInfo`, `$FilePath`, `$InputHash`).
- Environment variables are uppercase with `VERIHASH_` prefix: `VERIHASH_LOG_LEVEL`, `VERIHASH_TEST_MODE`.

**Log tags:**
- PSFramework `-Tag` values are `PascalCase` category + `PascalCase` sub-category: `'Config', 'Entry'`, `'Hash', 'Compute'`, `'Verify', 'Summary'`, `'Install', 'Windows'`.

## Where to Add New Code

**New hashing feature / CLI flag:**
- Extend the `param(...)` block near the top of `VeriHash.ps1`.
- Implement logic inside `Invoke-HashFile` (line ~1024) or add a helper function above it.
- Add tests in `Tests\VeriHash.Tests.ps1`.

**New configuration key:**
- Add the default to `Get-VeriHashDefaultConfig` in `VeriHash.Config.ps1`.
- Extend file-merge, env-var-merge, and `$source` tracking blocks in `Get-VeriHashConfig`.
- Add validation (e.g. against a new `$script:Valid...` list) if the value is enumerated.
- Add tests in `Tests\VeriHash.Config.Tests.ps1` covering default / file / env priority.

**New desktop environment (Linux context menu):**
- Append an entry to `$script:DesktopEnvironments` in `VeriHash.ps1` (~line 213).
- Define a new `Install-<DE>ContextMenu` function matching the `Handler` field.
- No changes needed in `Install-LinuxContextMenu` — dispatch is data-driven via `Get-Command $config.Handler`.

**New log utility or path-privacy helper:**
- Add to `VeriHash.LogUtils.ps1`; tests go in `Tests\VeriHash.LogUtils.Tests.ps1`.
- This module is dot-sourced **first**, so do not reference `Get-VeriHashConfig` from it (that would create a cycle).

**New Pester tests:**
- Place at `Tests\<ScriptName>.Tests.ps1` (or extend an existing file if testing the same unit).
- Use `BeforeAll { . $PSScriptRoot/../<ScriptName>.ps1 }` to dot-source the target.
- Set `$env:VERIHASH_TEST_MODE = '1'` in `BeforeAll` when the test exercises logging paths — this routes logs to a `test\` subdirectory.

**Utilities / shared helpers:**
- There is no dedicated `Utils\` or `Common\` directory. Cross-cutting helpers live in `VeriHash.LogUtils.ps1` (path/log helpers) or inline in `VeriHash.ps1`.
- When the v2.0 "Modular Rebuild" lands, utility code is expected to migrate into purpose-named `VeriHash.*.ps1` siblings. Until then, prefer adding a new `VeriHash.<Area>.ps1` sibling and dot-sourcing it from `VeriHash.ps1` rather than growing `VeriHash.ps1` further.

**Release / build changes:**
- Version string lives in the header comment of `VeriHash.ps1` (look for `Version:`). `Build.ps1 -Version <v> -UpdateVersion` rewrites it via regex.
- Update `CHANGELOG.md` in the same commit as the version bump.

**New planning phase:**
- Create `.planning\milestones\v<X>-phases\<NN>-<kebab-slug>\` with the standard file set (`-CONTEXT`, `-PLAN`, `-RESEARCH`, `-PATTERNS`, `-VALIDATION`, `-VERIFICATION`, `-SUMMARY`, `-DISCUSSION-LOG`).

## Special Directories

**`.planning\`:**
- Purpose: Full GSD planning history — milestones, per-phase documents, research, retrospectives, and the codebase map consumed by planning agents.
- Generated: Partly (the `codebase\` subtree is regenerated by `/gsd-map-codebase`); the rest is authored.
- Committed: Yes.

**`Icons\`:**
- Purpose: Committed branding assets referenced at runtime (`Install-WindowsSendTo` uses `Icons\VeriHash_256.ico`).
- Generated: No — hand-authored, with `SourceIcons.7z` archiving originals.
- Committed: Yes.

**`tmp\`:**
- Purpose: Scratch output.
- Generated: Yes.
- Committed: Directory kept; contents treated as transient.

**`.claude\` / `.vscode\`:**
- Purpose: Per-editor / per-agent local configuration.
- Generated: Manually by developers.
- Committed: Partially — `.vscode\.gitignore` filters sensitive local files.

---

*Structure analysis: 2026-04-18*
