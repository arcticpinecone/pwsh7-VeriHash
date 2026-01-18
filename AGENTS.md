# AGENTS.md

This file provides context and instructions for AI coding agents working on projects. It follows the [agents.md](https://agents.md) standard for machine-readable project guidance.

## Purpose

These templates guide AI agents through a structured planning and implementation workflow. Rather than diving directly into code, agents should:

1. **Plan first** - Define what the MVP looks like before writing code
2. **Break into phases** - Each phase delivers a working, testable milestone
3. **Complete incrementally** - Finish one phase before starting the next

This approach prevents scope creep, ensures testable progress, and keeps the human in control of feature direction.

## Workflow Overview

```markdown
plan.md → implementation.md → phase-N-implementation.md → complete-phase.md
   ↑                                                              │
   └──────────────── (when all phases done, loop back) ───────────┘
```

### Step 1: Planning (`.agents/plan.md`)

Start here. Define:

- What problem the project solves
- Who uses it
- Core MVP features (must-have vs nice-to-have)
- Tech choices
- Rough timeline

**When to use:** New project, major feature addition, or revisiting direction.

### Step 2: Implementation Phases (`.agents/implementation.md`)

Break the plan into 3-5 phases. Each phase should:

- Deliver something that **works and can be tested**
- Build on the previous phase
- Have clear success criteria

**When to use:** After planning is approved, before coding begins.

### Step 3: Phase Work (`.agents/phase-N-implementation.md`)

Detailed task tracking for the current phase. Contains:

- Specific tasks with checkboxes
- Testing requirements
- Completion criteria
- Daily progress log

**When to use:** Created automatically when starting a new phase.

### Step 4: Phase Completion (`.agents/complete-phase.md`)

Handles the transition between phases:

- Marks current phase complete in `implementation.md`
- If more phases remain → creates next phase file
- If all phases done → engages user for next direction

**When to use:** When a phase's success criteria are met.

## Commands

| Command | When to Use | What It Does |
| ------- | ----------- | ------------ |
| `/plan` | Starting a project or major feature | Opens planning template, guides MVP definition |
| `/implement` | After plan is approved | Creates phased implementation breakdown |
| `/complete-phase` | Finished current phase | Marks progress, sets up next phase or asks for new direction |

## File Locations

All planning artifacts live in `.agents/` within the project:

```markdown
project/
├── .agents/
│   ├── plan.md                    # MVP scope and decisions
│   ├── implementation.md          # Phase breakdown and tracking
│   ├── phase-1-implementation.md  # Current phase details
│   ├── phase-2-implementation.md  # (created as needed)
│   └── ...
└── (project files)
```

## Key Principles

- **Human stays in control** - Agent proposes, human approves
- **Ship incrementally** - Each phase is a working milestone
- **Test everything** - If you can't test it, the phase isn't done.
  - _Tests_ are **not allowed** to be modified to _pass_. Our CODE is modified to pass tests. NO CHEATING!
- **Refactor** code when it makes sense, especially against tests!
- **Iterate on feedback** - Plans evolve based on real usage

## Development Environment

This project is developed on **Windows 11** with the following toolchain:

- **Terminal:** PowerShell 7+ (`pwsh`) - not bash
- **Version Control:** Git
- **Python:** 3.13+ via `uv` package manager
- **Shell Commands:** Use PowerShell-native commands and syntax

When requesting tools or writing scripts, prefer:

- `Get-ChildItem` over `ls` (or use `ls` alias in pwsh)
- `Select-String` over `grep`
- `Get-Content` over `cat`
- PowerShell-style paths with backslashes or forward slashes (both work in pwsh)
- `uv run` for Python execution within projects

## Scaling Agent Context

As projects grow, this root `AGENTS.md` should remain lean—acting as a **router** rather than a repository of all knowledge.

### Context Index Pattern

For domain-specific guidance, create index files in `.agents/context/`:

```markdown
.agents/
├── context/
│   ├── INDEX.md          # Master index of all context files
│   ├── logging.md        # Logging conventions and patterns
│   ├── mkdocs.md         # MkDocs setup and documentation standards
│   ├── sdk-reference.md  # SDK documentation and usage patterns
│   └── testing.md        # Testing strategies and frameworks
├── plan.md
├── implementation.md
└── ...
```

### INDEX.md Structure

The `INDEX.md` file serves as a lookup table for agents:

```markdown
# Context Index

## When to Load Each Context

| Topic | File | Load When... |
| ----- | ---- | ------------ |
| Logging | `logging.md` | Implementing logging, debugging, or observability |
| Documentation | `mkdocs.md` | Creating or updating project documentation |
| SDK Usage | `sdk-reference.md` | Working with external SDKs or APIs |
| Testing | `testing.md` | Writing tests, setting up test infrastructure |

## Quick Reference Tags

- `#logging` → logging.md
- `#docs` → mkdocs.md
- `#sdk` → sdk-reference.md
- `#testing` → testing.md
```

### How Agents Should Use This

1. **On task start:** Check `INDEX.md` for relevant context files
2. **Keyword matching:** If the task mentions "logging", "MkDocs", etc., load the corresponding file
3. **Explicit requests:** User can say "load logging context" or reference `#logging`
4. **Stay focused:** Only load context files relevant to the current task

### Creating New Context Files

When a topic grows beyond a few paragraphs in `AGENTS.md`:

1. Create a new file in `.agents/context/`
2. Add an entry to `INDEX.md` with clear "load when" criteria
3. Remove the verbose content from root `AGENTS.md`
4. Keep only a one-line reference in root if needed

## Agent Maintenance Responsibilities

All files in `.agents/` (including this one) are **living documentation**. Agents must maintain them as part of normal project work:

- **Update plans** when scope changes or phases complete
- **Keep INDEX.md current** as context files are added, modified, or removed
- **Retire stale content** rather than letting it accumulate
- **Propose new context files** when recurring topics deserve dedicated guidance

This is baked into the workflow—not a separate task. If agent guidance drifts from reality, future sessions inherit confusion.
