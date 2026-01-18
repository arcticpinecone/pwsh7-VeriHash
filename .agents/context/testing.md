# Testing Context

Guidelines for agents when testing is part of the project workflow.

## When to Suggest Testing

Agents should propose testing when:

- User is implementing logic with clear inputs/outputs
- A bug fix is being made (regression test opportunity)
- The project has an existing test structure to follow
- User mentions "make sure this works" or similar intent

Agents should *not* push testing when:

- It's a quick script or one-off utility
- User explicitly wants to skip it
- The overhead outweighs the benefit (use judgment)

## Framework Integration

Tests are project artifacts. Track them in `.agents/` like any other deliverable:

- **In `plan.md`:** Note if testing is in scope for the MVP
- **In `implementation.md`:** Include test milestones in phases (e.g., "Phase 2 includes unit tests for core module")
- **In `phase-N-implementation.md`:** List specific test tasks with checkboxes

## Structure Conventions

Agents should follow whatever test structure the project already uses. If none exists and User wants tests:

1. Ask User's preference for test location (e.g., `tests/`, `__tests__/`, colocated)
2. Mirror source structure inside test directory
3. Name test files predictably (e.g., `test_<module>.py`, `<module>.test.ts`)

## Test-Code Relationship

From `AGENTS.md` Key Principles:

> Tests are **not allowed** to be modified to *pass*. Our CODE is modified to pass tests. NO CHEATING!

This means:

- Write tests that assert correct behavior
- When tests fail, fix the implementation—not the test
- Refactoring is encouraged, but tests define correctness

## Suggesting Test Tooling

Agents may suggest test frameworks when:

- User asks what to use
- Project has no existing test setup and User wants one

Let User choose. Common options by ecosystem:

- Python: pytest, unittest
- JavaScript/TypeScript: vitest, jest, mocha
- PowerShell: Pester
- Go: built-in testing package
- Rust: built-in #[test]

Don't over-specify. If User says "add tests," ask which framework or detect from existing config.

---

## VeriHash Test Suite

VeriHash uses **Pester** for testing. Test files are in `Tests/`.

### Running Tests

```powershell
# Run all tests
Invoke-Pester -Path "Tests/" -Output Detailed

# Run specific test file
Invoke-Pester -Path "Tests/VeriHash.Tests.ps1" -Output Detailed

# Run with code coverage
Invoke-Pester -Path "Tests/" -CodeCoverage "VeriHash.ps1"
```

### Test Files

| File | Tests |
| ---- | ----- |
| `VeriHash.Tests.ps1` | Main VeriHash functionality |
| `VeriHash.LogUtils.Tests.ps1` | Log parsing utilities |
| `VeriHash.Config.Tests.ps1` | Configuration management |
| `VeriHash.Timing.Tests.ps1` | Performance/timing tests |
| `QuickHash.Tests.ps1` | QuickHash utility |

### Test Environment

Tests automatically set `VERIHASH_TEST_MODE=1` to redirect logs to `logs/test/` subdirectory, preventing test logs from mixing with production logs.

### Non-Interactive Testing

All test invocations include `-NoPause -Force` flags to:

- Skip "Press Enter to continue..." prompts (`-NoPause`)
- Auto-update sidecars without prompting (`-Force`)

**Do not run test files by dot-sourcing them directly** - use `Invoke-Pester`.
