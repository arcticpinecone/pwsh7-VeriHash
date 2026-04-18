# Plan 02-01 — WinVerifyTrust P/Invoke Pin

**Status:** Locked. Source of truth for the P/Invoke struct layouts, flag values, action GUID, and HRESULT → Status mapping consumed by `VeriHash.HotPath/Private/Invoke-WinVerifyTrust.ps1` and `VeriHash.HotPath/Private/ConvertFrom-WinTrustHResult.ps1`.

**Canonical sources (cited verbatim):**
- `WINTRUST_DATA` struct — <https://learn.microsoft.com/en-us/windows/win32/api/wintrust/ns-wintrust-wintrust_data>
- `WINTRUST_FILE_INFO` struct — <https://learn.microsoft.com/en-us/windows/win32/api/wintrust/ns-wintrust-wintrust_file_info_>
- `WinVerifyTrust` function — <https://learn.microsoft.com/en-us/windows/win32/api/wintrust/nf-wintrust-winverifytrust>
- `WINTRUST_ACTION_GENERIC_VERIFY_V2` GUID — Windows 10/11 SDK `wintrust.h`
- HRESULT constants — `winerror.h` (Windows 10/11 SDK)
- pinvoke.net cross-check — <https://www.pinvoke.net/default.aspx/wintrust.winverifytrust>

This file is read by `Plan 02-01 Task 2`. Code copies struct layout, flag names+values, action GUID, and HRESULT mapping verbatim from this document. **No struct invention.**

---

## Section 1 — `WINTRUST_DATA` struct (verbatim from canonical source)

Lock the C# field list in this exact order:

```csharp
[StructLayout(LayoutKind.Sequential)]
public struct WINTRUST_DATA {
    public uint   cbStruct;
    public IntPtr pPolicyCallbackData;
    public IntPtr pSIPClientData;
    public uint   dwUIChoice;             // WTD_UI_NONE = 2
    public uint   fdwRevocationChecks;    // WTD_REVOKE_NONE = 0
    public uint   dwUnionChoice;          // WTD_CHOICE_FILE = 1
    public IntPtr pFile;                  // -> WINTRUST_FILE_INFO*
    public uint   dwStateAction;          // WTD_STATEACTION_VERIFY = 1, WTD_STATEACTION_CLOSE = 2
    public IntPtr hWVTStateData;          // populated by VERIFY, freed by CLOSE
    [MarshalAs(UnmanagedType.LPWStr)] public string pwszURLReference;
    public uint   dwProvFlags;            // WTD_REVOCATION_CHECK_NONE (0x00000010) | WTD_CACHE_ONLY_URL_RETRIEVAL (0x00001000)
    public uint   dwUIContext;
    public IntPtr pSignatureSettings;     // Win8+, IntPtr.Zero for our use
}
```

**Diff from canonical source:** None. Field count, ordering, and types match `wintrust.h` (Windows 10/11 SDK) one-for-one. `pSignatureSettings` is the post-Win8 trailing field; we set it to `IntPtr.Zero`, which is safe on Win7 because the OS reads only `cbStruct` bytes and `cbStruct` is computed from the .NET `Marshal.SizeOf` of the same struct definition the OS will index into.

---

## Section 2 — `WINTRUST_FILE_INFO` struct (verbatim)

```csharp
[StructLayout(LayoutKind.Sequential)]
public struct WINTRUST_FILE_INFO {
    public uint   cbStruct;
    [MarshalAs(UnmanagedType.LPWStr)] public string pcwszFilePath;
    public IntPtr hFile;             // IntPtr.Zero
    public IntPtr pgKnownSubject;    // IntPtr.Zero
}
```

**Diff from canonical source:** None.

---

## Section 3 — Action GUID

`WINTRUST_ACTION_GENERIC_VERIFY_V2 = {00AAC56B-CD44-11D0-8CC2-00C04FC295EE}`

C# literal:

```csharp
static readonly Guid WINTRUST_ACTION_GENERIC_VERIFY_V2 =
    new Guid("00AAC56B-CD44-11D0-8CC2-00C04FC295EE");
```

PowerShell literal:

```powershell
$actionGuid = [guid]'00AAC56B-CD44-11D0-8CC2-00C04FC295EE'
```

Confirmed against `wintrust.h` (Windows 10/11 SDK) and pinvoke.net.

---

## Section 4 — Flag naming clarification (resolves RESEARCH.md Assumption A2)

**`fdwRevocationChecks` (struct field) and `dwProvFlags` (struct field) live in different namespaces.** PERF-02 ("disable network CRL lookups") requires setting BOTH:

| Field | Constant name | Value | Effect |
|-------|---------------|-------|--------|
| `WINTRUST_DATA.fdwRevocationChecks` | `WTD_REVOKE_NONE` | `0` | Tells WinVerifyTrust "don't run a separate revocation pass at all". Disables the CRL axis at the policy level. |
| `WINTRUST_DATA.dwProvFlags` (bit) | `WTD_REVOCATION_CHECK_NONE` | `0x00000010` | Tells the trust provider not to check revocation as part of chain validation. Bit-OR'd into `dwProvFlags`. |
| `WINTRUST_DATA.dwProvFlags` (bit) | `WTD_CACHE_ONLY_URL_RETRIEVAL` | `0x00001000` | If any URL fetch is attempted, hit the local cache only — never go to the network. Bit-OR'd into `dwProvFlags`. |

