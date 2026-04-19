# Phase 5: Discussion Log

**Date:** 2025-07-24
**Mode:** Interactive (standard)
**Areas discussed:** 4 of 4

---

## Area 1: CLI parameter contract (4 questions)

**Q1: Which v1 params to drop/keep?**
→ Clean break. v2 surface: `[string[]]$FilePath`, `-Manifest`, `-InstallSendTo`, `-InstallKDE`, `-NoPause`, `-SystemWide`, `-Log`, `-Help`. Dropped: Hash, Algorithm, OnlyVerify, SkipSignatureCheck, LogLevel, Force. Renamed: SendTo → InstallSendTo.

**Q2: FilePath shape and manifest dispatch?**
→ `[string[]]$FilePath` for all modes. `-Manifest` flag switches mode. Extension auto-detect within manifest mode.

**Q3: Pause-at-end for no-args case?**
→ Detect interactivity (no FilePath + no pipe), show help banner + examples, pause.

**Q4: Pause-at-end when files ARE provided?**
→ Auto-detect: pause only if no parent console (Explorer/SendTo launch). Terminal sessions skip pause automatically. `-NoPause` as explicit override.

---

## Area 2: Dead code & Config fate (4 questions)

**Q1: VeriHash.Config.ps1 fate?**
→ Delete it. v2 has no config system.

**Q2: ConvertTo-SanitizedPath + LogUtils?**
→ Delete both. Dead code, no v2 consumer.

**Q3: VeriHash-OpenWith.bat?**
→ Delete it. v2 uses proper .lnk shortcuts.

**Q4: Tests/VeriHash.Config.Tests.ps1 and Tests/VeriHash.Tests.ps1?**
→ Delete both (plus Tests/VeriHash.LogUtils.Tests.ps1). They test deleted/rewritten code.

---

## Area 3: README & CHANGELOG shape (4 questions)

**Q1: README structure?**
→ Comprehensive rewrite. Keep benchmarks, "Why PowerShell 7?", profile integration, privacy. Add Module Architecture section. Drop QuickHash section.

**Q2: CHANGELOG format?**
→ Clean v2.0 entry ("Modular Rewrite"). Breaking changes section. v1 entries in collapsed "Version 1.x History".

**Q3: Concepting docs?**
→ Move to `.planning/archive/`.

**Q4: Version badge/header?**
→ Version badge + short tagline, no inline release notes in header. Link to CHANGELOG.

---

## Area 4: CLI test strategy (3 questions)

**Q1: Test scope?**
→ Dispatch routing + error paths only. Mock module functions. Don't re-test module logic.

**Q2: Test file name?**
→ `Tests/VeriHash.Cli.Tests.ps1`.

**Q3: Pause behavior testing?**
→ Extract to testable function (`Test-VeriHashInteractive`). Tests mock it.

---

## Summary

15 decisions captured across 4 areas. All prior-phase decisions honored (Phase 4 D-06 resolved, D-09/D-10/D-12 carried forward). No scope creep — PSGallery publishing, GNOME/XFCE support, and file picker replacement deferred.
