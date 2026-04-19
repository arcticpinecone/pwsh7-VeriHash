function Get-VeriHashSignature {
    <#
    .SYNOPSIS
        Returns Authenticode signature status for a file via WinVerifyTrust (Windows) or skipped elsewhere.
    .DESCRIPTION
        On Windows, calls Invoke-WinVerifyTrust with WTD_REVOCATION_CHECK_NONE | WTD_CACHE_ONLY_URL_RETRIEVAL
        (no network CRL -- PERF-02), maps the HRESULT via ConvertFrom-WinTrustHResult, and returns
        a {Status, Reason} object. On non-Windows, returns Status='skipped' without P/Invoking.
    .PARAMETER Path
        Absolute or resolvable path to the file to verify.
    .PARAMETER IsPE
        Pre-computed PE-detect result; when $false, returns Status='skipped', Reason='not a PE file'
        without P/Invoking. The caller (Invoke-VeriHashHotPath) runs Test-IsPEFile once on the main
        thread and passes the result here so the sig ThreadJob doesn't re-open the file.
    .OUTPUTS
        [pscustomobject] @{ Status; Reason } -- Status in valid|invalid|unsigned|skipped|error
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [switch] $IsPE
    )
    if (-not $IsPE) {
        return [pscustomobject]@{ Status = 'skipped'; Reason = 'not a PE file' }
    }
    if ((Get-VeriHashPlatform) -ne 'Windows') {
        return [pscustomobject]@{ Status = 'skipped'; Reason = 'not supported on this platform' }
    }
    $hresult = Invoke-WinVerifyTrust -Path $Path
    return ConvertFrom-WinTrustHResult -HResult $hresult
}
