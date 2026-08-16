---
phase: 04
slug: integrations-config-trim
status: verified
threats_open: 0
asvs_level: 1
created: 2026-04-19
---

# Phase 04 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Config file → Config loader | Untrusted JSON from user's config directory | JSON with logging settings |
| Env vars → Config loader | Untrusted environment variable values | String values for log level, paths |
| File system → Install-WindowsSendTo | Writes .lnk files to user's SendTo folder | Shortcut files with script paths |
| File system → Install-KDEContextMenu | Writes .desktop files to KDE service menu paths | Desktop entry files with Exec lines |
| User elevation → SystemWide install | Root/admin check before writing to system paths | Privilege boundary |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-04-01 | T (Tampering) | VeriHash.Config.ps1 | accept | Config validates known keys only; VT fields removed; malformed JSON falls to defaults (line 166-169) | closed |
| T-04-02 | I (Information Disclosure) | PSFramework removal | mitigate | Zero PSFramework/Write-PSFMessage/PSFrameworkAvailable in all production .ps1 files — data disclosure channel eliminated entirely | closed |
| T-04-03 | E (Elevation of Privilege) | Install-WindowsSendTo | mitigate | No Start-Process -Verb RunAs; no UAC trigger; writes only to user-level $env:AppData\SendTo (lines 88-142) | closed |
| T-04-04 | E (Elevation of Privilege) | Install-KDEContextMenu | mitigate | Root check ($env:USER + id -u) before system path write; non-root → Write-Error + return; user-level → ~/.local/ only (lines 203-226) | closed |
| T-04-05 | T (Tampering) | .lnk / .desktop files | accept | Files in user-writable directories; same trust level as any user-installed shortcut; no escalation path | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-04-01 | T-04-01 | Config JSON from user directory could contain unexpected keys. Loader validates only known keys, casts to expected types, catches parse errors. Residual risk: Low — config file is user-owned, same trust as PowerShell profile. | gsd-security-auditor | 2026-04-19 |
| AR-04-02 | T-04-05 | .lnk and .desktop files are user-writable by design. No escalation path — same trust model as any user-installed shortcut on Windows/Linux. Residual risk: Low. | gsd-security-auditor | 2026-04-19 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-04-19 | 5 | 5 | 0 | gsd-security-auditor |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-04-19
