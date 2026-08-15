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
        [pscustomobject] @{ Status; Reason; Signer } -- Status in valid|invalid|unsigned|skipped|error.
        Signer is the signing certificate's CN, or $null when unavailable.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [switch] $IsPE
    )
    if (-not $IsPE) {
        return [pscustomobject]@{ Status = 'skipped'; Reason = 'not a PE file'; Signer = $null }
    }
    if ((Get-VeriHashPlatform) -ne 'Windows') {
        return [pscustomobject]@{ Status = 'skipped'; Reason = 'not supported on this platform'; Signer = $null }
    }
    $hresult = Invoke-WinVerifyTrust -Path $Path
    $verdict = ConvertFrom-WinTrustHResult -HResult $hresult

    # The trust VERDICT comes from WinVerifyTrust above; this only reads the
    # embedded certificate's subject for a display name. CreateFromSignedFile
    # does no chain walk and no network I/O, so it costs ~1-5 ms -- and it runs
    # inside the sig ThreadJob, off the wall clock entirely.
    $signer = $null
    if ($verdict.Status -eq 'valid') {
        try {
            $cert    = [System.Security.Cryptography.X509Certificates.X509Certificate]::CreateFromSignedFile($Path)
            $subject = $cert.Subject
            # Subject looks like: CN="Contoso, Ltd.", O=Contoso, L=Redmond, C=US
            if ($subject -match 'CN=(?:"(?<q>[^"]+)"|(?<b>[^,]+))') {
                $signer = if ($matches['q']) { $matches['q'] } else { $matches['b'] }
                $signer = $signer.Trim()
            }
        } catch {
            $signer = $null   # display nicety only -- never fail the verdict over it
        }
    }

    return [pscustomobject]@{ Status = $verdict.Status; Reason = $verdict.Reason; Signer = $signer }
}
