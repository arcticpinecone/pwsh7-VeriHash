function Test-VeriHashSidecar {
    <#
    .SYNOPSIS
        Verifies a target file against its strongest adjacent sidecar.
    .DESCRIPTION
        Sidecar precedence: .sha512 > .sha256 > .md5. Only the chosen sidecar
        is read and verified (single hash compute). Supports v1 sidecar formats
        ('HASH  filename' two-space and 'HASH *filename' asterisk).
    .PARAMETER Path
        Path to the TARGET file (NOT the sidecar). Resolved with -LiteralPath.
    .PARAMETER ComputedResult
        An optional VeriHash.Result the caller has ALREADY computed for this file.
        When its Algorithm equals the chosen sidecar's, it is reused verbatim and
        no second pass over the file is made -- a full re-hash of a large file is
        the single most expensive thing this function can do, and in the common
        case (a .sha256 sidecar under a SHA256 run) it recomputes a digest the
        caller is already holding. When the algorithms differ the parameter is
        ignored and the file is hashed with the sidecar's algorithm as before,
        because a SHA256 digest cannot answer a .sha512 sidecar.
    .OUTPUTS
        VeriHash.Result with an additional 'Sidecar' field describing which
        sidecar was used, or $null when no sidecar exists.

        SidecarStatus (matched|mismatch|error), SidecarName, and ExpectedHash
        carry the same facts as data for the renderer; the Sidecar string is
        retained for backward compatibility. ExpectedHash is the hash read OUT
        of the sidecar -- without it a mismatch cannot be shown, only asserted.
    #>
    [CmdletBinding()]
    [OutputType('VeriHash.Result')]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [pscustomobject]$ComputedResult
    )

    $sidecar = Get-PreferredSidecar -TargetPath $Path
    if (-not $sidecar) { return $null }

    $sidecarLeaf = Split-Path -Leaf $sidecar.Path
    $line = Get-Content -LiteralPath $sidecar.Path -TotalCount 1
    $parsed = Read-SidecarLine -Line $line

    $actual = if ($ComputedResult -and $ComputedResult.Hash -and
                  $ComputedResult.Algorithm -eq $sidecar.Algorithm) {
        $ComputedResult
    } else {
        Get-VeriHashResult -Path $Path -Algorithm $sidecar.Algorithm
    }

    if (-not $parsed) {
        return [pscustomobject]@{
            PSTypeName    = 'VeriHash.Result'
            FilePath      = $actual.FilePath
            Size          = $actual.Size
            Algorithm     = $actual.Algorithm
            Hash          = $actual.Hash
            ElapsedMs     = $actual.ElapsedMs
            Sidecar       = "error ($sidecarLeaf)"
            SidecarStatus = 'error'
            SidecarName   = $sidecarLeaf
            ExpectedHash  = $null
        }
    }

    $status = if ($actual.Hash -eq $parsed.Hash) { 'matched' } else { 'mismatch' }

    return [pscustomobject]@{
        PSTypeName    = 'VeriHash.Result'
        FilePath      = $actual.FilePath
        Size          = $actual.Size
        Algorithm     = $actual.Algorithm
        Hash          = $actual.Hash
        ElapsedMs     = $actual.ElapsedMs
        Sidecar       = "$status ($sidecarLeaf)"
        SidecarStatus = $status
        SidecarName   = $sidecarLeaf
        ExpectedHash  = $parsed.Hash
    }
}