**Note on naming in `02-CONTEXT.md`:** `02-CONTEXT.md` refers to "WTD_REVOCATION_NONE" in the locked-decision text (D-A1-1). That label is shorthand for the `dwProvFlags` constant **`WTD_REVOCATION_CHECK_NONE = 0x10`**. `WTD_REVOKE_NONE` (the `fdwRevocationChecks` value) is a different constant that happens to also be `0`. Both must be set; they are not duplicates.

Final `dwProvFlags` value used by `Invoke-WinVerifyTrust.ps1`:

```
dwProvFlags = WTD_REVOCATION_CHECK_NONE | WTD_CACHE_ONLY_URL_RETRIEVAL
            = 0x00000010 | 0x00001000
            = 0x00001010
```

---

## Section 5 — Forbidden flag list (D-A1-1)

The following constants are **forbidden** anywhere in `VeriHash.HotPath/`. A grep for `WTD_DISABLE_MD2_MD4` in this repo MUST return zero matches except inside this PIN doc and the corresponding test that audits its absence:

| Constant | Value | Why forbidden |
|----------|-------|---------------|
| `WTD_DISABLE_MD2_MD4` | `0x00002000` | Downgrade flag; weakens digest-algorithm policy. EDRs flag binaries that pass it. |
| `WTD_DISABLE_IND` | `0x00000100` | Disables individual-trust UI prompts; not needed when `dwUIChoice = WTD_UI_NONE`. |
| `WTD_USE_DEFAULT_OSVER_CHECK` | `0x00020000` | Changes OS-version policy; not relevant to Authenticode-on-PE. |
| Any other `WTD_*` flag not listed in Section 4 | — | If you didn't pin it here, you don't ship it. |

Test `Tests/VeriHash.HotPath.Tests.ps1` enforces zero matches for `WTD_DISABLE_MD2_MD4` across `VeriHash.HotPath/`.

---

## Section 6 — HRESULT → Status mapping (verbatim from RESEARCH.md Pitfall 3)

`ConvertFrom-WinTrustHResult.ps1` MUST implement exactly this 8-row table. PowerShell receives the `WinVerifyTrust` return value as a signed 32-bit `int`; the third column is the corresponding signed-int decimal literal used in the `switch` arms.

| HRESULT name | Hex (uint32) | Signed int32 | Status | Reason (short string) |
|--------------|-------------|--------------|--------|-----------------------|
| `S_OK` | `0x00000000` | `0` | `valid` | `''` (empty) |
| `TRUST_E_NOSIGNATURE` | `0x800B0100` | `-2146762496` | `unsigned` | `not signed` |
| `TRUST_E_BAD_DIGEST` | `0x80096010` | `-2146869232` | `invalid` | `bad digest` |
| `TRUST_E_EXPLICIT_DISTRUST` | `0x800B0111` | `-2146762479` | `invalid` | `explicit distrust` |
| `CERT_E_EXPIRED` | `0x800B0101` | `-2146762495` | `invalid` | `cert expired` |
| `CERT_E_REVOKED` | `0x80092010` | `-2146885616` | `invalid` | `cert revoked` |
| `CERT_E_UNTRUSTEDROOT` | `0x800B0109` | `-2146762487` | `invalid` | `untrusted root` |
| `CERT_E_CHAINING` | `0x800B010A` | `-2146762486` | `invalid` | `chain build failed` |
| *anything else* | `0x????????` | *varies* | `error` | `'0x{0:X8}' -f ([uint32]$HResult)` |

**Sign-conversion verification:** in PowerShell 7,
```powershell
[int]([uint32]0x800B0100)   # -> -2146762496
[int]([uint32]0x80096010)   # -> -2146869232
[int]([uint32]0x800B0111)   # -> -2146762479
[int]([uint32]0x800B0101)   # -> -2146762495
[int]([uint32]0x80092010)   # -> -2146885616
[int]([uint32]0x800B0109)   # -> -2146762487
[int]([uint32]0x800B010A)   # -> -2146762486
```

---

## Section 7 — Call sequence (Pitfall 4 — STATEACTION_VERIFY/CLOSE pairing)

```powershell
try {
    $hresult = [VeriHash.WinTrust]::WinVerifyTrust([IntPtr]::Zero, [ref]$actionGuid, [ref]$wtd)
    return [int]$hresult
} finally {
    $wtd.dwStateAction = 2     # WTD_STATEACTION_CLOSE — releases hWVTStateData
    [void][VeriHash.WinTrust]::WinVerifyTrust([IntPtr]::Zero, [ref]$actionGuid, [ref]$wtd)
    if ($filePtr -ne [IntPtr]::Zero) {
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($filePtr)
    }
}
```

Both calls share the same `$wtd` value-typed struct so `hWVTStateData` populated by VERIFY is visible to CLOSE.
