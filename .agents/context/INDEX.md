# Context Index

This index helps agents locate domain-specific guidance without bloating the root `AGENTS.md`.

**This file is living documentation.** Agents are responsible for maintaining it alongside project work.

## How This Works

1. **Root `AGENTS.md`** - Project-wide principles, workflow, and environment setup
2. **This `INDEX.md`** - Maps topics to context files; agents check here first
3. **Context files** - Deep dives on specific topics (logging, testing, SDKs, etc.)

## Loading Context

Agents should load context files when:

- The task keywords match a topic below
- User explicitly requests it (e.g., "load logging context" or `#logging`)
- A context file is referenced in plan or implementation docs

## Context Files

| Tag | File | Load When |
| --- | ---- | --------- |
| `#logging` | `logging.md` | Implementing logging, using PSFramework, debugging, observability |
| `#testing` | `testing.md` | Writing Pester tests, test strategy, TDD approach |
| `#config` | `config.md` | Configuration loading, settings merging, JSON config schema, env vars |
| `#virustotal` | `virustotal.md` *(create in Phase 3)* | VirusTotal API integration, rate limiting, API key management |
| `#mkdocs` | `mkdocs.md` | Creating or updating project documentation, working with MkDocs |

> **Note:** Some files above are templates ready to use; others are placeholders to create when the project needs them. Agents may suggest loading relevant context as part of planning.

## VeriHash-Specific Context

### Logging (`logging.md`)

VeriHash-specific logging architecture including:

- `VeriHash.Logging.ps1` module usage
- `Write-VeriHashLog` function patterns
- Log levels and what to log at each level
- Config file format for logging settings
- Troubleshooting with logs

### Configuration (`config.md`)

VeriHash-specific configuration system including:

- `VeriHash.Config.ps1` module usage
- Config file schema (logging, virustotal sections)
- Environment variable overrides
- Priority: env vars > config file > defaults
- Source tracking for debugging

### Testing (`testing.md`)

General testing guidance. VeriHash uses:

- **Pester 5.x** for PowerShell testing
- TDD approach: Write tests first, code passes tests
- Tests in `Tests/` directory
- Run via `.\Test-All.ps1`

### Documentation (`mkdocs.md`)

VeriHash-specific documentation system including:

- MkDocs with Material theme configuration
- Local development workflow (`mkdocs serve`)
- Auto-generated parameter docs from comment-based help
- Anti-drift strategy (tested examples, PR checklist)
- GitHub Pages deployment via Actions

## Related Files

- `../plan.md` - MVP scope and decisions
- `../implementation.md` - Phase breakdown and tracking
- `../phase-N-implementation.md` - Current phase task details
- `../../AGENTS.md` - Root agent instructions (workflow, environment, principles)

## Adding New Context

1. Create `topic-name.md` in this folder
2. Add a row to the table above with a short tag and clear "load when" trigger
3. Keep context files focused—one topic per file

## Maintenance Responsibilities

Agents should treat this index and its context files as part of the project codebase:

- **Add entries** when new patterns, tools, or conventions emerge during work
- **Update entries** when context files are modified or renamed
- **Remove entries** when topics become obsolete or are consolidated elsewhere
- **Flag stale content** if a context file no longer reflects current project state

This is not optional housekeeping—it ensures future sessions (and other agents) don't work with outdated guidance.
