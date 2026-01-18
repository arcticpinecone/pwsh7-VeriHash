# MkDocs Documentation Context

Context for working with VeriHash's MkDocs documentation site.

## Overview

VeriHash uses MkDocs with the Material theme for documentation, deployed via GitHub Pages.

## Key Files

| File | Purpose |
|------|---------|
| `mkdocs.yml` | Site configuration (theme, nav, plugins) |
| `docs/` | Documentation source files (Markdown) |
| `.github/workflows/docs.yml` | Auto-deploy to GitHub Pages |
| `scripts/Generate-Docs.ps1` | Extracts parameter docs from code |
| `Tests/VeriHash.Docs.Tests.ps1` | Validates doc examples work |

## Local Development

```powershell
# Preview docs locally (requires Python)
pip install mkdocs mkdocs-material
mkdocs serve
# Opens at http://127.0.0.1:8000
```

## Auto-Generated Content

Some documentation is auto-generated from code:

- **Parameters reference:** Extracted from VeriHash.ps1 comment-based help via `scripts/Generate-Docs.ps1`
- **Function docs:** Extracted from LogUtils and Config modules

Run `scripts/Generate-Docs.ps1` before building if code has changed.

## Anti-Drift Strategy

1. **Doc examples are tested** - `Tests/VeriHash.Docs.Tests.ps1` runs documented examples
2. **Parameters auto-generated** - Can't drift because extracted from code
3. **PR checklist** - `.github/PULL_REQUEST_TEMPLATE.md` reminds about doc updates
4. **Workflow guideline** - AGENTS.md requires doc updates for user-facing changes

## When Making Changes

**Code change affects user behavior?**

1. Update relevant doc page in `docs/`
2. Run `Invoke-Pester Tests/VeriHash.Docs.Tests.ps1` to verify examples still work
3. If parameter changed, run `scripts/Generate-Docs.ps1`

**Adding new feature?**

1. Decide which doc page it belongs in (or create new one)
2. Add examples to docs
3. Add corresponding test to `VeriHash.Docs.Tests.ps1`

## Deployment

Automatic via GitHub Actions:

- Push to `main` with changes in `docs/` or `mkdocs.yml`
- Workflow runs `mkdocs gh-deploy`
- Site updates at `https://[username].github.io/VeriHash/`
