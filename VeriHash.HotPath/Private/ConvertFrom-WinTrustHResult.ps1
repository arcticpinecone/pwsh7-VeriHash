function ConvertFrom-WinTrustHResult {
    <#
    .SYNOPSIS
        Maps a WinVerifyTrust HRESULT (signed Int32) to a {Status, Reason} object.
    .DESCRIPTION
        Implements the 8-row table locked in
        .planning/phases/02-hot-path-performance-multi-file-loop/02-01-PINVOKE-PIN.md
        Section 6. Unknown HRESULTs return Status='error' with Reason set to the
        canonical 0xXXXXXXXX hex form so users can search Microsoft docs.
    .PARAMETER HResult
        The signed Int32 returned by WinVerifyTrust.
    .OUTPUTS
        [pscustomobject] @{ Status; Reason }
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [int] $HResult
    )
    $hex = '0x{0:X8}' -f ([System.BitConverter]::ToUInt32([System.BitConverter]::GetBytes($HResult), 0))
    switch ($HResult) {
        0           { return [pscustomobject]@{ Status = 'valid';    Reason = '' } }
        -2146762496 { return [pscustomobject]@{ Status = 'unsigned'; Reason = 'not signed' } }              # 0x800B0100 TRUST_E_NOSIGNATURE
        -2146869232 { return [pscustomobject]@{ Status = 'invalid';  Reason = 'bad digest' } }              # 0x80096010 TRUST_E_BAD_DIGEST
        -2146762479 { return [pscustomobject]@{ Status = 'invalid';  Reason = 'explicit distrust' } }       # 0x800B0111 TRUST_E_EXPLICIT_DISTRUST
        -2146762495 { return [pscustomobject]@{ Status = 'invalid';  Reason = 'cert expired' } }            # 0x800B0101 CERT_E_EXPIRED
        -2146885616 { return [pscustomobject]@{ Status = 'invalid';  Reason = 'cert revoked' } }            # 0x80092010 CERT_E_REVOKED
        -2146762487 { return [pscustomobject]@{ Status = 'invalid';  Reason = 'untrusted root' } }          # 0x800B0109 CERT_E_UNTRUSTEDROOT
        -2146762486 { return [pscustomobject]@{ Status = 'invalid';  Reason = 'chain build failed' } }      # 0x800B010A CERT_E_CHAINING
        default     { return [pscustomobject]@{ Status = 'error';    Reason = $hex } }
    }
}
